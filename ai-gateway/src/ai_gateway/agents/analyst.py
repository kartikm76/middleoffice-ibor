# src/ai_gateway/agents/analyst.py
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, date
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, List, Literal, Optional

from ai_gateway.tools.structured import StructuredTools


# ----------------------------
# Dataclasses returned to router
# ----------------------------

@dataclass
class Citation:
    """Source pointer for numbers (structured) or narrative (rag)."""
    kind: Literal["structured", "rag"]
    source: str
    url: Optional[str] = None
    title: Optional[str] = None
    score: Optional[float] = None
    chunk_id: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None


@dataclass
class AnalystAnswer:
    """Stable envelope the router maps into AnalystAnswerModel (Pydantic)."""
    contract_version: int
    question: str
    as_of: date
    portfolio_code: Optional[str] = None
    instrument_code: Optional[str] = None

    data: Dict[str, Any] = field(default_factory=dict)     # raw payload from tools (unchanged)
    summary: Optional[str] = None                          # short narrative from computed aggregates
    citations: List[Citation] = field(default_factory=list)
    gaps: List[str] = field(default_factory=list)

    created_at: datetime = field(default_factory=datetime.now)
    diagnostics: Optional[Dict[str, Any]] = None


# ----------------------------
# Agent (Option A)
# ----------------------------

class AnalystAgent:
    """
    Option A:
      - Uses StructuredTools to fetch raw numbers.
      - Computes *small derived aggregates* (e.g., sums) for summary/diagnostics ONLY.
      - Never mutates the raw 'data' block returned by tools.
    """

    def __init__(self, structured_tools: StructuredTools) -> None:
        self.tools = structured_tools
        self.contract_version = 1

    # -------- positions today --------
    def positions_today(self, portfolio_code: str, as_of: date) -> AnalystAnswer:
        payload = self.tools.positions(portfolio_code=portfolio_code, as_of=as_of, base_currency=None, source=None)
        positions = _extract_positions(payload)

        # Aggregates (grounded on payload)
        total_mv = _sum_decimal(p.get("marketValue") for p in positions)
        total_qty = _sum_decimal(p.get("netQty") for p in positions)
        currencies = sorted({(p.get("currency") or "").upper() for p in positions if p.get("currency")})
        count_instr = len(positions)

        # Structured citation (if tool attached one)
        citations = _extract_structured_citation(payload)

        summary = (
                f"{portfolio_code} has {count_instr} instruments as of {as_of}; "
                f"sum(marketValue)={total_mv} " + ("/".join(currencies) if currencies else "")
        ).strip()

        return AnalystAnswer(
            contract_version=self.contract_version,
            question=f"positions({portfolio_code}, {as_of})",
            as_of=as_of,
            portfolio_code=portfolio_code,
            data=payload if isinstance(payload, dict) else {"positions": positions},
            summary=summary,
            citations=citations,
            diagnostics={
                "countInstruments": count_instr,
                "sumMarketValue": str(total_mv),
                "sumNetQty": str(total_qty),
                "currencies": currencies,
            },
        )

    # -------- transaction lineage (instrument) --------
    def show_trades(self, portfolio_code: str, instrument_code: str, as_of: date) -> AnalystAnswer:
        payload = self.tools.position_drilldown(
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            as_of=as_of,
        )

        # Expect tool to return { transactions: [...], lots: [...] } or at least transactions[]
        transactions = _extract_transactions(payload)

        # Aggregates for summary (grounded on payload)
        gross = _sum_decimal(_mul(p.get("quantity"), p.get("price")) for p in transactions)
        net_qty = _sum_decimal(p.get("quantity") for p in transactions)
        n_trades = len(transactions)

        citations = _extract_structured_citation(payload)

        summary = (
            f"{instrument_code} in {portfolio_code} as of {as_of}: "
            f"{n_trades} transactions, netQty={net_qty}, gross≈{gross}"
        )

        return AnalystAnswer(
            contract_version=self.contract_version,
            question=f"trades({portfolio_code}, {instrument_code}, {as_of})",
            as_of=as_of,
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            data=payload if isinstance(payload, dict) else {"transactions": transactions},
            summary=summary,
            citations=citations,
            diagnostics={
                "transactionCount": n_trades,
                "netQty": str(net_qty),
                "grossAmountApprox": str(gross),
            },
        )

    # -------- prices (series) --------
    def prices(
            self,
            instrument_code: str,
            from_date: date,
            to_date: date,
            source: Optional[str] = None,
            base_currency: Optional[str] = None,
    ) -> AnalystAnswer:
        payload = self.tools.instrument_prices(
            instrument_code=instrument_code,
            from_date=from_date,
            to_date=to_date,
            source=source,
            base_currency=base_currency,
        )

        series = _extract_prices(payload)

        # Derived quick stats
        values = [_as_decimal(p.get("price")) for p in series]
        values = [v for v in values if v is not None]
        min_p = min(values) if values else None
        max_p = max(values) if values else None
        last_p = values[-1] if values else None
        count = len(values)

        citations = _extract_structured_citation(payload)

        label_ccy = None
        if series:
            label_ccy = series[-1].get("currency") or series[0].get("currency")

        summary = (
                f"Prices for {instrument_code} {from_date}→{to_date}"
                + (f" ({label_ccy})" if label_ccy else "")
                + (f": n={count}, min={min_p}, max={max_p}, last={last_p}" if count else ": no data")
        )

        # as_of here: use to_date to anchor; or omit if you prefer not to overload semantics
        return AnalystAnswer(
            contract_version=self.contract_version,
            question=f"prices({instrument_code}, {from_date}, {to_date}, source={source}, base={base_currency})",
            as_of=to_date.isoformat(),
            instrument_code=instrument_code,
            data=payload if isinstance(payload, dict) else {"prices": series},
            summary=summary,
            citations=citations,
            diagnostics={
                "count": count,
                "min": str(min_p) if min_p is not None else None,
                "max": str(max_p) if max_p is not None else None,
                "last": str(last_p) if last_p is not None else None,
                "currency": label_ccy,
            },
        )

    # -------- PnL proxy (delta of total MV) --------
    def why_pnl_changed(
            self,
            portfolio_code: str,
            as_of: str,
            prior: str,
            instrument_code: Optional[str] = None,
    ) -> AnalystAnswer:
        # current snapshot
        curr_payload = self.tools.positions(portfolio_code=portfolio_code, as_of=as_of)
        curr_positions = _extract_positions(curr_payload)

        # prior snapshot
        prior_payload = self.tools.positions(portfolio_code=portfolio_code, as_of=prior)
        prior_positions = _extract_positions(prior_payload)

        # Optionally scope to single instrument
        if instrument_code:
            curr_positions = [p for p in curr_positions if p.get("instrumentCode") == instrument_code]
            prior_positions = [p for p in prior_positions if p.get("instrumentCode") == instrument_code]

        # Sum market values
        curr_mv = _sum_decimal(p.get("marketValue") for p in curr_positions)
        prior_mv = _sum_decimal(p.get("marketValue") for p in prior_positions)
        delta = curr_mv - prior_mv

        # Citations: both calls
        citations = []
        citations.extend(_extract_structured_citation(curr_payload))
        citations.extend(_extract_structured_citation(prior_payload))

        subject = instrument_code or "portfolio"
        summary = (
            f"PnL proxy for {subject} in {portfolio_code}: "
            f"MV({as_of})={curr_mv} vs MV({prior})={prior_mv} → Δ={delta}"
        )

        # Build a compact data object
        data = {
            "asOf": as_of,
            "prior": prior,
            "scope": instrument_code or "PORTFOLIO",
            "current": {"sumMarketValue": str(curr_mv)},
            "previous": {"sumMarketValue": str(prior_mv)},
            "delta": str(delta),
        }

        return AnalystAnswer(
            contract_version=self.contract_version,
            question=f"pnl({portfolio_code}, {as_of}, prior={prior}, instrument={instrument_code})",
            as_of=as_of,
            portfolio_code=portfolio_code,
            instrument_code=instrument_code,
            data=data,
            summary=summary,
            citations=citations,
            diagnostics={
                "currCount": len(curr_positions),
                "priorCount": len(prior_positions),
            },
        )


# ----------------------------
# Helpers (pure, local)
# ----------------------------

def _extract_structured_citation(payload: Any) -> List[Citation]:
    """
    If tools attach a _citation dict like:
      {"source": ".../api/positions?...", "url": "http://..."}
    turn it into a structured Citation[]; otherwise empty.
    """
    if isinstance(payload, dict):
        cit = payload.get("_citation")
        if isinstance(cit, dict) and cit.get("source"):
            return [Citation(kind="structured", source=str(cit.get("source")), url=cit.get("url"))]
    return []


def _extract_positions(payload: Any) -> List[Dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("positions"), list):
        return [p for p in payload["positions"] if isinstance(p, dict)]
    if isinstance(payload, list):
        return [p for p in payload if isinstance(p, dict)]
    return []


def _extract_transactions(payload: Any) -> List[Dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("transactions"), list):
        return [t for t in payload["transactions"] if isinstance(t, dict)]
    return []


def _extract_prices(payload: Any) -> List[Dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("prices"), list):
        return [r for r in payload["prices"] if isinstance(r, dict)]
    if isinstance(payload, list):
        return [r for r in payload if isinstance(r, dict)]
    return []


def _as_decimal(x: Any) -> Optional[Decimal]:
    if x is None:
        return None
    try:
        return Decimal(str(x))
    except (InvalidOperation, ValueError, TypeError):
        return None


def _sum_decimal(iterable) -> Decimal:
    total = Decimal("0")
    for x in iterable:
        d = _as_decimal(x)
        if d is not None:
            total += d
    return total


def _mul(a: Any, b: Any) -> Optional[Decimal]:
    da, db = _as_decimal(a), _as_decimal(b)
    if da is None or db is None:
        return None
    return da * db