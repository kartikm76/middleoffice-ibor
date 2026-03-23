from __future__ import annotations
import psycopg
from dataclasses import dataclass

@dataclass
class PgPoolConfig:
    dsn: str

class PgPool:
    def __init__(self, config: PgPoolConfig) -> None:
        self._dsn = config.dsn

    def get_conn(self):
        return psycopg.connect(self._dsn)

def test_pg_round_trip() -> None:
    config = PgPoolConfig (dsn="postgresql://ibor:ibor@localhost:5432/ibor")
    pool = PgPool(config)

    with pool.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 AS x;")
            row = cur.fetchone()
            assert row == (1,)