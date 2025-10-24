import httpx
from typing import Optional, Dict, Any
from ai_gateway.config import settings

class IBORClient:
    """
    HTTP client to call Spring Boot structured data API.
    Single responsibility: send requests to IBOR structured data API and return responses.
    No business logic here.
    """

    def __init__(self):
        self._base = settings.strructured_api_base.rstrip('/')
    
    async def get_positions(self, portfolio_code: str, as_of: str) -> Dict[str, Any]:
        url = f"{self._base}/positions"
        params = {"portfolioCode:":portfolio_code, "asOf": as_of}

        async with httpx.AsyncClient(timeout=10.0, verify=False) as client:
            r = await client.get(url, params=params)
        r.raise_for_status()
        return r.json()
    
    async def get_position_drilldown(self, portfolio_code: str, instrument_code: str, as_of: str) -> Dict[str, Any]:
        url = f"{self._base}/positions/{portfolio_code}/{instrument_code}"
        params = {"asOf": as_of}
        
        async with httpx.AsyncClient(timeout=10.0, verify=False) as client:
            r = await client.get(url, params=params)
        r.raise_for_status()
        return r.json()
    
    async def get_prices(self, instrument_code: str, from_date: str, to_date: str, 
                         source: Optional[str] = None, base_currency: Optional[str] = None) -> Dict[str, Any]:
        url = f"{self._base}/prices/{instrument_code}"
        params = {"from": from_date, "to": to_date}

        if source:
            params["source"] = source
        if base_currency:
            params["baseCurrency"] = base_currency

        async with httpx.AsyncClient(timeout=10.0, verify=False) as client:
            r = await client.get(url, params=params)
        r.raise_for_status()
        return r.json()