from __future__ import annotations
from datetime import date
from typing import Optional, Dict, Any
from ai_gateway.infra.tracing import traced
from ai_gateway.tools.structured import StructuredTools

class DataAgent:
    """
    Thin wrapper around structured tools.
    Responsibility: fetch numbers only (no narrative).
    """
    def __init__(self, tools: StructuredTools):
        self.tools = tools

    @traced("data_agent.positions")
    def positions_today(self, portfolio_code: str, as_of: date) -> Dict[str, Any]:
        # Returns {"positions":[...]} + optional _citation
        return self.tools.positions(portfolio_code=portfolio_code, as_of=as_of)

    @traced("data_agent.trades")
    def trades(self, portfolio_code: str, instrument_code: str, as_of: date) -> Dict[str, Any]:
        # Returns {"transactions":[...]} + optional _citation
        return self.tools.position_drilldown(
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            as_of=as_of,
        )

    @traced("data_agent.prices")
    def prices(self, instrument_code: str, from_date: date, to_date: date, source: Optional[str] = None, base_currency: Optional[str] = None) -> Dict[str, Any]:
        # Returns {"prices":[...]} + optional _citation
        return self.tools.instrument_prices(
            instrument_code=instrument_code,
            from_date=from_date,
            to_date=to_date,
            source=source,
            base_currency=base_currency,
        )

    @traced("data_agent.pnl")
    def pnl(self, portfolio_code: str, as_of: date, prior: date, instrument_code: Optional[str] = None) -> Dict[str, Any]:
        # Returns {"pnl":[...]} + optional _citation
        return None