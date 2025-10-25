# src/ai_gateway/clients/ibor_client.py
from __future__ import annotations
import logging
from typing import Any, Dict, Optional
import httpx
from ai_gateway.config import settings

log = logging.getLogger(__name__)

class IborClient:
    """
    Thin HTTP client for the IBOR structured API (Spring Boot).
    No business logic here—just request/response handling.
    """

    def __init__(
            self,
            base_url: Optional[str] = None,
            timeout_seconds: float = 10.0,
            verify_tls: bool = True,
    ) -> None:
        self._base = (base_url or settings.structured_api_base).rstrip("/")
        self._timeout = timeout_seconds
        self._verify = verify_tls

        # Single reusable sync client
        self._client = httpx.Client(timeout=self._timeout, verify=self._verify)

    # ---------- Positions (portfolio-level) ----------
    def get_positions(self, portfolio_code: str, as_of: str) -> Dict[str, Any]:
        """
        GET /api/positions?portfolioCode=...&asOf=YYYY-MM-DD
        """
        url = f"{self._base}/positions"
        params = {"portfolioCode": portfolio_code, "asOf": as_of}
        log.debug("GET %s params=%s", url, params)

        r = self._client.get(url, params=params)
        r.raise_for_status()
        return r.json()

    # ---------- Instrument drill-down ----------
    def get_position_drilldown(
            self,
            portfolio_code: str,
            instrument_code: str,
            as_of: str,
            lot_view: str = "NONE",
    ) -> Dict[str, Any]:
        """
        GET /api/positions/{portfolioCode}/{instrumentCode}?asOf=YYYY-MM-DD&lotView=NONE
        """
        url = f"{self._base}/positions/{portfolio_code}/{instrument_code}"
        params = {"asOf": as_of, "lotView": lot_view}
        log.debug("GET %s params=%s", url, params)

        r = self._client.get(url, params=params)
        r.raise_for_status()
        return r.json()

    # ---------- Lifecycle ----------
    def close(self) -> None:
        try:
            self._client.close()
        except Exception:  # pragma: no cover
            log.exception("Error closing IborClient httpx.Client")

    def __del__(self) -> None:  # pragma: no cover
        self.close()