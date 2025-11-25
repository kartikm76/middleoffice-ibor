from  __future__ import annotations

from datetime import date
from typing import Optional, Dict, Any
from dataclasses import is_dataclass, asdict

from fastapi import APIRouter
from pydantic import BaseModel, Field

from ai_gateway.openai.analyst_llm_agent import AnalystLLMAgent
from ai_gateway.schemas.common import AnalystAnswerModel

def _to_jsonable(obj: Any) -> Any:
    """
    Small helper to make sure dataclasses / nested objects
    can be fed into AnalystAnswerModel(**...) without surprises.
    """
    if is_dataclass(obj):
        return {k: _to_jsonable(v) for k, v in asdict(obj).items()}
    if isinstance(obj, list):
        return [_to_jsonable(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _to_jsonable(v) for k, v in obj.items()}
    return obj

class AnalystChatRequest(BaseModel):
    """
    Request body for LLM-driven analyst chat.

    Example JSON:
    {
      "question": "What are P-ALPHA positions as of 2025-01-03?",
      "portfolioCode": "P-ALPHA",
      "asOf": "2025-01-03"
    }
    """
    question: str = Field(..., description="The natural-language question to ask the analyst.")
    portfolio_code: Optional[str] = Field(
        None,
        alias="portfolioCode",
        description="Optional PortfolioCode to query (e.g. P-ALPHA)")
    as_of: Optional[date] = Field(
        None,
        alias="asOf",
        description="Optional date for the query (e.g. 2023-10-01)")

    class Config:
        populate_by_name = True
        json_schema_extra = {
            "example": {
                "question": "What are P-ALPHA positions as of 2025-01-03?",
                "portfolioCode": "P-ALPHA",
                "asOf": "2025-01-03"
            }
        }

    def create_analyst_llm_router(agent: AnalystLLMAgent) -> APIRouter:
        """
        Factory so wiring stays in app/bootstrap code:
        AnalystLlmAgent is created once and passed here.
        """
        router = APIRouter(
            prefix="/analyst/analyst-llm",
            tags=["Analyst LLM"],
            responses = {
                400: {"description": "Bad request"},
                500: {"description": "Internal error"},
            },
        )

        @router.post(
            "/chat",
            response_model = AnalystAnswerModel,
            summary = "LLM driven analyst chat (positions/trades/pnl/prices)",
            description = (
                    "Uses OpenAI + tools to decide whether to call positions, trades, pnl, or prices, "
                    "then returns a grounded AnalystAnswerModel."
            ),
        )

        def chat(body: AnalystChatRequest) -> AnalystAnswerModel:
            answer = agent.run_question(
                question = body.question,
                portfolio_code = body.portfolio_code,
                as_of = body.as_of,
            )
            return AnalystAnswerModel(**_to_jsonable(answer))

        return router





