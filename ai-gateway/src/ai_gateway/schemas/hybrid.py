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

class PositionsAnswer(BaseModel):
    """
    Request body for /agents/analyst/positions
    """
    portfolio_code: str = Field(..., description="The portfolio code for which positions are requested.")
    as_of: date = Field(..., description="The date as-of which positions are requested.")
    model_config = {
        "json_schema_extra": {
            "example": {
                "portfolio_code": "P-ALPHA",
                "as_of": "2023-09-28",
            }
        }
    }

class TradesAnswer(BaseModel):
    """
    Request body for /agents/analyst/trades
    """
    portfolio_code: str = Field(..., description="The portfolio code for which trades are requested.")
    instrument_code: str = Field(..., description="The instrument code for which trades are requested.")
    as_of: date = Field(..., description="The date as-of which trades are requested.")
    model_config = {
        "json_schema_extra": {
            "example": {
                "portfolio_code": "P-ALPHA",
                "instrument_code": "EQ-IBM",
                "as_of": "2023-09-28",
            }
        }
    }

class PricesAnswer(BaseModel):
    """Request body for /agents/analyst/prices"""
    instrument_code: str = Field(..., description="The instrument code for which prices are requested.")
    from_date: date = Field(..., description="The start date for the price range.")
    to_date: date = Field(..., description="The end date for the price range.")
    source: Optional[str] = Field(None, description="The source for the prices.")
    base_currency: Optional[str] = Field(None, description="The base currency for the prices.")
    model_config = {
        "json_schema_extra": {
            "example": {
                "instrument_code": "EQ-IBM",
                "from_date": "2023-09-28",
                "to_date": "2023-10-05",
                "source": "yahoo",
                "base_currency": "USD",
            }
        }
    }

class PnLAnswer(BaseModel):
    portfolio_code: str = Field(..., alias="portfolioCode", description="Portfolio code, e.g. P-ALPHA")
    as_of: date = Field(..., alias="asOf", description="Current as-of date YYYY-MM-DD")
    prior: date = Field(..., description="Prior as-of date YYYY-MM-DD")
    instrument_code: Optional[str] = Field(None, alias="instrumentCode",
        description="Optional instrument scope (e.g., EQ-IBM). If omitted, computes for whole portfolio."
    )
    model_config = {
        "validate_assignment": True,  # ensure aliases map correctly
        "populate_by_name": True,     # allow either camelCase or snake_case from UI
        "json_schema_extra": {
            "example": {
                "portfolioCode": "P-ALPHA",
                "asOf": "2025-01-03",
                "prior": "2025-01-01",
                "instrumentCode": "EQ-IBM"
            }
        }
    }