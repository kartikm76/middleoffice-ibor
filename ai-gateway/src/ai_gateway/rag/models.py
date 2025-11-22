from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, Optional

@dataclass
class RagDocument:
    """
    Represents a document in a RAG (Retrieval-Augmented Generation) system.
    """
    document_id: int
    source: str
    external_id: str
    title: Optional[str]
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime

@dataclass
class RagChunk:
    """
    Represents a chunk of text within a RAG (Retrieval-Augmented Generation) document.
    """
    chunk_id: int
    document_id: int
    chunk_index: int
    content: str
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime