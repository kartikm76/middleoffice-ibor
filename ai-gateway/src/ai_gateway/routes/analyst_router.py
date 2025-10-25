from __future__ import annotations

from dataclasses import asdict, is_dataclass
from typing import Any, Optional

from fastapi import APIRouter, HTTPException

from ai_gateway.agents.analyst import AnalystAgent, AnalystAnswer
from ai_gateway.clients.ibor_client import IborClient
from ai_gateway.tools.structured import StructuredTools
from ai_gateway.schemas.common import AnalystAnswerModel
from ai_gateway.schemas.hybrid import (PositionsAnswer,
                                       TradesAnswer,
                                       PricesAnswer,
                                       PnLAnswer)

router = APIRouter(
    prefix="/agents/analyst",
    tags=["Analyst"],
    responses={
        400: {"description": "Bad request"},
        404: {"description": "Not found"},
        500: {"description": "Internal error"},
    },
)

# Wiring: IborClient -> StructuredTools -> AnalystAgent
_ibor_client = IborClient()
#_structured_tools = StructuredTools(ibor_client=_ibor_client)
_structured_tools = StructuredTools()
_agent = AnalystAgent(structured_tools=_structured_tools)


def _to_jsonable(obj: Any) -> Any:
    """Convert dataclasses to plain dicts recursively so FastAPI/Pydantic can serialize."""
    if is_dataclass(obj):
        return {k: _to_jsonable(v) for k, v in asdict(obj).items()}
    if isinstance(obj, list):
        return [_to_jsonable(x) for x in obj]
    if isinstance(obj, dict):
        return {k: _to_jsonable(v) for k, v in obj.items()}
    return obj


@router.post(
    "/positions",
    response_model=AnalystAnswerModel,
    summary="Positions (Analyst view)",
    description=(
            "Returns a grounded positions summary for a portfolio as of the given date. "
            "Numbers are pulled strictly from the structured service. "
            "Response includes short narrative (`summary`), raw `data`, and `citations`."
    ),
)
def positions_today(body: PositionsAnswer) -> AnalystAnswerModel:
    try:
        ans: AnalystAnswer = _agent.positions_today(
            portfolio_code=body.portfolio_code,
            as_of=body.as_of,
        )
        return AnalystAnswerModel(**_to_jsonable(ans))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"positions_today failed: {e}") from e


@router.post(
    "/trades",
    response_model=AnalystAnswerModel,
    summary="Transaction lineage (Analyst view)",
    description=(
            "Ordered list of transactions and adjustments that make up the position for the instrument "
            "as of the given date (lotting v1 = NONE)."
    ),
)
def show_trades(body: TradesAnswer) -> AnalystAnswerModel:
    try:
        ans: AnalystAnswer = _agent.show_trades(
            portfolio_code=body.portfolio_code,
            instrument_code=body.instrument_code,
            as_of=body.as_of,
        )
        return AnalystAnswerModel(**_to_jsonable(ans))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"show_trades failed: {e}") from e


@router.post(
    "/prices",
    response_model=AnalystAnswerModel,
    summary="Prices (Analyst view, optional FX normalization)",
    description=(
            "Fetches raw prices for an instrument between dates, optionally normalizing to a base currency "
            "using FX (in-memory conversion)."
    ),
)
def prices(body: PricesAnswer) -> AnalystAnswerModel:
    try:
        ans: AnalystAnswer = _agent.prices(
            instrument_code=body.instrument_code,
            from_date=body.from_date,
            to_date=body.to_date,
            source=body.source,
            base_currency=body.base_currency,
        )
        return AnalystAnswerModel(**_to_jsonable(ans))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"prices failed: {e}") from e

@router.post(
    "/pnl",
    response_model=AnalystAnswerModel,
    summary="PnL proxy via market value delta (v1)",
    description="Delta of market value between two dates for a portfolio (or instrument if provided). Numbers sourced strictly from the structured service."
)
def pnl(body: PnLAnswer) -> AnalystAnswerModel:
    try:
        ans = _agent.why_pnl_changed(
            portfolio_code=body.portfolio_code,
            as_of=body.as_of,
            prior=body.prior,
            instrument_code=body.instrument_code,
        )
        return AnalystAnswerModel(**_to_jsonable(ans))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"pnl failed: {e}") from e