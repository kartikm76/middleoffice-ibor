from __future__ import annotations

# ---------- documents ----------

UPSERT_DOCUMENT_SQL = """
INSERT INTO ibor.rag_documents (source, external_id, title, metadata)
VALUES (%(source)s, %(external_id)s, %(title)s, %(metadata)s::jsonb)
ON CONFLICT (source, external_id)
DO UPDATE SET 
    title = EXCLUDED.title,
    metadata = EXCLUDED.metadata,
    updated_at = now()
RETURNING
    document_id,
    source,
    external_id,
    title,
    metadata,
    created_at,
    updated_at;
"""

GET_DOCUMENT_BY_ID_SQL = """
SELECT
    document_id,
    source,
    external_id,
    title,
    metadata,
    created_at,
    updated_at
FROM ibor,rag_documents
WHERE document_id = %(document_id)s;
"""

GET_DOCUMENT_BY_EXTERNAL_ID_SQL = """
SELECT
    document_id,
    source,
    external_id,
    title,
    metadata,
    created_at,
    updated_at
FROM ibor.rag_documents
WHERE external_id = %(external_id)s;
"""

LIST_DOCUMENTS_SQL = """
SELECT
    document_id,
    source,
    external_id,
    title,
    metadata,
    created_at,
    updated_at
FROM ibor.rag_documents
ORDER BY created_at DESC
LIMIT %(limit)s;
"""

DELETE_DOCUMENT_SQL = """
DELETE FROM ibor.rag_documents
WHERE document_id = %(document_id)s;
"""

# ---------- chunks ----------
INSERT_CHUNK_SQL = """
INSERT INTO ibor.rag_chunks (document_id, chunk_index, content, metadata)
VALUES (%(document_id)s, %(chunk_index)s, %(content)s, %(metadata)s::jsonb)
RETURNING
    chunk_id,
    document_id,
    chunk_index,
    content,
    metadata,
    created_at,
    updated_at;
"""

GET_CHUNKS_FOR_DOCUMENT_SQL = """
SELECT
    chunk_id,
    document_id,
    chunk_index,
    content,
    metadata,
    created_at,
    updated_at
FROM ibor.rag_chunks
WHERE document_id = %(document_id)s
ORDER BY chunk_index ASC;
"""

DELETE_CHUNKS_FOR_DOCUMENT_SQL = """
DELETE FROM ibor.rag_chunks
WHERE document_id = %(document_id)s;
"""

# (Optional) simple vector search – we keep it here, still pure SQL
SEARCH_CHUNKS_SQL = """
SELECT
    chunk_id,
    document_id,
    chunk_index,
    content,
    metadata,
    created_at,
    updated_at,
    (embedding <=> %(query_embedding)s)AS distance
FROM ibor.rag_chunks
WHERE document_id = %(document_id)s
ORDER BY encoding <=> %(query_embedding)s
LIMIT %(limit)s;
"""
