from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, Optional


@dataclass
class RagDocument:
    """A document stored in the RAG vector store (ibor.rag_documents)."""
    document_id: int
    source: str
    external_id: str
    title: Optional[str]
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime


@dataclass
class RagChunk:
    """A text chunk belonging to a RagDocument (ibor.rag_chunks)."""
    chunk_id: int
    document_id: int
    chunk_index: int
    content: str
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime
