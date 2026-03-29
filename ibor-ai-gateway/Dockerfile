# ─────────────────────────────────────────────────────────────────────────────
# IBOR AI Gateway (FastAPI) Dockerfile
# Uses frozen uv.lock for reproducible Python environment
# ─────────────────────────────────────────────────────────────────────────────

FROM python:3.13-slim-bookworm

WORKDIR /app

# Install system dependencies (curl for health checks, build tools for compiled packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.cargo/bin/uv /usr/local/bin/uv

# Copy uv.lock (frozen dependencies)
COPY uv.lock pyproject.toml ./

# Create virtual environment and sync dependencies from frozen uv.lock
RUN uv venv /app/.venv && \
    . /app/.venv/bin/activate && \
    uv sync --frozen

# Copy source code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Set PATH to use venv
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Run FastAPI application
CMD ["uvicorn", "ai_gateway.main:app", "--host", "0.0.0.0", "--port", "8000"]
