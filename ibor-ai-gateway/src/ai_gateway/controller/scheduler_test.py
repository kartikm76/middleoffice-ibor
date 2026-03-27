"""
Scheduler Test Endpoint (for debugging/testing only)
Remove before production.
"""

from fastapi import APIRouter, HTTPException
import logging

log = logging.getLogger(__name__)

router = APIRouter(prefix="/test/scheduler", tags=["test"])

# Will be injected by main.py
scheduler = None


@router.post("/trigger-embedding")
async def trigger_embedding():
    """Manually trigger embedding cycle (for testing only)."""
    if not scheduler:
        raise HTTPException(status_code=503, detail="Scheduler not initialized")

    try:
        await scheduler._embed_pending_conversations()
        return {"status": "success", "message": "Embedding cycle triggered"}
    except Exception as e:
        log.error(f"Failed to trigger embeddings: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status")
async def scheduler_status():
    """Check scheduler status."""
    if not scheduler:
        return {"status": "not initialized"}

    return {
        "status": "running" if scheduler._running else "stopped",
        "interval_seconds": scheduler._interval_seconds,
        "task_active": scheduler._task is not None and not scheduler._task.done(),
    }
