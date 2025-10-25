# src/ai_gateway/infra/tracing.py
from __future__ import annotations
from functools import wraps
from typing import Optional, Iterable

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

_tracer = trace.get_tracer("ai-gateway")

def init_tracing(
        service_name: str = "ibor-ai-gateway",
        otlp_endpoint: Optional[str] = None,  # e.g. http://localhost:4318
        console_fallback: bool = True,
) -> None:
    """
    Initialize OpenTelemetry tracing for this process.
    - If otlp_endpoint is provided, export to that OTLP collector.
    - Optionally also log spans to console for quick dev verification.
    """
    provider = TracerProvider(resource=Resource.create({"service.name": service_name}))
    if otlp_endpoint:
        provider.add_span_processor(
            BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{otlp_endpoint}/v1/traces"))
        )
    if console_fallback or not otlp_endpoint:
        provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)

def traced(name: Optional[str] = None, attrs: Optional[dict] = None, arg_attrs: Optional[Iterable[str]] = None):
    """
    Decorate any sync function to create a child span.
    - name: span name (defaults to module.qualname)
    - attrs: dict of static attributes to attach to the span
    - arg_attrs: iterable of argument names to record as span attributes (sanitized)
    """
    def deco(fn):
        span_name = name or f"{fn.__module__}.{fn.__qualname__}"

        @wraps(fn)
        def wrapper(*args, **kwargs):
            with _tracer.start_as_current_span(span_name) as span:
                # static attributes
                if attrs:
                    for k, v in attrs.items():
                        span.set_attribute(k, v)
                # selected argument attributes
                if arg_attrs:
                    # bind args → param names to safely pick requested ones
                    from inspect import signature
                    bound = signature(fn).bind_partial(*args, **kwargs)
                    bound.apply_defaults()
                    for k in arg_attrs:
                        if k in bound.arguments:
                            v = bound.arguments[k]
                            # avoid logging big payloads/secrets
                            if isinstance(v, (str, int, float, bool)) or v is None:
                                span.set_attribute(f"arg.{k}", v)
                            else:
                                span.set_attribute(f"arg.{k}", type(v).__name__)
                try:
                    return fn(*args, **kwargs)
                except Exception as e:
                    span.record_exception(e)
                    from opentelemetry.trace.status import Status, StatusCode
                    span.set_status(Status(StatusCode.ERROR, str(e)))
                    raise
        return wrapper
    return deco