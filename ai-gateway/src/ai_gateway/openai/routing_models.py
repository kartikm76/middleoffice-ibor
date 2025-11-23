# src/ai_gateway/openai/routing_models.py

from __future__ import annotations

from typing import Optional, Literal, TypedDict


class ToolDecision(TypedDict, total=False):
    """
    Decision produced by the LLM router.

    Keys are camelCase because that’s what we send/expect in JSON, but your
    internal Python code can still use snake_case locals.
    """
    tool: Literal["positions", "trades", "pnl", "prices"]
    portfolioCode: Optional[str]
    instrumentCode: Optional[str]
    asOf: Optional[str]   # "YYYY-MM-DD"
    prior: Optional[str]  # "YYYY-MM-DD" for pnl
    fromDate: Optional[str]
    toDate: Optional[str]