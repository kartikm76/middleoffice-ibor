from  __future__ import annotations
from datetime import date
from typing import Optional

from ai_gateway.clients.ibor_client import IborClient
from ai_gateway.tools.structured import StructuredTools
from ai_gateway.agents.analyst import AnalystAgent, AnalystAnswer

class AnalystOrchestrator:
    """
    Central wiring point for the Analyst flow.

    Step A (current):
      - Keep everything local / deterministic.
      - Wraps StructuredTools + AnalystAgent (Option A).
      - Exposes simple methods the FastAPI router can call.

    Later (Option C):
      - We'll add OpenAI Analysts / multi-agent logic here
        (LLM agent, tool registration, RAG handoff, etc.)
      - Router will not need to change again.
    """

    def __init__(
            self,
            client: Optional[IborClient] = None,
            tools: Optional[StructuredTools] = None) -> None:
        # Shared HTTP client for Spring structured service
        self._ibor_client = client or IborClient()

        # Structured tools (price/positions/drilldown wrappers)
        self._structured_tools = tools or StructuredTools(ibor_client = self._ibor_client)

        # Local deterministic Analyst
        self._analyst = AnalystAgent(structured_tools=self._structured_tools)

    # ---------- Local, deterministic runners (Option A) ----------
    def positions(self, portfolio_code: str, as_of: date) -> AnalystAnswer:
        """
        Positions snapshot for a portfolio as of date (no LLM)
        """
        return self._analyst.positions_today(
            portfolio_code = portfolio_code,
            as_of = as_of
        )

    def trades (
        self,
        portfolio_code: str,
        instrument_code: str,
        as_of: date,
    ) -> AnalystAnswer:
        """
       Transaction lineage for a single instrument in a portfolio
       """
        return self._analyst.show_trades(
            portfolio_code = portfolio_code,
            instrument_code = instrument_code,
            as_of = as_of,
        )

    def prices(
            self,
            instrument_code: str,
            from_date: date,
            to_date: date,
            source: Optional[str] = None,
            base_currency: Optional[str] = None,
     ) -> AnalystAnswer:
        """
        Price time series for an instrument (optionally normalized to base currency
        """
        return self._analyst.prices(
            instrument_code = instrument_code,
            from_date = from_date,
            to_date = to_date,
            source = source,
            base_currency = base_currency
        )

    def pnl (
        self,
        portfolio_code: str,
        as_of: date,
        prior: date,
        instrument_code=None) -> AnalystAnswer:
        """
        PnL proxy: delt of market value between two dates; for portfolio or instrument
        """
        return self._analyst.why_pnl_changed (
            portfolio_code = portfolio_code,
            as_of = as_of,
            prior = prior,
            instrument_code = instrument_code,
        )