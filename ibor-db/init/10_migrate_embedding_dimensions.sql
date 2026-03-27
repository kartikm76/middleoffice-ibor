-- =====================================================================
-- MIGRATION: Update embedding vector dimensions from 1536 to 384
-- From: OpenAI text-embedding-3-small (1536 dims)
-- To: sentence-transformers all-MiniLM-L6-v2 (384 dims)
-- =====================================================================

-- Drop the ivfflat index (required before altering column)
DROP INDEX IF EXISTS idx_conv_emb_similarity;
DROP INDEX IF EXISTS idx_chunk_emb_similarity;

-- Alter conversation_embedding table
-- Drop the old column and recreate with correct dimension
ALTER TABLE conv.conversation_embedding
DROP COLUMN embedding;

ALTER TABLE conv.conversation_embedding
ADD COLUMN embedding VECTOR(384) NOT NULL;

-- Update the embedding_model field to reflect the new provider
UPDATE conv.conversation_embedding
SET embedding_model = 'all-MiniLM-L6-v2'
WHERE embedding_model = 'text-embedding-3-small';

-- Recreate the vector similarity index for conversations
CREATE INDEX idx_conv_emb_similarity ON conv.conversation_embedding USING ivfflat (embedding vector_cosine_ops);

-- Alter document_chunk_embedding table
ALTER TABLE conv.document_chunk_embedding
DROP COLUMN embedding;

ALTER TABLE conv.document_chunk_embedding
ADD COLUMN embedding VECTOR(384) NOT NULL;

-- Update the embedding_model field for document chunks
UPDATE conv.document_chunk_embedding
SET embedding_model = 'all-MiniLM-L6-v2'
WHERE embedding_model = 'text-embedding-3-small';

-- Recreate the vector similarity index for document chunks
CREATE INDEX idx_chunk_emb_similarity ON conv.document_chunk_embedding USING ivfflat (embedding vector_cosine_ops);

-- =====================================================================
-- Update main schema file comment (for documentation)
-- =====================================================================
-- NOTE: This migration changes the embedding dimension from 1536 (OpenAI)
-- to 384 (sentence-transformers all-MiniLM-L6-v2). This eliminates the
-- OpenAI API dependency while maintaining full RAG functionality.
-- Existing embeddings are cleared by the column drop (acceptable for Phase 1).
