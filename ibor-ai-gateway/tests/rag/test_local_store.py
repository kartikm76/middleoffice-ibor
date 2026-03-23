import pytest
from datetime import datetime

from ai_gateway.infra.db import PgPool, PgPoolConfig
from ai_gateway.rag.local_store import LocalRagStore
from ai_gateway.rag.models import RagDocument, RagChunk

@pytest.fixture(scope="module")
def pg_pool() -> PgPool:
    config = PgPoolConfig(
        dsn = "postgresql://ibor:ibor@localhost:5432/ibor",
        max_size = 5,
    )
    return PgPool(config)

@pytest.fixture(scope="module")
def local_rag_store(pg_pool: PgPool) -> LocalRagStore:
    return LocalRagStore(pg_pool)

def test_upsert_document(local_rag_store: LocalRagStore) -> None:
    doc = local_rag_store.upsert_document(
        source="pytest",
        external_id="pytest-doc-001",
        title="Test Document",
        metadata={"category": "demo", "ts": datetime.now().isoformat()},
    )
    assert doc.document_id > 0
    assert doc.source == "pytest"
    assert doc.external_id == "pytest-doc-001"
    assert doc.title == "Test Document"
    #assert doc.metadata == {"category": "demo", "ts": datetime.now().isoformat()}
    assert isinstance(doc.created_at, datetime)
    # assert isinstance(doc.updated_at, datetime)

def test_delete_document(local_rag_store: LocalRagStore) -> None:
    doc = local_rag_store.upsert_document(
        source="pytest",
        external_id="pytest-doc-002",
        title="Test Document 2",
        metadata={"category": "demo", "ts": datetime.now().isoformat()},
    )
    assert doc.document_id > 0
    local_rag_store.delete_document(doc.document_id)
    assert local_rag_store.get_document_by_id(doc.document_id) is None

def test_delete_document_by_id (local_rag_store: LocalRagStore) -> None:
    doc = local_rag_store.get_document_by_id(23)
    if doc is None:
        pytest.skip("Document id=1 not present in test database")
    local_rag_store.delete_document(doc.document_id)