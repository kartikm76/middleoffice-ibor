# src/ai_gateway/tools/structured.py
from typing import Optional, Dict, Any, List
from datetime import datetime, date
from ai_gateway.clients.ibor_client import IborClient


class StructuredTools:
    def __init__(self):
        self._client = IborClient()

    def positions(self, portfolio_code: str, as_of: date,
                  base_currency: Optional[str], source: Optional[str]) -> List[Dict[str, Any]]:
        return self._client.get_positions(portfolio_code, as_of, base_currency, source)

    def position_drilldown(self, portfolio_code: str, instrument_code: str,
                  as_of: date, lot_view: str = "NONE") -> Dict[str, Any]:
        return self._client.get_position_drilldown(portfolio_code, instrument_code, as_of, lot_view)

    def instrument_prices(self, instrument_code: str, from_date: date, to_date: date,
               source: Optional[str], base_currency: Optional[str]) -> List[Dict[str, Any]]:
        return self._client.get_prices(instrument_code, from_date, to_date, source, base_currency)