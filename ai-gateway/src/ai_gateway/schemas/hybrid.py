from pydantic import BaseModel, Field, HttpUrl, field_validator
from typing import Optional, List
from datetime import datetime, date

class ChatRequest(BaseModel):
    sessionId: str = Field(..., description="The unique identifier for the chat session.")
    message: str
    uiFilters: Optional[dict] = None

class Citation(BaseModel):
    chunkId: str = Field(..., description="The unique identifier for the chunk.")
    source: Optional[str] = None
    url: Optional[str] = None
    text: Optional[str] = None

class FactPosition(BaseModel):
    type: str = Field(default = "position")
    portfolio: str
    instrument: str
    netQuantity: float
    mktValue: float
    currency: str
    asOf: date

    model_config = {
        "validate_assignment": True
    }

    @field_validator('type')
    @classmethod
    def validate_type(cls, v):
        if v != "position":
            raise ValueError("type must be 'position'")
        return v

class FactsEnvelope(BaseModel):
    asOf: date
    portfolio: Optional[str] = None
    facts: List[FactPosition] = Field(default_factory=list)

class FinalAnswer(BaseModel):
    summary: str = Field(..., description="The final summary of the chat session.")
    narrative: List[str] = Field(default_factory=list, description="The narrative of the chat session.")
    facts: FactsEnvelope
    citations: List[Citation] = Field(default_factory=list, description="The citations used in the chat session.")
    assumptions: List[str] = Field(default_factory=list, description="The assumptions made in the chat session.")
