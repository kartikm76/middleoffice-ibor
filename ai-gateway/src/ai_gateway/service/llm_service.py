from __future__ import annotations

import json
from datetime import date
from typing import Any, Dict, List, Optional

from openai import AsyncOpenAI

from ai_gateway.model.schemas import IborAnswer
from ai_gateway.service.ibor_service import IborService

_TOOL_SELECTION_PROMPT = """
You are IBOR Analyst. Your job is to select the right data tool for the user's question.

Available tools:
- positions(portfolioCode, asOf, baseCurrency?, source?)
- trades(portfolioCode, instrumentCode, asOf)
- pnl(portfolioCode, asOf, prior, instrumentCode?)
- prices(instrumentCode, fromDate, toDate, source?, baseCurrency?)

Rules:
- Always use a tool. Never answer from memory.
- If required parameters are missing, note them in gaps.
"""

_NARRATION_PROMPT = """
You are an IBOR analyst writing a concise answer for a portfolio manager.

Rules:
- Use only the numbers provided in the data. Never invent or estimate figures.
- Write 2-4 sentences in plain English.
- Be precise: include key numbers (market values, quantities, dates).
- Do not repeat the raw JSON — synthesise it into a natural answer.
"""

_TOOLS: List[Dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "positions",
            "description": "Get positions for a portfolio as of a date.",
            "parameters": {
                "type": "object",
                "properties": {
                    "portfolioCode": {"type": "string"},
                    "asOf": {"type": "string", "format": "date"},
                    "baseCurrency": {"type": "string"},
                    "source": {"type": "string"},
                },
                "required": ["portfolioCode", "asOf"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "trades",
            "description": "Get transaction lineage for a portfolio + instrument as of a date.",
            "parameters": {
                "type": "object",
                "properties": {
                    "portfolioCode": {"type": "string"},
                    "instrumentCode": {"type": "string"},
                    "asOf": {"type": "string", "format": "date"},
                },
                "required": ["portfolioCode", "instrumentCode", "asOf"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "pnl",
            "description": "PnL proxy: market value delta between two dates for a portfolio or instrument.",
            "parameters": {
                "type": "object",
                "properties": {
                    "portfolioCode": {"type": "string"},
                    "asOf": {"type": "string", "format": "date"},
                    "prior": {"type": "string", "format": "date"},
                    "instrumentCode": {"type": "string"},
                },
                "required": ["portfolioCode", "asOf", "prior"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "prices",
            "description": "Historical price series for an instrument between two dates.",
            "parameters": {
                "type": "object",
                "properties": {
                    "instrumentCode": {"type": "string"},
                    "fromDate": {"type": "string", "format": "date"},
                    "toDate": {"type": "string", "format": "date"},
                    "source": {"type": "string"},
                    "baseCurrency": {"type": "string"},
                },
                "required": ["instrumentCode", "fromDate", "toDate"],
            },
        },
    },
]


class LlmService:
    """Two-step AI analyst:
    1. Ask OpenAI which tool to call → fetch deterministic data from IborService.
    2. Ask OpenAI to narrate the data into a natural language summary.

    No data logic here — IborService owns all numbers.
    """

    def __init__(
        self,
        openai_client: AsyncOpenAI,
        service: IborService,
        model: Optional[str] = None,
    ) -> None:
        self._openai = openai_client
        self._service = service
        self._model = model or "gpt-4o-mini"

    async def chat(self, question: str) -> IborAnswer:
        # --- Step 1: tool selection ---
        response = await self._openai.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": _TOOL_SELECTION_PROMPT},
                {"role": "user", "content": question},
            ],
            tools=_TOOLS,
            tool_choice="auto",
        )
        msg = response.choices[0].message

        if not getattr(msg, "tool_calls", None):
            return IborAnswer(
                question=question,
                as_of=date.today(),
                gaps=["LLM did not select a tool; cannot provide a grounded answer."],
            )

        tool_call = msg.tool_calls[0]
        name = tool_call.function.name
        try:
            args: Dict[str, Any] = json.loads(tool_call.function.arguments or "{}")
        except json.JSONDecodeError:
            args = {}

        try:
            answer = await self._dispatch(name, args, date.today(), None)
        except Exception as exc:
            return IborAnswer(
                question=question,
                as_of=date.today(),
                gaps=[f"Tool '{name}' failed: {exc}"],
            )

        answer.question = question

        # --- Step 2: narration ---
        answer.summary = await self._narrate(question, answer)
        return answer

    async def _narrate(self, question: str, answer: IborAnswer) -> str:
        """Second OpenAI call: turn raw IborAnswer data into a natural language summary."""
        payload = {
            "question": question,
            "as_of": str(answer.as_of),
            "data": answer.data,
        }
        response = await self._openai.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": _NARRATION_PROMPT},
                {"role": "user", "content": json.dumps(payload)},
            ],
        )
        return response.choices[0].message.content or ""

    async def _dispatch(
        self,
        name: str,
        args: Dict[str, Any],
        fallback_as_of: date,
        fallback_portfolio: Optional[str],
    ) -> IborAnswer:
        def _date(key: str, fallback: Optional[date] = None) -> date:
            v = args.get(key)
            return date.fromisoformat(v) if isinstance(v, str) else (fallback or date.today())

        if name == "positions":
            return await self._service.positions(
                portfolio_code=args.get("portfolioCode") or fallback_portfolio,
                as_of=_date("asOf", fallback_as_of),
                base_currency=args.get("baseCurrency"),
                source=args.get("source"),
            )
        if name == "trades":
            return await self._service.trades(
                portfolio_code=args.get("portfolioCode") or fallback_portfolio,
                instrument_code=args["instrumentCode"],
                as_of=_date("asOf", fallback_as_of),
            )
        if name == "pnl":
            return await self._service.pnl(
                portfolio_code=args.get("portfolioCode") or fallback_portfolio,
                as_of=_date("asOf", fallback_as_of),
                prior=_date("prior"),
                instrument_code=args.get("instrumentCode"),
            )
        if name == "prices":
            return await self._service.prices(
                instrument_code=args["instrumentCode"],
                from_date=_date("fromDate"),
                to_date=_date("toDate"),
                source=args.get("source"),
                base_currency=args.get("baseCurrency"),
            )

        return IborAnswer(
            question="",
            as_of=fallback_as_of,
            portfolio_code=fallback_portfolio,
            gaps=[f"Unknown tool requested by model: '{name}'"],
        )
