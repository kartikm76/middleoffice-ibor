from __future__ import annotations

import asyncio
import json
import logging
import re
from datetime import date, timedelta
from typing import Any, Dict, List, Optional, Tuple

from anthropic import AsyncAnthropic

from ai_gateway.model.schemas import IborAnswer
from ai_gateway.service.ibor_service import IborService
from ai_gateway.service.market_tools import MarketTools

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

_INTENT_SYSTEM = """\
You are analyzing a portfolio manager's question to determine what data to fetch.
Today's date: {today}

Available IBOR tools:
- positions: portfolio holdings as-of a date         (portfolioCode, asOf required; optional: accountCode)
- pnl:       P&L delta between two dates             (portfolioCode, asOf, prior required)
- trades:    transaction history for one instrument  (portfolioCode, instrumentCode, asOf required)
- prices:    historical price series                 (instrumentCode, fromDate, toDate required)

Call plan_query with your analysis plan. Rules:
- Use positions for "what do I hold", "exposure", "portfolio overview" questions.
- Use pnl for "performance", "P&L", "how did I do" — default prior to yesterday.
- Use trades ONLY when a specific instrument is named in the question.
- Use prices ONLY when price history is explicitly requested.
- explicit_tickers: ONLY tickers the user directly names (e.g. "AAPL", "MSFT"). Do NOT infer.
- needs_macro: true for rate, FX, macro, or portfolio-level performance questions.
- Extract portfolioCode from the question if present; otherwise omit it from args.
"""

_SYNTHESIS_SYSTEM = """\
You are a senior portfolio analyst at an asset management firm.
A portfolio manager has asked a question. You have two categories of data:

IBOR DATA — your firm's investment book of record. These numbers are ground truth.
Use them exactly as given. Never estimate, round, or invent figures.

MARKET CONTEXT — live data from Yahoo Finance (prices, news, earnings, macro indices).
Use this to add intelligence, not to contradict IBOR facts.

Write a 4-8 sentence analyst-grade response that:
1. Answers the question directly using IBOR facts (exact numbers, positions, dates).
2. Layers in market context: current price movement, upcoming events, relevant news.
3. Surfaces the key risk or opportunity the PM should be aware of.
4. Ends with a clear, actionable observation.

Rules:
- IBOR numbers are gospel — never contradict them.
- Market data enriches, it does not override.
- Flowing analyst prose — no bullet points, no headers.
- Be direct and confident; the reader is a professional who manages money.
- If any data is missing or a tool failed, mention it once briefly and continue.
- Today's date: {today}
"""

# ---------------------------------------------------------------------------
# Intent tool definition  (Anthropic format: input_schema, no type:function wrapper)
# ---------------------------------------------------------------------------

_PLAN_TOOL: Dict[str, Any] = {
    "name": "plan_query",
    "description": "Output the analysis plan: which IBOR tools to call and what market context to fetch.",
    "input_schema": {
        "type": "object",
        "properties": {
            "ibor_calls": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "tool": {
                            "type": "string",
                            "enum": ["positions", "trades", "pnl", "prices"],
                        },
                        "args": {"type": "object"},
                    },
                    "required": ["tool", "args"],
                },
            },
            "explicit_tickers": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Tickers explicitly named in the user question only.",
            },
            "needs_macro": {
                "type": "boolean",
                "description": "True if macro context (VIX, yields, S&P 500) is relevant.",
            },
        },
        "required": ["ibor_calls", "explicit_tickers", "needs_macro"],
    },
}


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

class LlmService:
    """Two-stage fan-out AI analyst.

    Stage 1  — Parse intent: one LLM call extracts which IBOR tools to call
               and any tickers explicitly named in the question.

    Stage 2a — If tickers were explicit: fire IBOR tools + all market tools
               simultaneously in a single asyncio.gather (true Octopus blast).

    Stage 2b — If no explicit tickers: fetch IBOR data first, extract equity
               tickers from the results, then fan-out all market tools in parallel.

    Final    — One synthesis LLM call that combines everything into
               analyst-grade prose.
    """

    def __init__(
        self,
        anthropic_client: AsyncAnthropic,
        service: IborService,
        market_tools: MarketTools,
        model: Optional[str] = None,
    ) -> None:
        self._anthropic = anthropic_client
        self._service = service
        self._market = market_tools
        self._model = model or "claude-sonnet-4-6"

    async def chat(self, question: str) -> IborAnswer:
        today = date.today()

        # ── Step 1: intent parse ──────────────────────────────────────────
        plan = await self._parse_intent(question, today)
        ibor_calls: List[Dict[str, Any]] = plan.get("ibor_calls", [])
        explicit_tickers: List[str] = [t.upper() for t in plan.get("explicit_tickers", [])]
        needs_macro: bool = plan.get("needs_macro", True)

        if not ibor_calls:
            return IborAnswer(
                question=question,
                as_of=today,
                gaps=["Could not determine what IBOR data to fetch for this question."],
            )

        ibor_coros = [
            self._dispatch_ibor(c["tool"], c.get("args", {}), today)
            for c in ibor_calls
        ]

        # ── Step 2: fan-out ───────────────────────────────────────────────
        if explicit_tickers:
            # True octopus: IBOR + market all at once
            market_labels, market_coros = self._build_market_coros(explicit_tickers, needs_macro)
            all_results = await asyncio.gather(*ibor_coros, *market_coros, return_exceptions=True)
            ibor_results: List[Any] = list(all_results[: len(ibor_coros)])
            market_raw: List[Any] = list(all_results[len(ibor_coros) :])
        else:
            # Two-stage: IBOR → extract tickers → market
            ibor_results = list(await asyncio.gather(*ibor_coros, return_exceptions=True))
            tickers = _extract_equity_tickers(ibor_results)
            market_labels, market_coros = self._build_market_coros(tickers, needs_macro)
            market_raw = (
                list(await asyncio.gather(*market_coros, return_exceptions=True))
                if market_coros
                else []
            )

        market_context = _collate_market(market_labels, market_raw)

        # ── Step 3: synthesis ─────────────────────────────────────────────
        return await self._synthesize(question, today, ibor_calls, ibor_results, market_context)

    # ── Intent parsing ────────────────────────────────────────────────────

    async def _parse_intent(self, question: str, today: date) -> Dict[str, Any]:
        try:
            resp = await self._anthropic.messages.create(
                model=self._model,
                max_tokens=1024,
                system=_INTENT_SYSTEM.format(today=today),
                messages=[{"role": "user", "content": question}],
                tools=[_PLAN_TOOL],
                tool_choice={"type": "tool", "name": "plan_query"},
            )
            # Anthropic returns tool use as a content block with type "tool_use"
            tool_block = next((b for b in resp.content if b.type == "tool_use"), None)
            return tool_block.input if tool_block else {}
        except Exception as exc:
            log.warning("intent parse failed: %s", exc)
            return {"ibor_calls": [], "explicit_tickers": [], "needs_macro": False}

    # ── IBOR dispatch ─────────────────────────────────────────────────────

    async def _dispatch_ibor(
        self, tool: str, args: Dict[str, Any], today: date
    ) -> IborAnswer:
        def _d(key: str, fallback: date) -> date:
            v = args.get(key)
            return date.fromisoformat(v) if isinstance(v, str) else fallback

        try:
            if tool == "positions":
                return await self._service.positions(
                    portfolio_code=args.get("portfolioCode") or "P-ALPHA",
                    as_of=_d("asOf", today),
                    account_code=args.get("accountCode"),
                    base_currency=args.get("baseCurrency"),
                    source=args.get("source"),
                )
            if tool == "pnl":
                return await self._service.pnl(
                    portfolio_code=args.get("portfolioCode") or "P-ALPHA",
                    as_of=_d("asOf", today),
                    prior=_d("prior", today - timedelta(days=1)),
                    instrument_code=args.get("instrumentCode"),
                )
            if tool == "trades":
                return await self._service.trades(
                    portfolio_code=args.get("portfolioCode") or "P-ALPHA",
                    instrument_code=args.get("instrumentCode", ""),
                    as_of=_d("asOf", today),
                )
            if tool == "prices":
                return await self._service.prices(
                    instrument_code=args.get("instrumentCode", ""),
                    from_date=_d("fromDate", today - timedelta(days=30)),
                    to_date=_d("toDate", today),
                    source=args.get("source"),
                    base_currency=args.get("baseCurrency"),
                )
        except Exception as exc:
            log.warning("ibor dispatch failed %s %s: %s", tool, args, exc)
            return IborAnswer(
                question=f"{tool}({args})",
                as_of=today,
                gaps=[f"IBOR tool '{tool}' failed: {exc}"],
            )

        return IborAnswer(
            question="",
            as_of=today,
            gaps=[f"Unknown IBOR tool requested: '{tool}'"],
        )

    # ── Market task builder ───────────────────────────────────────────────

    def _build_market_coros(
        self, tickers: List[str], needs_macro: bool
    ) -> Tuple[List[Tuple[str, Optional[str]]], List]:
        labels: List[Tuple[str, Optional[str]]] = []
        coros: List = []
        for ticker in tickers:
            labels.append(("snapshot", ticker))
            coros.append(self._market.get_market_snapshot(ticker))
            labels.append(("news", ticker))
            coros.append(self._market.get_news(ticker))
            labels.append(("earnings", ticker))
            coros.append(self._market.get_earnings(ticker))
        if needs_macro:
            labels.append(("macro", None))
            coros.append(self._market.get_macro_snapshot())
        return labels, coros

    # ── Synthesis ─────────────────────────────────────────────────────────

    async def _synthesize(
        self,
        question: str,
        today: date,
        ibor_calls: List[Dict],
        ibor_results: List,
        market_context: Dict[str, Any],
    ) -> IborAnswer:
        ibor_data: Dict[str, Any] = {}
        gaps: List[str] = []

        for call, result in zip(ibor_calls, ibor_results):
            tool = call["tool"]
            if isinstance(result, Exception):
                gaps.append(f"{tool} failed: {result}")
            elif isinstance(result, IborAnswer):
                gaps.extend(result.gaps)
                ibor_data[tool] = result.data
            else:
                gaps.append(f"{tool} returned unexpected type")

        payload = {
            "question": question,
            "as_of": str(today),
            "ibor_data": ibor_data,
            "market_context": market_context,
        }

        resp = await self._anthropic.messages.create(
            model=self._model,
            max_tokens=2048,
            system=_SYNTHESIS_SYSTEM.format(today=today),
            messages=[{"role": "user", "content": json.dumps(payload)}],
        )
        text_block = next((b for b in resp.content if b.type == "text"), None)
        summary = text_block.text if text_block else ""

        first_ok = next(
            (r for r in ibor_results if isinstance(r, IborAnswer) and not r.gaps), None
        )
        return IborAnswer(
            question=question,
            as_of=first_ok.as_of if first_ok else today,
            summary=summary,
            data={"ibor": ibor_data, "market": market_context},
            gaps=gaps,
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _extract_equity_tickers(ibor_results: List) -> List[str]:
    """Pull equity tickers from IBOR position data (instrument codes like EQ-AAPL → AAPL)."""
    tickers: set[str] = set()
    for result in ibor_results:
        if isinstance(result, IborAnswer):
            for pos in result.data.get("positions", []):
                code = str(pos.get("instrument", ""))
                # Strip EQ- prefix; ignore bonds/futures/options/fx/index
                if code.startswith("EQ-"):
                    ticker = code[3:]  # e.g. "EQ-AAPL" → "AAPL"
                    if re.match(r"^[A-Z]{1,6}$", ticker):
                        tickers.add(ticker)
    return list(tickers)[:10]  # cap to avoid excessive external API calls


def _collate_market(
    labels: List[Tuple[str, Optional[str]]], results: List
) -> Dict[str, Any]:
    """Reconstruct market results from asyncio.gather into a structured dict."""
    context: Dict[str, Any] = {"by_ticker": {}, "macro": None}
    for (label, ticker), result in zip(labels, results):
        if isinstance(result, Exception):
            log.warning("market task %s/%s failed: %s", label, ticker, result)
            continue
        if label == "macro":
            context["macro"] = result
        else:
            context["by_ticker"].setdefault(ticker, {})[label] = result
    return context