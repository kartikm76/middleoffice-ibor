from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Dict, Optional, Sequence

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
from opentelemetry import trace

from ai_gateway.infra.tracing import traced

_tracer = trace.get_tracer("ai-gateway.db")

@dataclass(frozen=True)
class PgPoolConfig:
    """
    Config holder for PostgreSQL pooling.
    DSN is injected from outside (no env access here).
    """
    dsn: str
    min_size: int = 1
    max_size: int = 5
    max_lifetime: int = 60 * 60  # seconds
    max_wait: int = 10           # seconds to wait for a connection


class PgPool:
    """
    Singleton-style wrapper around psycopg_pool.ConnectionPool.

    - Uses dict_row so callers get Dict[str, Any] rows.
    - Provides execute() / fetch_all() / fetch_one().
    - Adds simple retry + tracing attributes (duration, rowcount, retry_count).
    """

    _instance: Optional["PgPool"] = None

    def __new__(cls, config: PgPoolConfig) -> "PgPool":
        # One shared pool per process (simple singleton).
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._init(config)
        return cls._instance

    def _init(self, config: PgPoolConfig) -> None:
        self._config = config
        self._pool = ConnectionPool(
            conninfo=config.dsn,
            min_size=config.min_size,
            max_size=config.max_size,
            max_lifetime=config.max_lifetime,
            timeout=config.max_wait,
            open=True,
            kwargs={"row_factory": dict_row},
        )

    def connection(self):
        return self._pool.connection()

    def open(self) -> None:
        # keep compatibility if callers explicitly open
        if not self._pool.open:
            self._pool.open()

    def close(self) -> None:
        self._pool.close()

    # -------- core operations --------

    @traced("db.execute")
    def execute(
            self,
            sql: str,
            params: Optional[Dict[str, Any]] = None,
            *,
            retries: int = 2,
            retry_backoff: float = 0.2,
    ) -> int:
        """
        Run INSERT/UPDATE/DELETE/DDL.

        Returns: rowcount
        """
        attempt = 0
        last_exc: Optional[Exception] = None
        start = time.perf_counter()

        while attempt <= retries:
            try:
                with self._pool.connection() as conn, conn.cursor() as cur:
                    cur.execute(sql, params or {})
                    conn.commit()
                    rowcount = cur.rowcount

                span = trace.get_current_span()
                span.set_attribute("db.system", "postgresql")
                span.set_attribute("db.operation", "execute")
                span.set_attribute("db.statement", sql[:5000])
                span.set_attribute("db.rowcount", rowcount)
                span.set_attribute("db.retry_count", attempt)
                span.set_attribute(
                    "db.duration_ms",
                    (time.perf_counter() - start) * 1000.0,
                    )
                return rowcount

            except Exception as exc:  # broad but traced/logged
                last_exc = exc
                attempt += 1
                if attempt > retries:
                    span = trace.get_current_span()
                    span.record_exception(exc)
                    span.set_attribute("db.retry_exhausted", True)
                    raise
                time.sleep(retry_backoff)

        # should not reach here
        if last_exc:
            raise last_exc
        return 0

    @traced("db.fetch_all")
    def fetch_all(
            self,
            sql: str,
            params: Optional[Dict[str, Any]] = None,
            *,
            retries: int = 2,
            retry_backoff: float = 0.2,
    ) -> Sequence[Dict[str, Any]]:
        """
        Run SELECT and return list[dict].
        """
        attempt = 0
        last_exc: Optional[Exception] = None
        start = time.perf_counter()

        while attempt <= retries:
            try:
                with self._pool.connection() as conn, conn.cursor() as cur:
                    cur.execute(sql, params or {})
                    rows = list(cur.fetchall())

                span = trace.get_current_span()
                span.set_attribute("db.system", "postgresql")
                span.set_attribute("db.operation", "fetch_all")
                span.set_attribute("db.statement", sql[:5000])
                span.set_attribute("db.rowcount", len(rows))
                span.set_attribute("db.retry_count", attempt)
                span.set_attribute(
                    "db.duration_ms",
                    (time.perf_counter() - start) * 1000.0,
                    )
                return rows

            except Exception as exc:
                last_exc = exc
                attempt += 1
                if attempt > retries:
                    span = trace.get_current_span()
                    span.record_exception(exc)
                    span.set_attribute("db.retry_exhausted", True)
                    raise
                time.sleep(retry_backoff)

        if last_exc:
            raise last_exc
        return []

    @traced("db.fetch_one")
    def fetch_one(
            self,
            sql: str,
            params: Optional[Dict[str, Any]] = None,
            *,
            retries: int = 2,
            retry_backoff: float = 0.2,
    ) -> Optional[Dict[str, Any]]:
        """
        Run SELECT and return a single row (or None).
        """
        rows = self.fetch_all(
            sql,
            params=params,
            retries=retries,
            retry_backoff=retry_backoff,
        )
        return rows[0] if rows else None