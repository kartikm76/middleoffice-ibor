-- =====================================================================
-- CONVERSATION & DOCUMENT RAG SCHEMA
-- AI analyst conversation memory + multi-turn support
-- Phase 1: Conversation RAG
-- Phase 2: Document RAG (chunking, embedding, source attribution)
-- =====================================================================

-- Create conv schema for all conversation/document-related tables
DROP SCHEMA IF EXISTS conv CASCADE;
CREATE SCHEMA conv;

-- =====================================================================
-- PHASE 1: CONVERSATION STORAGE & RAG
-- =====================================================================

-- ---------------------------
-- Conversation table (memory for multi-turn resumption)
-- ---------------------------
CREATE TABLE conv.conversation (
  conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  analyst_id VARCHAR NOT NULL,
  portfolio_id VARCHAR,                    -- optional: what portfolio is this about?
  title TEXT,                              -- auto-generated or analyst-provided
  messages JSONB NOT NULL,                 -- full chat history in order
                                           -- format: [{"role": "user|assistant", "content": "..."}]
  message_count INT DEFAULT 0,             -- count of messages for quick checks
  last_embedding_checkpoint TIMESTAMP,     -- when we last embedded (for delta tracking)
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_conv_analyst ON conv.conversation(analyst_id);
CREATE INDEX idx_conv_portfolio ON conv.conversation(portfolio_id);
CREATE INDEX idx_conv_created ON conv.conversation(created_at DESC);

-- ---------------------------
-- Conversation embeddings (pgvector for semantic search)
-- ---------------------------
CREATE TABLE conv.conversation_embedding (
  conversation_id UUID PRIMARY KEY REFERENCES conv.conversation(conversation_id) ON DELETE CASCADE,
  embedding VECTOR(1536) NOT NULL,        -- OpenAI text-embedding-3-small or sentence-transformers
  embedding_model VARCHAR DEFAULT 'text-embedding-3-small',
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_conv_emb_similarity ON conv.conversation_embedding USING ivfflat (embedding vector_cosine_ops);

-- =====================================================================
-- PHASE 2: DOCUMENT STORAGE & CHUNKED RAG
-- =====================================================================

-- ---------------------------
-- Document metadata
-- ---------------------------
CREATE TABLE conv.document (
  document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  analyst_id VARCHAR NOT NULL,
  portfolio_id VARCHAR,
  document_type VARCHAR NOT NULL,         -- earnings_pdf, regulatory, internal_memo, market_research
  title TEXT NOT NULL,                    -- "AAPL Q4 2025 Earnings"
  description TEXT,
  file_path TEXT,                         -- where file is stored (S3 path or local)
  file_size_bytes INT,
  file_hash VARCHAR(64),                  -- SHA256 hash for deduplication
  page_count INT,                         -- for PDFs
  upload_by VARCHAR,                      -- analyst_id of uploader
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_doc_analyst ON conv.document(analyst_id);
CREATE INDEX idx_doc_portfolio ON conv.document(portfolio_id);
CREATE INDEX idx_doc_type ON conv.document(document_type);
CREATE INDEX idx_doc_created ON conv.document(created_at DESC);

-- ---------------------------
-- Document chunks (after PDF splitting)
-- ---------------------------
CREATE TABLE conv.document_chunk (
  chunk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES conv.document(document_id) ON DELETE CASCADE,
  chunk_index INT NOT NULL,               -- order in document (0-based)
  page_number INT,                        -- which page (for PDFs)
  section_title TEXT,                     -- extracted heading or auto-generated
  content TEXT NOT NULL,                  -- actual text content (~500 tokens per chunk)
  token_count INT,                        -- approximate token count
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (document_id, chunk_index)
);

CREATE INDEX idx_chunk_document ON conv.document_chunk(document_id);
CREATE INDEX idx_chunk_page ON conv.document_chunk(document_id, page_number);

-- ---------------------------
-- Document chunk embeddings (one per chunk)
-- ---------------------------
CREATE TABLE conv.document_chunk_embedding (
  chunk_id UUID PRIMARY KEY REFERENCES conv.document_chunk(chunk_id) ON DELETE CASCADE,
  embedding VECTOR(1536) NOT NULL,        -- pgvector embedding of chunk content
  embedding_model VARCHAR DEFAULT 'text-embedding-3-small',
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_chunk_emb_similarity ON conv.document_chunk_embedding USING ivfflat (embedding vector_cosine_ops);

-- ---------------------------
-- Linking table: conversations to documents they reference
-- ---------------------------
CREATE TABLE conv.conversation_document (
  conversation_id UUID NOT NULL REFERENCES conv.conversation(conversation_id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES conv.document(document_id) ON DELETE CASCADE,
  mentioned_at_message_idx INT,           -- which message in conversation mentioned the doc
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, document_id)
);

CREATE INDEX idx_conv_doc_lookup ON conv.conversation_document(document_id);

-- =====================================================================
-- AUDIT TRIGGERS
-- =====================================================================

-- Audit table for conversations
CREATE TABLE conv.conversation_audit (
  audit_id BIGSERIAL PRIMARY KEY,
  conversation_id UUID NOT NULL,
  operation VARCHAR NOT NULL,             -- INSERT, UPDATE, DELETE
  old_data JSONB,
  new_data JSONB,
  changed_by VARCHAR DEFAULT 'SYSTEM',
  changed_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Trigger: conversation changes
CREATE OR REPLACE FUNCTION conv.audit_conversation()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO conv.conversation_audit (conversation_id, operation, new_data, changed_by, changed_at)
    VALUES (NEW.conversation_id, 'INSERT', to_jsonb(NEW), COALESCE(current_setting('app.user_id', true), 'SYSTEM'), now());
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO conv.conversation_audit (conversation_id, operation, old_data, new_data, changed_by, changed_at)
    VALUES (NEW.conversation_id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), COALESCE(current_setting('app.user_id', true), 'SYSTEM'), now());
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO conv.conversation_audit (conversation_id, operation, old_data, changed_by, changed_at)
    VALUES (OLD.conversation_id, 'DELETE', to_jsonb(OLD), COALESCE(current_setting('app.user_id', true), 'SYSTEM'), now());
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversation_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON conv.conversation
FOR EACH ROW EXECUTE FUNCTION conv.audit_conversation();

-- Audit table for documents
CREATE TABLE conv.document_audit (
  audit_id BIGSERIAL PRIMARY KEY,
  document_id UUID NOT NULL,
  operation VARCHAR NOT NULL,
  old_data JSONB,
  new_data JSONB,
  changed_by VARCHAR DEFAULT 'SYSTEM',
  changed_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Trigger: document changes
CREATE OR REPLACE FUNCTION conv.audit_document()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO conv.document_audit (document_id, operation, new_data, changed_by, changed_at)
    VALUES (NEW.document_id, 'INSERT', to_jsonb(NEW), COALESCE(current_setting('app.user_id', true), 'SYSTEM'), now());
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO conv.document_audit (document_id, operation, old_data, new_data, changed_by, changed_at)
    VALUES (NEW.document_id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), COALESCE(current_setting('app.user_id', true), 'SYSTEM'), now());
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO conv.document_audit (document_id, operation, old_data, changed_by, changed_at)
    VALUES (OLD.document_id, 'DELETE', to_jsonb(OLD), COALESCE(current_setting('app.user_id', true), 'SYSTEM'), now());
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER document_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON conv.document
FOR EACH ROW EXECUTE FUNCTION conv.audit_document();

-- =====================================================================
-- HELPER VIEWS
-- =====================================================================

-- View: conversations with embedding freshness info
CREATE OR REPLACE VIEW conv.vw_conversation_status AS
SELECT
  c.conversation_id,
  c.analyst_id,
  c.portfolio_id,
  c.title,
  c.message_count,
  c.created_at,
  c.updated_at,
  c.last_embedding_checkpoint,
  COALESCE(ce.embedding IS NOT NULL, false) AS has_embedding,
  EXTRACT(EPOCH FROM (now() - c.last_embedding_checkpoint)) / 60 AS minutes_since_embedding,
  CASE
    WHEN c.last_embedding_checkpoint IS NULL THEN 'NEEDS_INITIAL_EMBEDDING'
    WHEN EXTRACT(EPOCH FROM (now() - c.last_embedding_checkpoint)) / 60 > 5 THEN 'NEEDS_DELTA_EMBEDDING'
    ELSE 'CURRENT'
  END AS embedding_status
FROM conv.conversation c
LEFT JOIN conv.conversation_embedding ce ON ce.conversation_id = c.conversation_id;

-- View: documents with chunk counts and embedding status
CREATE OR REPLACE VIEW conv.vw_document_status AS
SELECT
  d.document_id,
  d.analyst_id,
  d.portfolio_id,
  d.title,
  d.document_type,
  COUNT(dc.chunk_id) AS chunk_count,
  COUNT(dce.chunk_id) AS embedded_chunk_count,
  d.created_at,
  d.updated_at
FROM conv.document d
LEFT JOIN conv.document_chunk dc ON dc.document_id = d.document_id
LEFT JOIN conv.document_chunk_embedding dce ON dce.chunk_id = dc.chunk_id
GROUP BY d.document_id, d.analyst_id, d.portfolio_id, d.title, d.document_type, d.created_at, d.updated_at;

-- =====================================================================
-- PERMISSIONS & GRANTS (if using role-based access)
-- =====================================================================
-- GRANT SELECT, INSERT, UPDATE ON conv.conversation TO ibor_app;
-- GRANT SELECT, INSERT ON conv.conversation_embedding TO ibor_app;
-- GRANT SELECT, INSERT, UPDATE ON conv.document TO ibor_app;
-- GRANT SELECT, INSERT ON conv.document_chunk TO ibor_app;
-- GRANT SELECT, INSERT ON conv.document_chunk_embedding TO ibor_app;
-- GRANT SELECT ON conv.vw_conversation_status TO ibor_app;
-- GRANT SELECT ON conv.vw_document_status TO ibor_app;
