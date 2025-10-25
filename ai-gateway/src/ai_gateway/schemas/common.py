# --- in src/ai_gateway/schemas/common.py ---

from pydantic import BaseModel, Field
from typing import Optional, Any, List
from datetime import datetime, date
from typing import Literal

class CitationModel(BaseModel):
    kind: Literal["structured", "rag"] = Field(...)
    source: str = Field(...)
    url: Optional[str] = None
    title: Optional[str] = None
    score: Optional[float] = None
    chunk_id: Optional[str] = None
    meta: Optional[dict[str, Any]] = None

class AnalystAnswerModel(BaseModel):
    contract_version: int = Field(
        1, description="Version of the response contract for deterministic clients."
    )
    question: str = Field(...)
    as_of: date = Field(...)
    portfolio_code: Optional[str] = None
    instrument_code: Optional[str] = None

    data: dict[str, Any] = Field(default_factory=dict)
    summary: Optional[str] = None
    citations: List[CitationModel] = Field(default_factory=list)
    gaps: List[str] = Field(default_factory=list)

    created_at: datetime = Field(default_factory=datetime.now)
    diagnostics: Optional[dict[str, Any]] = None

    model_config = {
        # If later you add camelCase aliases, you can enable by_alias here.
        # "populate_by_name": True,
        # "ser_json_timedelta": "float",
    }

    # Example
    @staticmethod
    def example() -> dict[str, Any]:
        return {
            "contract_version": 1,
            "question": "Show positions today for P-ALPHA",
            "as_of": "2025-01-03",
            "portfolio_code": "P-ALPHA",
            "instrument_code": None,
            "summary": "P-ALPHA holds 2 instruments; total market value is 27,431.00 USD.",
            "data": {
                "positions": [
                    {
                        "instrumentId": "EQ-IBM",
                        "instrumentType": "EQUITY",
                        "netQty": 100,
                        "price": 175.25,
                        "priceSource": "BBG",
                        "mktValue": 17525.00,
                        "currency": "USD",
                        "contractMultiplier": 1
                    }
                ]
            },
            "citations": [
                {
                    "kind": "structured",
                    "source": "/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03",
                    "meta": {"portfolioCode": "P-ALPHA", "asOf": "2025-01-03"}
                }
            ],
            "gaps": [],
            "created_at": "2025-01-03T14:22:11Z",
            "diagnostics": {"traceId": "abc123", "tools": ["positions"]}
        }