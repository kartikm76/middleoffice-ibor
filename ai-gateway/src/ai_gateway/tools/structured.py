# src/ai_gateway/tools/structured.py
from datetime import date
from typing import Optional, Dict, Any
from ai_gateway.clients.ibor_client import IborClient

class StructuredTools:
    def __init__(self, ibor_client: Optional[IborClient] = None) -> None:
        self.client = ibor_client or IborClient()

    def _wrap(self, maybe_list, root_key: str) -> Dict[str, Any]:
        # If Spring returns a JSON array, wrap it so we can attach _citation safely
        if isinstance(maybe_list, list):
            return {root_key: maybe_list}
        return maybe_list if isinstance(maybe_list, dict) else {root_key: []}

    # ---------------- Positions ----------------
    def positions(
            self,
            portfolio_code: str,
            as_of: date,
            base_currency: Optional[str] = None,
            source: Optional[str] = None,
    ) -> Dict[str, Any]:
        raw = self.client.get_positions(
            portfolio_code=portfolio_code,
            as_of=as_of.isoformat(),
            base_currency=base_currency,
            source=source,
        )
        payload = self._wrap(raw, "positions")

        qs_parts = [f"portfolioCode={portfolio_code}", f"asOf={as_of.isoformat()}"]
        if base_currency:
            qs_parts.append(f"baseCurrency={base_currency}")
        if source:
            qs_parts.append(f"source={source}")
        qs = "&".join(qs_parts)

        payload["_citation"] = {
            "kind": "structured",
            "title": "Positions API",
            "source": f"/api/positions?{qs}",
            "url": f"{self.client.base}/positions?{qs}",
        }
        return payload

    # ------------- Instrument Drilldown -------------
    def position_drilldown(
            self,
            portfolio_code: str,
            instrument_code: str,
            as_of: date,
    ) -> Dict[str, Any]:
        payload = self.client.get_position_drilldown(
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            as_of=as_of.isoformat(),
        )
        # If someone returns a list by mistake, still make it a dict with 'transactions'
        if isinstance(payload, list):
            payload = {"transactions": payload}

        payload["_citation"] = {
            "kind": "structured",
            "title": "Position Drilldown API",
            "source": f"/api/positions/{portfolio_code}/{instrument_code}?asOf={as_of.isoformat()}",
            "url": f"{self.client.base}/positions/{portfolio_code}/{instrument_code}?asOf={as_of.isoformat()}",
        }
        return payload

    # ---------------- Prices ----------------
    def instrument_prices(
            self,
            instrument_code: str,
            from_date: date,
            to_date: date,
            source: Optional[str] = None,
            base_currency: Optional[str] = None,
    ) -> Dict[str, Any]:
        raw = self.client.get_prices(
            instrument_code=instrument_code,
            from_date=from_date.isoformat(),
            to_date=to_date.isoformat(),
            source=source,
            base_currency=base_currency,
        )
        payload = self._wrap(raw, "prices")

        qs_parts = [f"from={from_date.isoformat()}", f"to={to_date.isoformat()}"]
        if source:
            qs_parts.append(f"source={source}")
        if base_currency:
            qs_parts.append(f"baseCurrency={base_currency}")
        qs = "&".join(qs_parts)

        payload["_citation"] = {
            "kind": "structured",
            "title": "Prices API",
            "source": f"/api/prices/{instrument_code}?{qs}",
            "url": f"{self.client.base}/prices/{instrument_code}?{qs}",
        }
        return payload