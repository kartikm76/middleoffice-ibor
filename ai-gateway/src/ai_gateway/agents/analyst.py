from typing import Any, Dict
from pydantic import BaseModel, Field
from openai import OpenAI
from ai_gateway.tools.structured import get_positions_tool, ping_tool
from ai_gateway.config import Settings

SYSTEM_PROMPT = """
You are IBOR AnalystAgent.

Rules (non-negotiable):
- Never invent numbers; all numeric outputs must come from approved tools.
- Always include 'asOf' and 'portfolioCode' in numeric answers.
- If inputs are missing, ask a single clarifying question.
- If tools return empty, say what’s missing in a 'GAPS' section.

Output format:
Respond in concise JSON ready to show in UI. Do not include prose outside JSON.
"""

class AnalystAnswer(BaseModel):
    """Top-level answer envelope the UI will render"""
    intent: str = Field(..., description="Detected intent, e.g. positions_tpday")
    asOf: str
    portfolioCode: str
    data: Dict[str, Any] = Field(default_factory=dict)
    gaps: Dict[str, Any] = Field(default_factory=dict)

def build_agent(client: OpenAI) -> "openai.agents.Agent":
    """
    Construct a single agent with one structured tool (get_positions).
    Using the OpenAI Agents SDK
    """

    agent = client.agents.create(
        model=Settings().openai_model,
        name="IBOR AnalystAgent",
        instructions=SYSTEM_PROMPT,
        tools=[get_positions_tool()],
        response_format={"type": "json_object"},
        temperature=0.1,
    )
    return agent
