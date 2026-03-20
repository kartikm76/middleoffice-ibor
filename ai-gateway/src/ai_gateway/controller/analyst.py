from __future__ import annotations
from fastapi import APIRouter, HTTPException
from ai_gateway.model.schemas import (
    ChatRequest, IborAnswer, PnLRequest, PositionsRequest, PricesRequest, TradesRequest,
)
from ai_gateway.service.ibor_service import IborService
from ai_gateway.service.llm_service import LlmService

def make_analyst_router(service: IborService, agent: LlmService) -> APIRouter:
    router = APIRouter(prefix="/analyst", tags=["Analyst"])

    @router.post("/positions", response_model=IborAnswer)
    async def positions(body: PositionsRequest) -> IborAnswer:
        try:
            return await service.positions(
                portfolio_code=body.portfolio_code,
                as_of=body.as_of,
                base_currency=body.base_currency,
                source=body.source,
                page=body.page,
                size=body.size,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.post("/trades", response_model=IborAnswer)
    async def trades(body: TradesRequest) -> IborAnswer:
        try:
            return await service.trades(
                portfolio_code=body.portfolio_code,
                instrument_code=body.instrument_code,
                as_of=body.as_of,
                page=body.page,
                size=body.size,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.post("/prices", response_model=IborAnswer)
    async def prices(body: PricesRequest) -> IborAnswer:
        try:
            return await service.prices(
                instrument_code=body.instrument_code,
                from_date=body.from_date,
                to_date=body.to_date,
                source=body.source,
                base_currency=body.base_currency,
                page=body.page,
                size=body.size,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.post("/pnl", response_model=IborAnswer)
    async def pnl(body: PnLRequest) -> IborAnswer:
        try:
            return await service.pnl(
                portfolio_code=body.portfolio_code,
                as_of=body.as_of,
                prior=body.prior,
                instrument_code=body.instrument_code,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.post("/chat", response_model=IborAnswer)
    async def chat(body: ChatRequest) -> IborAnswer:
        try:
            return await agent.chat(question=body.question)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    return router
