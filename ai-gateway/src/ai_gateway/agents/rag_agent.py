"""
RAG Agent
=========

This module implements a minimal Retrieval-Augmented Generation (RAG) helper
for the AI Gateway. It provides:

- Document ingestion: split -> embed -> upsert doc -> insert chunks
- Semantic search: embed query -> ANN search (pgvector) -> return ranked hits

Assumptions and requirements:
- PostgreSQL with the pgvector extension installed
- Two tables are present: ibor.rag_documents and ibor.rag_chunks
- OpenAI API is available for text embeddings

Configuration (read from ai_gateway.config.settings and environment):
- settings.pg_dsn: PostgreSQL connection string
- settings.openai_embed_model: Embedding model name (e.g., text-embedding-3-small)
- OPENAI_API_KEY (env): API key for OpenAI

Notes:
- All heavy operations are wrapped with tracing via the @traced decorator
- Chunking uses a sliding window with configurable overlap to preserve context
"""

from __future__ import annotations

import os
import psycopg
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Iterable, Tuple
from datetime import datetime
from openai import OpenAI  # pip install openai>=1.51
from ai_gateway.infra.tracing import traced
from ai_gateway.config import settings

@dataclass
class RagHit:
    """Single search result returned by the RAG search pipeline.

    Attributes:
        chunk_id: Unique identifier for the stored chunk.
        document_id: Foreign key of the parent document in rag_documents.
        content: The actual text content of the chunk.
        distance: Cosine distance between query embedding and chunk embedding
                  in [0, 2], where lower is more similar (similarity = 1 - distance).
        metadata: Arbitrary JSON metadata attached to the chunk (e.g., titles, tags).
    """
    chunk_id: int
    document_id: int
    content: str
    distance: float
    metadata: Dict[str, Any]


class RagAgent:
    """RAG helper for ingesting documents and performing semantic search.

    Responsibilities:
    - Ingest documents: split text into chunks, embed via OpenAI, and persist into PG
    - Search: embed query, run ANN search via pgvector, return ranked hits

    Database contract:
    - ibor.rag_documents(document_id, source, external_id, title, metadata, ...)
    - ibor.rag_chunks(chunk_id, document_id, chunk_index, content, embedding, metadata, ...)

    Performance considerations:
    - Batch embedding via _embed_many for ingestion throughput
    - Use ivfflat index over vector_cosine_ops for fast similarity search
    """

    def __init__(
            self,
            dsn: str | None = None,
            embed_model: str | None = None,
            embed_dim: int = 1536,
    ):
        """Construct a RagAgent.

        Args:
            dsn: PostgreSQL DSN; defaults to settings.pg_dsn if omitted.
            embed_model: Embedding model name; defaults to settings.openai_embed_model.
            embed_dim: Expected embedding dimensionality; used for validation.
        """
        self.dsn = dsn or settings.pg_dsn
        self.embed_model = embed_model or settings.openai_embed_model  # e.g., "text-embedding-3-small"
        self.embed_dim = embed_dim
        self._client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

    # ---------------- Ingest ----------------

    @traced("rag.ingest_text")
    def ingest_text(
            self,
            *,
            source: str,
            external_id: str,
            title: str,
            text: str,
            metadata: Optional[Dict[str, Any]] = None,
            chunk_chars: int = 1200,
            overlap: int = 150,
    ) -> int:
        """Ingest a document into the RAG store.

        The text is split into overlapping chunks, embedded via OpenAI, then
        upserted into ibor.rag_documents with corresponding chunk rows in
        ibor.rag_chunks. If a document with the same (source, external_id)
        exists, it is updated (idempotent operation).

        Args:
            source: Source system identifier (e.g., "confluence").
            external_id: External document identifier unique within the source.
            title: Human-readable document title.
            text: Full document text to ingest.
            metadata: Optional document-level metadata (author, tags, etc.).
            chunk_chars: Target chunk size in characters.
            overlap: Overlap in characters between consecutive chunks.

        Returns:
            The integer document_id for the upserted/created document.
        """
        chunks = list(self._split(text, chunk_chars, overlap))
        vectors = self._embed_many(chunks)

        with psycopg.connect(self.dsn, autocommit=True) as conn:
            did = self._upsert_document(conn, source, external_id, title, metadata or {})
            for i, (content, vec) in enumerate(zip(chunks, vectors)):
                self._insert_chunk(conn, did, i, content, vec, {"ingestedAt": datetime.utcnow().isoformat()})
            return did

    # ---------------- Search ----------------

    @traced("rag.search")
    def search(
            self,
            query: str,
            top_k: int = 6,
            min_similarity: Optional[float] = None,  # if you want to filter
    ) -> List[RagHit]:
        """Perform semantic search against stored chunks.

        Embeds the query using the configured model, then finds the nearest
        chunks using cosine distance from the pgvector index. Optionally filters
        results by a similarity threshold.

        Args:
            query: Natural language search query.
            top_k: Maximum number of hits to return.
            min_similarity: If provided, only return hits with (1 - distance)
                greater than or equal to this threshold in [0, 1].

        Returns:
            A list of RagHit instances ordered by ascending distance (most similar first).
        """
        vec = self._embed_one(query)

        sql = """
        SELECT chunk_id, document_id,
               (embedding <=> %s)::float4 AS distance,
               content, metadata
        FROM ibor.rag_chunks
        ORDER BY embedding <=> %s
        LIMIT %s
        """
        with psycopg.connect(self.dsn) as conn:
            with conn.cursor() as cur:
                cur.execute(sql, (vec, vec, top_k))
                rows = cur.fetchall()

        # Convert cosine *distance* (lower=better) to similarity if requested
        hits: List[RagHit] = []
        for chunk_id, document_id, distance, content, md in rows:
            hit = RagHit(
                chunk_id=chunk_id,
                document_id=document_id,
                content=content,
                distance=float(distance),
                metadata=md or {},
            )
            hits.append(hit)

        if min_similarity is not None:
            # cosine similarity = 1 - distance
            hits = [h for h in hits if (1.0 - h.distance) >= min_similarity]

        return hits

    # ---------------- Internals ----------------
    def _split(self, text: str, size: int, overlap: int) -> Iterable[str]:
        """Split text into overlapping chunks using a sliding window.

        Args:
            text: The source text to split.
            size: Target chunk size in characters.
            overlap: Number of characters to overlap between chunks.

        Returns:
            An iterator over text chunks.
        """
        text = text.strip()
        if not text:
            return []
        start = 0
        n = len(text)
        while start < n:
            end = min(n, start + size)
            chunk = text[start:end]
            yield chunk
            if end == n:
                break
            start = end - overlap

    def _embed_one(self, text: str) -> List[float]:
        """Create a single embedding vector for the given text.

        Validates the resulting vector dimensionality against self.embed_dim.

        Args:
            text: The text to embed.

        Returns:
            The embedding vector as a list of floats.

        Raises:
            ValueError: If the returned vector has an unexpected dimension.
        """
        em = self._client.embeddings.create(model=self.embed_model, input=text)
        vec = em.data[0].embedding
        if len(vec) != self.embed_dim:
            raise ValueError(f"Embedding dim mismatch: expected {self.embed_dim}, got {len(vec)}")
        return vec

    def _embed_many(self, chunks: List[str]) -> List[List[float]]:
        """Create embeddings for many chunks in a single API call.

        Args:
            chunks: List of text chunks to embed, in order.

        Returns:
            List of embedding vectors in the same order as input.

        Raises:
            ValueError: If any returned vector has an unexpected dimension.
        """
        em = self._client.embeddings.create(model=self.embed_model, input=chunks)
        out = [d.embedding for d in em.data]
        for v in out:
            if len(v) != self.embed_dim:
                raise ValueError(f"Embedding dim mismatch: expected {self.embed_dim}, got {len(v)}")
        return out

    def _upsert_document(
            self, conn: psycopg.Connection, source: str, external_id: str, title: str, metadata: Dict[str, Any]
    ) -> int:
        """Insert or update a document row and return its document_id.

        On conflict by (source, external_id), updates title/metadata, preserving
        existing metadata keys while merging new values. Returns the stable id.

        Args:
            conn: Active psycopg connection (autocommit recommended by caller).
            source: Source system identifier.
            external_id: External document identifier.
            title: Document title.
            metadata: Document-level metadata as JSON-serializable dict.

        Returns:
            The integer document_id.
        """
        sql = """
        INSERT INTO ibor.rag_documents (source, external_id, title, metadata)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (source, external_id)
        DO UPDATE SET title = EXCLUDED.title,
                      metadata = COALESCE(ibor.rag_documents.metadata, '{}'::jsonb) || EXCLUDED.metadata,
                      updated_at = now()
        RETURNING document_id
        """
        with conn.cursor() as cur:
            cur.execute(sql, (source, external_id, title, metadata))
            (did,) = cur.fetchone()
            return int(did)

    def _insert_chunk(
            self, conn: psycopg.Connection, document_id: int, chunk_index: int, content: str, vector: List[float], metadata: Dict[str, Any]
    ) -> int:
        """Insert or update a chunk row and return its chunk_id.

        Chunks are deduplicated by (document_id, chunk_index) to allow idempotent
        re-ingestion of the same document content.

        Args:
            conn: Active psycopg connection.
            document_id: Parent document id.
            chunk_index: Zero-based index of the chunk within the document.
            content: Chunk text.
            vector: Embedding vector for the chunk.
            metadata: Optional chunk-level metadata.

        Returns:
            The integer chunk_id.
        """
        sql = """
        INSERT INTO ibor.rag_chunks (document_id, chunk_index, content, embedding, metadata)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (document_id, chunk_index)
        DO UPDATE SET content = EXCLUDED.content,
                      embedding = EXCLUDED.embedding,
                      metadata = EXCLUDED.metadata,
                      updated_at = now()
        RETURNING chunk_id
        """
        with conn.cursor() as cur:
            cur.execute(sql, (document_id, chunk_index, content, vector, metadata))
            (cid,) = cur.fetchone()
            return int(cid)