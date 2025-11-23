# src/ai_gateway/openai/analyst_chat_agent.py

from __future__ import annotations

import json
from datetime import date
from typing import Any, Dict, Optional

from openai import OpenAI

from ai_gateway.agents.analyst import AnalystAgent, AnalystAnswer
from ai_gateway.openai.routing_models import ToolDecision
from ai_gateway.openai.tool_runners import (
    ToolRunner,
    PositionsRunner,
    TradesRunner,
    PnLRunner,
    PricesRunner,
)

SYSTEM_PROMPT_ROUTER = """
You are an IBOR Analyst *router*.

Your ONLY job:
- Read the user's question + optional hints.
- Decide which ONE of these tools is appropriate:

  - "positions": Answer questions about current holdings, exposures, or positions for a portfolio.
  - "trades": Answer questions about trades / transactions / fills that make up a position in a portfolio.
  - "pnl":   Answer questions about how PnL / market value changed between two dates.
  - "prices": Answer questions about historical price series, min/max charts, moving windows, or “what was IBM’s price last week?”

Return STRICT JSON with this shape (no prose, no extra fields):

{
  "tool": "positions" | "trades" | "pnl",
  "portfolioCode": "<string or null>",
  "instrumentCode": "<string or null>",
  "asOf": "<YYYY-MM-DD or null>",
  "prior": "<YYYY-MM-DD or null>",
  "fromDate": "<YYYY-MM-DD or null>",
  "toDate": "<YYYY-MM-DD or null>"
}

Rules:
- If the user talks about "today's positions", "what do I hold", "exposure", pick "positions".
- If the user talks about "trades", "fills", "transactions that made up position", pick "trades".
- If the user talks about "PnL", "profit/loss", "change between two dates", pick "pnl".
- If the user talks about "historical prices", "price series",  "chart", "min/max", "window", pick "prices".
- If the user does not give portfolioCode or asOf, leave them null (the caller may fill defaults).
- NEVER include any text outside of a single valid JSON object.
"""

class OpenAiAnalystChatAgent:
    """
    Phase 1, Step 1 (refactored):

    - Uses OpenAI to classify the question -> ToolDecision
    - Delegates execution to dedicated ToolRunner instances (positions / trades / pnl / prices)
    - Returns the AnalystAnswer produced by those runners.

    This class does *not* know about HTTP, Spring, or business aggregates.
    """

    def __init__(
            self,
            client: OpenAI,
            positions_runner: ToolRunner,
            trades_runner: ToolRunner,
            pnl_runner: ToolRunner,
            prices_runner: ToolRunner,
            default_tool: str = "positions",
    ) -> None:
        self._client = client
        self._runners: Dict[str, ToolRunner] = {
            "positions": positions_runner,
            "trades": trades_runner,
            "pnl": pnl_runner,
            "prices": prices_runner,
        }
        self._default_tool = default_tool

    # ---- public API ----

    def chat(
            self,
            question: str,
            portfolio_code: Optional[str] = None,
            as_of: Optional[date] = None,
    ) -> AnalystAnswer:
        decision = self._decide_tool(question, portfolio_code, as_of)
        tool_name = decision.get("tool")
        if not tool_name or tool_name not in self._runners:
            tool_name = self._default_tool
        runner = self._runners[tool_name]
        return runner.run(decision, question)

    # ---- internal: LLM call only ----

    def _decide_tool(
            self,
            question: str,
            portfolio_code: Optional[str],
            as_of: Optional[date],
    ) -> ToolDecision:
        hints: Dict[str, Any] = {}
        if portfolio_code:
            hints["portfolioCode"] = portfolio_code
        if as_of:
            hints["asOf"] = as_of.isoformat()

        user_payload = {
            "question": question,
            "hints": hints,
        }

        resp = self._client.chat.completions.create(
            model="gpt-4.1-mini",
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_ROUTER},
                {"role": "user", "content": json.dumps(user_payload)},
            ],
        )
        content = resp.choices[0].message.content or "{}"

        try:
            parsed: ToolDecision = json.loads(content)
        except json.JSONDecodeError:
            # Defensive fallback
            return {
                "tool": self._default_tool,
                "portfolioCode": portfolio_code,
                "instrumentCode": None,
                "asOf": as_of.isoformat() if as_of else None,
                "prior": None,
                "fromDate": None,
                "toDate": None,
            }

        # Fill missing from hints
        if not parsed.get("portfolioCode") and portfolio_code:
            parsed["portfolioCode"] = portfolio_code
        if not parsed.get("asOf") and as_of:
            parsed["asOf"] = as_of.isoformat()
        if not parsed.get("fromDate") and as_of:
            parsed["fromDate"] = as_of.isoformat()
        if not parsed.get("toDate") and as_of:
            parsed["toDate"] = as_of.isoformat()

        return parsed