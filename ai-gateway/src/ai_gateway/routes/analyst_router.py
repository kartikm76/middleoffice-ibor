from __future__ import annotations

from typing import Any
from fastapi import APIRouter, HTTPException
from ai_gateway.agents.i_orchestrator import AnalystService
from ai_gateway.schemas.common import AnalystAnswerModel
from ai_gateway.schemas.hybrid import (
    PositionsAnswer,
    TradesAnswer,
    PricesAnswer,
    PnLAnswer,
)
from ai_gateway.utils.jsonable import to_jsonable

router = APIRouter(
    prefix="/agents/analyst",
    tags=["Analyst"],
    responses={
        400: {"description": "Bad request"},
        404: {"description": "Not found"},
        500: {"description": "Internal error"},
    },
)

def make_analyst_router(service: AnalystService) -> APIRouter:
    router = APIRouter(
        prefix = "/agents/analyst",
        tags = ["Analyst"],
        responses = {
            400: {"description": "Bad Request"},
            404: {"description": "Not Found"},
            500: {"description": "Internal Error"},
        },
    )

    @router.post("/positions", response_model = AnalystAnswerModel, summary = "Positions (Analyst view)",
                description=("Returns a grounded positions summary for a portfolio as of the given date. "
                            "Numbers are pulled strictly from the structured service. "
                            "Response includes short narrative (`summary`), raw `data`, and `citations`."
                ),
    )
    def positions (body: PositionsAnswer) -> AnalystAnswerModel:
        try:
            ans = service.positions(portfolio_code = body.portfolio_code,
                as_of = body.as_of,
            )
            return AnalystAnswerModel(**to_jsonable(ans))
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
    def trades (body: TradesAnswer) -> AnalystAnswerModel:
        try:
            ans = service.trades(
                    portfolio_code = body.portfolio_code,
                    instrument_code = body.instrument_code,
                    as_of = body.as_of,
            )
            return AnalystAnswerModel(**to_jsonable(ans))
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"trades failed: {e}") from e


    @router.post(
        "/prices",
        response_model=AnalystAnswerModel,
        summary="Prices (Analyst view, optional FX normalization)",
        description=(
                "Fetches raw prices for an instrument between dates, optionally normalizing to a base currency "
                "using FX (in-memory conversion)."
        ),
    )
    def prices (body: PricesAnswer) -> AnalystAnswerModel:
        try:
            ans = service.prices(
                    instrument_code = body.instrument_code,
                    from_date = body.from_date,
                    to_date = body.to_date,
                    source=body.source,
                    base_currency=body.base_currency,
            )
            return AnalystAnswerModel(**to_jsonable(ans))
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
            ans = service.pnl(
                    portfolio_code = body.portfolio_code,
                    as_of = body.as_of,
                    prior = body.prior,
                    instrument_code = body.instrument_code,
            )
            return AnalystAnswerModel(**to_jsonable(ans))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"pnl failed: {e}") from e

    return router