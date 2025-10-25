from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


class CitationModel(BaseModel):
    """
    A single source used to justify part of the answer.
    kind='structured' means the number came from your Spring service.
    kind='rag' means narrative/supporting context from your RAG store.
    """
    kind: Literal["structured", "rag"] = Field(
        ...,
        description="Type of citation: 'structured' (Spring/SQL numbers) or 'rag' (vector/narrative)."
    )
    source: str = Field(
        ...,
        description="Identifier of the source (e.g., endpoint path for structured, or document title/id for RAG)."
    )
    url: Optional[str] = Field(
        None,
        description="Link for the source (e.g., doc page, internal link, or API call)."
    )
    title: Optional[str] = Field(
        None,
        description="Title of the source (e.g., document title, endpoint name)."
    )
    score: Optional[float] = Field(
        None,
        description="Score of the source (e.g., relevance, confidence)."
    )
    chunk_id: Optional[str] = Field(
        None,
        description="Chunk identifier for RAG (if applicable)."
    )
    meta: Optional[Dict[str, Any]] = Field(
        default=None,
        description="Optional metadata (e.g., instrumentId, asOf, etc.)."
    )


class AnalystAnswerModel(BaseModel):
    """
    Contract returned by Analyst routes.
    Rules:
    - All numbers must come from structured tools (citations.kind == 'structured').
    - Narrative/context may be backed by RAG (citations.kind == 'rag').
    - Always include as_of; include portfolio_code/instrument_code if relevant.
    """
    contract_version: int = Field(
        1,
        description="Version of the response contract for deterministic clients.",
    )
    question: str = Field(
        ...,
        description="The original question or prompt that generated this answer.",
    )
    as_of: date = Field(
        ...,
        description="The date as-of which the answer was generated.",
    )
    portfolio_code: Optional[str] = Field(
        None,
        description="The portfolio code for which the answer was generated.",
    )
    instrument_code: Optional[str] = Field(
        None,
        description="The instrument code for which the answer was generated.",
    )

    # Structured data payload (numbers/tables/series, already computed upstream)
    data: Dict[str, Any] = Field(
        default_factory=dict,
        description="Structured payload (e.g., positions[], trades[], pnl[]). No freeform text here.",
    )
    # Optional short narrative (safe; must not introduce new numbers)
    summary: Optional[str] = Field(
        None,
        description="Optional short narrative (safe; must not introduce new numbers).",
    )
    # Citations (structured or RAG)
    citations: List[CitationModel] = Field(
        default_factory=list,
        description="Sources used for numbers (structured) and any narrative (rag).",
    )
    # If anything was missing to answer fully
    gaps: List[str] = Field(
        default_factory=list,
        description="Missing inputs or data gaps that prevented a complete answer.",
    )

    # Timestamps & diagnostics
    created_at: datetime = Field(
        default_factory=datetime.now,
        description="Timestamp when the answer was created.",
    )
    diagnostics: Optional[Dict[str, Any]] = Field(
        default=None,
        description="Optional debug info (e.g., which tools ran, timings). Not for end users."
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "contract_version": 1,
                "question": "Show positions today for P-ALPHA",
                "as_of": "2025-01-03",
                "portfolio_code": "P-ALPHA",
                "instrument_code": "EQ-IBM",
                "summary": "P-ALPHA holds 3 instruments; total market value is 12.34M USD.",
                "data": {
                    "positions": [
                        {
                            "instrumentCode": "EQ-IBM",
                            "instrumentType": "EQUITY",
                            "netQty": 1500,
                            "price": 182.15,
                            "marketValue": 273225.00,
                            "currency": "USD",
                            "asOf": "2025-01-03"
                        }
                    ]
                },
                "citations": [
                    {
                        "kind": "structured",
                        "source": "/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03",
                        "url": "http://structured/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03",
                        "title": "Positions API",
                        "score": 1.0,
                        "meta": {"portfolioCode": "P-ALPHA", "asOf": "2025-01-03"}
                    }
                ],
                "gaps": [],
                "created_at": "2025-01-03T14:22:11",
                "diagnostics": {"latencyMs": 128}
            }
        }
    }