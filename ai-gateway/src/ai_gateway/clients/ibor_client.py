# src/ai_gateway/clients/ibor_client.py
import httpx
from typing import Optional, Dict, Any, List
from datetime import datetime, date
from ai_gateway.config import settings

class IborClient:
    def __init__(self):
        self._base = settings.structured_api_base.rstrip('/')

    def get_positions(
            self, portfolio_code: str, as_of: str,
            base_currency: Optional[str] = None,
            source: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        url = f"{self._base}/positions"
        params = {"portfolioCode": portfolio_code, "asOf": as_of}
        if base_currency:
            params["baseCurrency"] = base_currency
        if source:
            params["source"] = source

        with httpx.Client(timeout=15, verify=False) as client:
            r = client.get(url, params=params)
            r.raise_for_status()
            return r.json()

    def get_position_drilldown(
            self, portfolio_code: str, instrument_code: str,
            as_of: str, lot_view: str = "NONE"
    ) -> Dict[str, Any]:
        url = f"{self._base}/positions/{portfolio_code}/{instrument_code}"
        params = {"asOf": as_of, "lotView": lot_view}

        with httpx.Client(timeout=15, verify=False) as client:
            r = client.get(url, params=params)
            r.raise_for_status()
            return r.json()

    def get_prices(
            self, instrument_code: str,
            from_date: date,
            to_date: date,
            source: Optional[str] = None,
            base_currency: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        url = f"{self._base}/prices/{instrument_code}"
        params = {"from": from_date, "to": to_date}
        if source:
            params["source"] = source
        if base_currency:
            params["baseCurrency"] = base_currency

        with httpx.Client(timeout=15, verify=False) as client:
            r = client.get(url, params=params)
            r.raise_for_status()
            return r.json()