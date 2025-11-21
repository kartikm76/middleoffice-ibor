from __future__ import annotations

from datetime import date
from typing import Optional, Protocol
from ai_gateway.agents.analyst import AnalystAnswer


class AnalystService(Protocol):
    """Behavior the web layer expects from any analyst service implementation."""

    def positions(self, portfolio_code: str, as_of: date) -> AnalystAnswer:
        ...

    def trades(self, portfolio_code: str, instrument_code: str, as_of: date) -> AnalystAnswer:
        ...

    def prices(self,
               instrument_code: str,
               from_date: date,
               to_date: date,
               source: Optional[str] = None,
                base_currency: Optional[str] = None,) -> AnalystAnswer:
        ...

    def pnl(self,
            portfolio_code: str,
            as_of: date,
            prior: date,
            instrument_code: str) -> AnalystAnswer:
        ...

