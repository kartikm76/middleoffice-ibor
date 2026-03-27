"""
Embedding Scheduler Service
============================

Runs every 5 minutes to embed conversations marked as pending_embedding=true.

Integrated into FastAPI lifespan to run as a background task.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from typing import Optional

from ai_gateway.service.conversation_service import ConversationService
from ai_gateway.config.db import PgPool

log = logging.getLogger(__name__)


class EmbeddingScheduler:
    """Background scheduler for embedding conversations."""

    def __init__(self, conversation_service: ConversationService, pg_pool: PgPool):
        """
        Args:
            conversation_service: Service to embed conversations
            pg_pool: Database connection pool
        """
        self._service = conversation_service
        self._pool = pg_pool
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self._interval_seconds = 300  # 5 minutes

    async def start(self) -> None:
        """Start the scheduler background task."""
        if self._running:
            log.warning("Scheduler already running")
            return

        self._running = True
        self._task = asyncio.create_task(self._run_loop())
        log.info("Embedding scheduler started (interval: 5 minutes)")

    async def stop(self) -> None:
        """Stop the scheduler gracefully."""
        if not self._running:
            return

        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        log.info("Embedding scheduler stopped")

    async def _run_loop(self) -> None:
        """Main scheduler loop - runs every 5 minutes."""
        while self._running:
            try:
                await asyncio.sleep(self._interval_seconds)
                await self._embed_pending_conversations()
            except asyncio.CancelledError:
                break
            except Exception as e:
                log.error(f"Scheduler error: {e}", exc_info=True)
                # Continue on error - don't let one failure break the loop

    async def _embed_pending_conversations(self) -> None:
        """Fetch and embed all conversations pending embedding."""
        try:
            # Query for all conversations with pending_embedding=true
            with self._pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT conversation_id, analyst_id, context_type, context_id
                        FROM conv.conversation
                        WHERE pending_embedding = true
                        ORDER BY updated_at ASC
                        LIMIT 100
                        """
                    )
                    rows = cur.fetchall()

            if not rows:
                log.debug("No pending conversations to embed")
                return

            log.info(f"Found {len(rows)} conversations to embed")

            # Embed each conversation
            for row in rows:
                try:
                    conversation_id = row["conversation_id"]
                    analyst_id = row["analyst_id"]
                    context_type = row["context_type"]
                    context_id = row["context_id"]

                    log.debug(f"Embedding conversation {conversation_id}")

                    await self._service.embed_and_store(
                        conversation_id=conversation_id,
                        context_type=context_type,
                        context_id=context_id,
                        analyst_id=analyst_id,
                    )

                    log.debug(f"Embedded conversation {conversation_id}")

                except Exception as e:
                    log.error(
                        f"Failed to embed conversation {conversation_id}: {e}",
                        exc_info=True,
                    )
                    # Continue with next conversation on error

            log.info(f"Embedding cycle complete ({len(rows)} conversations processed)")

        except Exception as e:
            log.error(f"Failed to fetch pending conversations: {e}", exc_info=True)
