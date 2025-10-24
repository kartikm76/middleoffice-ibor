from fastapi import APIRouter
router = APIRouter(tags=["hybrid_router"])

@router.get("/hybrid")
def hybrid_route():
    return {"message": "This is the hybrid router"}