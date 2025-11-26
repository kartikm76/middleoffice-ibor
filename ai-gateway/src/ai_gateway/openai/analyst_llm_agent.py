from __future__ import annotations

import json
from datetime import date
from typing import Optional, Dict, Any, List

from openai import OpenAI
from openai.types.chat import (
    ChatCompletionMessageParam,
    ChatCompletionSystemMessageParam,
    ChatCompletionUserMessageParam,
)
from httpx import HTTPStatusError

from ai_gateway.agents.analyst import AnalystAnswer
from ai_gateway.openai.tool_runners import PositionsRunner, TradesRunner, PnLRunner, PricesRunner, ToolRunner
from ai_gateway.utils.jsonable import to_jsonable

SYSTEM_PROMPT_ANALYST_AGENT = """
You are IBOR AnalystAgent.

Your tools give you **ground-truth numbers** for an Investment Book of Record (IBOR):
- positions(portfolioCode, asOf, baseCurrency?, source?)
- trades(portfolioCode, instrumentCode, asOf)
- pnl(portfolioCode, asOf, prior, instrumentCode?)
- prices(instrumentCode, fromDate, toDate, source?, baseCurrency?)

Rules (non-negotiable):
- Never invent numbers. All numeric values must come from tool results.
- Always include 'asOf' and 'portfolioCode' in numeric answers when relevant.
- If inputs are missing, you may ask for clarification, but the caller may also fill defaults.
- If tools return no data, say what is missing in a 'gaps' section.

Output format:
You do NOT need to build JSON yourself.
Just ask for tools as needed.
The caller will convert your tool results into the final JSON envelope.
"""

class AnalystLLMAgent:
    """
       Phase 1B – Skeleton for the real OpenAI Agents integration.

       Responsibilities (when fully implemented in later steps):
       - Hold the OpenAI client and configuration.
       - Know (or create) the underlying OpenAI Agent (agent_id).
       - Start runs for a given user question + hints (portfolioCode, asOf, etc.).
       - Retrieve the final structured JSON answer from the Agent.

       This class:
       - Has *no* FastAPI/HTTP knowledge.
       - Does *not* know about Spring / IborClient directly.
       - Will rely on tools registered in the OpenAI Agent configuration
    """

    def __init__(
            self,
            client: OpenAI,
            positions_runner: PositionsRunner,
            trades_runner: TradesRunner,
            pnl_runner: PnLRunner,
            prices_runner: PricesRunner,
            model: str = "gpt-4.1-mini",
    ) -> None:
        self._client = client
        self._model = model

        self._runners: Dict[str, ToolRunner] = {
            "positions": positions_runner,
            "trades": trades_runner,
            "pnl": pnl_runner,
            "prices": prices_runner,
        }
        # “Agent config” kept locally; easy to swap to real Agents API later
        self._agent_config: dict[str, Any] | None = None

    # -------------------------------------------------------------------------
    # Public entry point
    # -------------------------------------------------------------------------
    def run_question(
        self,
        question: str,
        portfolio_code: Optional[str] = None,
        as_of: Optional[date] = None,
    ) -> AnalystAnswer:
        """
            High-level entry point for the OpenAI Agent.
            1) Calls _ensure_agent() to get tools + system prompt.
            2) Calls _run_agent() to do:
               - LLM → tool-call selection
               - ToolRunner execution
            3) Returns AnalystAnswer (deterministic envelope).
        """
        hints: Dict[str, Any] = {}
        if portfolio_code:
            hints['portfolioCode'] = portfolio_code
        if as_of:
            hints['as_of'] = as_of

        return self._run_agent(question, hints)

    # -------------------------------------------------------------------------
    # Step 1: “Agent config” (local for now)
    # -------------------------------------------------------------------------
    def _ensure_agent(self) -> Dict[str, Any]:
        """
        For now, this just builds a generic agent config.
        Later, it can be replaced with:
        - A real OpenAI Agents API (using openai-agents-python SDK)
        - OR a response from a real Agents API (e.g. via HTTP)
        """
        if self._agent_config is not None:
            return self._agent_config

        self._agent_config = {
            "model": self._model,
            "system_prompt": SYSTEM_PROMPT_ANALYST_AGENT,
            "tools": self._tool_schemas(),
        }
        return self._agent_config

    def _tool_schemas(self) -> List[Dict[str, Any]]:
        """
        Tool JSON schema for each capability.

        These are standard OpenAI function tools:
        - type: "function"
        - function: { name, description, parameters }
        """
        return [
            {
                "type": "function",
                "function": {
                    "name": "positions",
                    "description": "Get positions for a portfolio as of a date, optionally normalized to a base currency.",
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
                    "description": "Compute a PnL proxy as market value delta between two dates for a portfolio or instrument.",
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
                    "description": "Get a historical price series for an instrument between two dates.",
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

    # -------------------------------------------------------------------------
    # Step 2: run question → tools → final answer
    # -------------------------------------------------------------------------
    def _run_agent(self, question: str, hints: Dict[str, Any]) -> AnalystAnswer | None:
        """
        Minimum tool-calling loop using chat.completions:
        1. Call LLM with system prompt + tools + user question (+hints)
        2. If the model returns a tool_call:
            - Parse its name/arguments
            - Dispatch to the corresponding ToolRunner
            - Return the AnalystAnswer from that runner (numeric + summary)

        3. If no tool_call is required:
            - Return a "gaps-only" AnalystAnswer sating we could not pickup a tool
        """
        agent_config = self._ensure_agent()

        user_payload = {
            "question": question,
            "hints": to_jsonable(hints),
        }
        system_message: ChatCompletionSystemMessageParam = {
            "role": "system",
            "content": agent_config["system_prompt"],
        }
        user_message: ChatCompletionUserMessageParam = {
            "role": "user",
            "content": json.dumps(user_payload),
        }
        messages: List[ChatCompletionMessageParam] = [system_message, user_message]

        response = self._client.chat.completions.create(
            model = agent_config["model"],
            messages = messages,
            tools = agent_config["tools"],
            tool_choice = "auto"
        )
        response_message = response.choices[0].message

        # No tool call → we cannot safely answer numerically; return gaps-only envelope
        if not getattr(response_message, "tool_calls", None):
            return AnalystAnswer(
                contract_version = 1,
                question = question,
                as_of = date.today(),
                portfolio_code = hints.get("portfolioCode"),
                instrument_code = None,
                data = {},
                summary = None,
                citations = [],
                gaps = [
                    "LLM did not select a tool; cannot provide numeric answer safely"
                ],
                diagnostics = {"note": "no_tool_call"},
            )

        tool_call = response_message.tool_calls[0]
        tool_name = tool_call.function.name

        try:
            args: Dict[str, Any] = json.loads(tool_call.function.arguments or "{}")
        except json.JSONDecodeError:
            args = {}

        runner = self._runners.get(tool_name)
        if runner is None:
            # Unknown tool name; again, fail safe
            return AnalystAnswer(
                contract_version = 1,
                question = question,
                as_of = date.today(),
                portfolio_code = hints.get("portfolioCode"),
                instrument_code = None,
                data = {},
                summary = None,
                citations = [],
                gaps = [f"Model requested unknown tool '{tool_name}'."],
                diagnostics = {"toolName": tool_name},
            )
        # Map raw args + hints into a "decision" dict that your existing runners expect.
        decision = self._build_decision(tool_name, args, hints)

        # Delegate to ToolRunner (which calls AnalystAgent → StructuredTools → Spring)
        try:
            answer = runner.run(decision, question)
        except HTTPStatusError as exc:
            status_code = exc.response.status_code if exc.response else None
            as_of_str = decision.get("asOf") or hints.get("asOf")
            as_of_date = None
            if isinstance(as_of_str, str):
                try:
                    as_of_date = date.fromisoformat(as_of_str)
                except ValueError:
                    as_of_date = None
            return AnalystAnswer(
                contract_version=1,
                question=question,
                as_of=as_of_date or date.today(),
                portfolio_code=decision.get("portfolioCode") or hints.get("portfolioCode"),
                instrument_code=decision.get("instrumentCode"),
                data={},
                summary=None,
                citations=[],
                gaps=[
                    "Structured data service failed to respond successfully; please retry or contact support."
                ],
                diagnostics={
                    "note": "structured_api_error",
                    "status_code": status_code,
                    "url": str(exc.request.url) if exc.request else None,
                },
            )

        return answer

    def _build_decision(
        self,
        tool_name: str,
        args: Dict[str, Any],
        hints: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Convert tool_call arguments + hints into the canonical decision dict
        that your ToolRunner implementations expect.

        This keeps “Agent → Runner” mapping in one place.
        """
        # Start with hints as defaults, then overlay explicit args

        decision: Dict[str, Any] = {
            "tool": tool_name,
            "portfolioCode": hints.get("portfolioCode"),
            "instrumentCode": None,
            "asOf": hints.get("asOf"),
            "prior": None,
            "fromDate": None,
            "toDate": None,
            "baseCurrency": None,
            "source": None,
        }

        # Overlay arguments from the tool call
        for k, v in args.items():
            # Normalize a bit for safety
            if isinstance(v, str):
                v = v.strip()
            decision[k] = v

        # If asOf missing but fromDate/toDate present, you could choose a convention; for now, leave as is.
        return decision

















