"""
Conversation Service Test Endpoints

Simple endpoints to test ConversationService methods directly.
Remove this file before production.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging

log = logging.getLogger(__name__)

router = APIRouter(prefix="/test/conversation", tags=["test"])

# Will be injected by main.py
conversation_service = None


class CreateConversationRequest(BaseModel):
    analyst_id: str
    session_id: str
    context_type: str = "portfolio"
    context_id: str = "P-ALPHA"


class SaveMessageRequest(BaseModel):
    conversation_id: str
    role: str  # "analyst" or "ai"
    content: str


class GetHistoryRequest(BaseModel):
    conversation_id: str


class SearchSimilarRequest(BaseModel):
    query: str
    analyst_id: str
    context_type: str = "portfolio"
    context_id: str = "P-ALPHA"
    top_k: int = 3


@router.post("/create-conversation")
async def create_conversation(request: CreateConversationRequest):
    """Create or get a conversation."""
    try:
        result = await conversation_service.get_or_create_conversation(
            analyst_id=request.analyst_id,
            session_id=request.session_id,
            context_type=request.context_type,
            context_id=request.context_id
        )
        return {"status": "success", "data": result}
    except Exception as e:
        log.error(f"Error creating conversation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/save-message")
async def save_message(request: SaveMessageRequest):
    """Save a message to a conversation."""
    try:
        await conversation_service.save_message(
            conversation_id=request.conversation_id,
            role=request.role,
            content=request.content
        )
        return {"status": "success", "message": "Message saved"}
    except Exception as e:
        log.error(f"Error saving message: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/get-history")
async def get_history(request: GetHistoryRequest):
    """Get conversation history."""
    try:
        history = await conversation_service.get_conversation_history(
            conversation_id=request.conversation_id
        )
        return {"status": "success", "data": history}
    except Exception as e:
        log.error(f"Error getting history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search-similar")
async def search_similar(request: SearchSimilarRequest):
    """Search for similar conversations."""
    try:
        results = await conversation_service.search_similar_conversations(
            query=request.query,
            context_type=request.context_type,
            context_id=request.context_id,
            analyst_id=request.analyst_id,
            top_k=request.top_k
        )
        return {"status": "success", "data": results}
    except Exception as e:
        log.error(f"Error searching similar: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def health():
    """Health check."""
    return {"status": "ok", "service": "conversation_test"}
