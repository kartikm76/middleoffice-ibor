from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from ai_gateway.tools.structured import StructuredTools

@dataclass (frozen=True)
class Citation:
    """
    Minimal citation model: points back to a specific structured call and
    the exact payload fragment we used for numbers.
    """
    source: str                    # e.g., "structured.positions"
    params: Dict[str, Any]         # the exact params we called with
    fragment: Dict[str, Any]       # the exact JSON fragment we used

@dataclass
class AnalystAnswer:
    """
    What the AnalystAgent returns to the controller:
    - 'text' is safe-to-render narrative
    - 'data' is machine-friendly structured echo
    - 'citation
    """
    text: str
    data: Dict[str, Any] = field(default_factory=dict)
    citations: List[Citation] = field(default_factory=list)

class AnalystAgent:
    """
    Deterministic, numbers-from-tools-only layer.
    This does NOT call OpenAI directly; it prepares grounded answers
    that can be fed to a higher-level LLM 'composer' later if desired.
    """
    def __init__(self, structured_tools: Optional[StructuredTools] = None) -> None:
        self.tools = structured_tools or StructuredTools()

    # ----------------------------
    # Happy-path #1: positions today
    # ----------------------------
    def positions_today(self, portfolio_code: str, as_of: str) -> AnalystAnswer:
        """
        Returns the position rows for the portfolio at 'as_of'.
        Guardrails: numbers are returned from the structured API.
        """
        payload = self.tools.positions(portfolio_code=portfolio_code, as_of=as_of)

        rows = payload if isinstance(payload, list) else payload.get("positions", [])
        total_mv = sum(
            (row.get("marketValue") or 0) for row in rows if isinstance(row, dict)
        )

        txt = (
            f"Positions for portfolio {portfolio_code} as of {as_of}: "
            f"{len(rows)} instruments. "
            f"Total market value = {total_mv} (sum of row.marketValue)."
        )

        citations = [
            Citation(
                source="structured_positions",
                params={"portfolioCode": portfolio_code, "asOf": as_of},
                fragment={"positions": rows},
            )
        ]
        return AnalystAnswer(text=txt, data={"positions": rows, "totalMarketValue": total_mv}, citations=citations)

    # ----------------------------
    # Happy-path #2: show trades (instrument drill-down)
    # ----------------------------
    def show_trades(self, portfolio_code: str, instrument_code: str, as_of: str) -> AnalystAnswer:
        """
        Returns ordered list of transactions contributing to the position on 'as_of'.
        """
        dd = self.tools.position_drilldown(
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            as_of=as_of,
            lot_view="NONE",
        )

        transactions = dd.get("transactions", []) if isinstance(dd, dict) else []
        sorted_transactions = sorted(
                                (t for t in transactions if isinstance(t, dict)),
                                key=lambda t: (t.get("ts") or "", t.get("source") or ""),
                                )

        net_quantity = dd.get("netQuantity", 0)

        txt = (
            f"Transaction lineage for {instrument_code} in {portfolio_code} as of {as_of}: "
            f"{len(sorted_transactions)} transactions; net quantity = {net_quantity}."
        )

        citations = [
            Citation(
                source="structured.position_drilldown",
                params={
                    "portfolioCode": portfolio_code,
                    "instrumentCode": instrument_code,
                    "asOf": as_of,
                    "lotView": "NONE",
                },
                fragment={"transactions": sorted_transactions, "netQty": net_quantity},
            )
        ]
        return AnalystAnswer(text=txt, data={"transactions": sorted_transactions, "netQuantity": net_quantity}, citations=citations)

    # ----------------------------
    # Happy-path #3: why did PnL change (v1 placeholder)
    # ----------------------------
    def why_pnl_changed(self,
                        portfolio_code: str,
                        as_of: str,
                        prior: str,
                        instrument_code: Optional[str] = None) -> AnalystAnswer:

        """
        v1 lightweight: compare instrument counts/marketValue across two dates.
        (We avoid price math here; the numeric story still comes from the tool payloads.)
        """
        current = self.tools.positions(portfolio_code=portfolio_code, as_of=as_of)
        previous = self.tools.positions(portfolio_code=portfolio_code, as_of=prior)

        def market_value_sum(rows: Any) -> float:
            arr = rows if isinstance(rows, list) else rows.get("positions", [])
            return float(sum((row.get("marketValue") or 0) for row in arr if isinstance(row, dict)))

        market_value_current = market_value_sum(current)
        market_value_previous = market_value_sum(previous)
        delta = market_value_current - market_value_previous

        scope_text = (
            f"instrument {instrument_code}" if instrument_code else "the portfolio"
        )

        txt = (
            f"PnL proxy (market value delta) for {scope_text} in {portfolio_code} "
            f"from {prior} → {as_of}: Δ ≈ {delta} "
            f"(MV_now={market_value_current} − MV_prev={market_value_previous})."
        )

        citations = [
            Citation(
                source="structured.positions",
                params={"portfolioCode": portfolio_code, "asOf": as_of},
                fragment=current if isinstance(current, dict) else {"positions": current},
            ),
            Citation(
                source="structured.positions",
                params={"portfolioCode": portfolio_code, "asOf": prior},
                fragment=previous if isinstance(previous, dict) else {"positions": previous},
            ),
        ]
        return AnalystAnswer(
            text=txt,
            data={
                "asOf": as_of,
                "prior": prior,
                "marketValueNow": market_value_current,
                "marketValuePrev": market_value_previous,
                "delta": delta,
            },
            citations=citations,
        )