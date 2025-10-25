# src/ai_gateway/tools/structured.py
from __future__ import annotations
import logging
from typing import Any, Dict
from ai_gateway.clients.ibor_client import IborClient

log = logging.getLogger(__name__)

class StructuredTools:
    """
    Synchronous tool wrappers around the IBOR structured API.
    Keep these small—validation/formatting for agent consumption, no heavy logic.
    """

    def __init__(self, client: IborClient | None = None) -> None:
        self._client = client or IborClient()

    # -------- Public tool methods --------

    def positions(self, portfolio_code: str, as_of: str) -> Dict[str, Any]:
        """
        Return portfolio-level positions snapshot for a given as_of date.
        """
        log.info("StructuredTools.positions portfolio=%s as_of=%s", portfolio_code, as_of)
        data = self._client.get_positions(portfolio_code=portfolio_code, as_of=as_of)

        # Optionally, you can normalize field names or attach a contract version here
        # data["contractVersion"] = 1
        return data

    def position_drilldown(
            self,
            portfolio_code: str,
            instrument_code: str,
            as_of: str,
            lot_view: str = "NONE",
    ) -> Dict[str, Any]:
        """
        Return instrument-level drilldown (fills/adjustments/lots) for a portfolio on a date.
        """
        log.info(
            "StructuredTools.position_drilldown portfolio=%s instrument=%s as_of=%s lot_view=%s",
            portfolio_code,
            instrument_code,
            as_of,
            lot_view,
        )
        data = self._client.get_position_drilldown(
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            as_of=as_of,
            lot_view=lot_view,
        )
        # data["contractVersion"] = 1
        return data