from __future__ import annotations
from typing import Any, Dict, List, Optional, Sequence
from psycopg.types.json import Json
from ai_gateway.infra.db import PgPool
from ai_gateway.rag.models import RagChunk, RagDocument
from ai_gateway.rag import sql as rag_sql

class LocalRagStore:
    """
    Local RAG repository backed by Postgres (rag_documents, rag_chunks).

    Responsibilities:
      - Upsert & fetch documents.
      - CRUD for chunks.
      - (Optionally) vector search inside a document.

    No embedding or text-splitting logic lives here – that comes in Step 3.
    """

    def __init__(self, pool: PgPool) -> None:
        self._pool = pool

    # ---------- document methods ----------
    def upsert_document(
        self,
        source: str,
        external_id: str,
        title: Optional[str],
        metadata: Optional[Dict[str, Any]] = None,
    ) -> RagDocument:
        params = {
            "source": source,
            "external_id": external_id,
            "title": title,
            "metadata": Json(metadata or {}),
        }
        rows = self._pool.fetch_all(rag_sql.UPSERT_DOCUMENT_SQL, params)
        if not rows:
            raise RuntimeError("UPSERT_DOCUMENT_SQL returned no rows")
        return self._map_document(rows[0])

    def get_document_by_id(self, document_id: int) -> Optional[RagDocument]:
        params = {"document_id": document_id}
        row = self._pool.fetch_one(rag_sql.GET_DOCUMENT_BY_ID_SQL, params)
        return self._map_document(row) if row else None

    def get_document_by_external_id(self, external_id: str) -> Optional[RagDocument]:
        params = {"external_id": external_id}
        row = self._pool.fetch_one(rag_sql.GET_DOCUMENT_BY_EXTERNAL_ID_SQL, params)
        return self._map_document(row) if row else None

    def list_documents(self, limit: int = 50) -> List[RagDocument]:
        params = {"limit": limit}
        rows = self._pool.fetch_all(rag_sql.LIST_DOCUMENTS_SQL, params)
        return [self._map_document(row) for row in rows]

    def delete_document(self, document_id: int) -> None:
        params = {"document_id": document_id}
        self._pool.execute(rag_sql.DELETE_DOCUMENT_SQL, params)

    # ---------- chunk methods ----------
    def insert_chunk(
        self,
        document_id: int,
        chunk_index: int,
        content: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> RagChunk:
        params = {
            "document_id": document_id,
            "chunk_index": chunk_index,
            "content": content,
            "metadata": Json(metadata or {}),
        }
        rows = self._pool.fetch_all(rag_sql.INSERT_CHUNK_SQL, params)
        if not rows:
            raise RuntimeError("INSERT_CHUNK_SQL returned no rows")
        return self._map_chunk(rows[0])

    def insert_chunks(
        self,
        document_id: int,
        chunks: Sequence[Dict[str, Any]],
    ) -> List[RagChunk]:
        inserted: List[RagChunk] = []
        with self._pool.connection() as conn:
            with conn.cursor() as cur:
                for chunk in chunks:
                    params = {
                        "document_id": document_id,
                        "chunk_index": chunk["chunk_index"],
                        "content": chunk["content"],
                        "metadata": Json(chunk.get("metadata") or {}),
                    }
                    cur.execute(rag_sql.INSERT_CHUNK_SQL, params)
                    row = cur.fetchone()
                    if row is None:
                        raise RuntimeError("INSERT_CHUNK_SQL returned no rows")
                    inserted.append(self._map_chunk(row))
            conn.commit()
        return inserted

    def get_chunks_for_document(self, document_id: int) -> List[RagChunk]:
        params = {"document_id": document_id}
        rows = self._pool.fetch_all(rag_sql.GET_CHUNKS_FOR_DOCUMENT_SQL, params)
        return [self._map_chunk(row) for row in rows]

    def delete_chunks_for_document(self, document_id: int) -> None:
        params = {"document_id": document_id}
        self._pool.execute(rag_sql.DELETE_CHUNKS_FOR_DOCUMENT_SQL, params)

    # ---------- optional vector search ----------

    def search_chunks(
        self,
        document_id: int,
        query_embedding: Any,
        limit: int = 5,
    ) -> List[RagChunk]:
        params = {
            "document_id": document_id,
            "query_embedding": query_embedding,
            "limit": limit,
        }
        rows = self._pool.fetch_all(rag_sql.SEARCH_CHUNKS_SQL, params)
        return [self._map_chunk(row) for row in rows]

    # ---------- mappers ----------

    @staticmethod
    def _map_document(row: Dict[str, Any]) -> RagDocument:
        return RagDocument(
            document_id=row["document_id"],
            source=row["source"],
            external_id=row["external_id"],
            title=row["title"],
            metadata=row["metadata"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

    @staticmethod
    def _map_chunk(row: Dict[str, Any]) -> RagChunk:
        return RagChunk(
            chunk_id=row["chunk_id"],
            document_id=row["document_id"],
            chunk_index=row["chunk_index"],
            content=row["content"],
            metadata=row["metadata"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )
