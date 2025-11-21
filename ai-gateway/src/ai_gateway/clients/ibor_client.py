# src/ai_gateway/clients/ibor_client.py
import httpx
from typing import Optional, Dict, Any, List, Union
from datetime import date
from ai_gateway.config import settings

class IborClient:
    def __init__(self, base_url: Optional[str] = None):
        self._base = (base_url or settings.structured_api_base).rstrip('/')

    @property
    def base(self) -> str:
        return self._base

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
            from_date: Union[str, date], ##Union[str, date] is a type hint that allows either a string or a date object to be passed as the from_date parameter.
            to_date: Union[str, date],
            source: Optional[str] = None,
            base_currency: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        url = f"{self._base}/prices/{instrument_code}"

        def _iso(x: Union[str, date]) -> str:
            return x.isoformat() if isinstance(x, date) else str(x)

        params = {"from": _iso(from_date), "to": _iso(to_date)}
        if source:
            params["source"] = source
        if base_currency:
            params["baseCurrency"] = base_currency

        with httpx.Client(timeout = 15, verify = False) as client:
            r = client.get(url, params = params)
            r.raise_for_status()
            return r.json()