"""
Embedding Provider - Local embeddings using sentence-transformers
No external API calls needed.
"""

from __future__ import annotations

import logging
from typing import List

try:
    from sentence_transformers import SentenceTransformer
    HAS_SENTENCE_TRANSFORMERS = True
except ImportError:
    HAS_SENTENCE_TRANSFORMERS = False

log = logging.getLogger(__name__)


class EmbeddingProvider:
    """Local embedding provider using sentence-transformers."""

    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        """
        Initialize embedding model.

        Args:
            model_name: HuggingFace model name for embeddings
                       Default: all-MiniLM-L6-v2 (384 dims, fast, good quality)
                       Alternative: all-mpnet-base-v2 (768 dims, slower, higher quality)
        """
        if not HAS_SENTENCE_TRANSFORMERS:
            raise RuntimeError(
                "sentence-transformers not installed. "
                "Run: pip install sentence-transformers"
            )

        log.info(f"Loading embedding model: {model_name}")
        self.model = SentenceTransformer(model_name)
        self.model_name = model_name
        self.dimension = self.model.get_sentence_embedding_dimension()
        log.info(f"Embedding model loaded: {model_name} ({self.dimension} dims)")

    async def embed(self, text: str) -> List[float]:
        """
        Generate embedding for text.

        Args:
            text: Text to embed

        Returns:
            Embedding vector (list of floats)
        """
        try:
            embedding = self.model.encode(text, convert_to_tensor=False)
            return embedding.tolist()
        except Exception as e:
            log.error(f"Failed to generate embedding: {e}")
            raise

    async def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """
        Generate embeddings for multiple texts (more efficient).

        Args:
            texts: List of texts to embed

        Returns:
            List of embedding vectors
        """
        try:
            embeddings = self.model.encode(texts, convert_to_tensor=False)
            return embeddings.tolist()
        except Exception as e:
            log.error(f"Failed to generate batch embeddings: {e}")
            raise
