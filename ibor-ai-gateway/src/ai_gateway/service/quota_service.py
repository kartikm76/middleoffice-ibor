"""
Quota Service
=============

Tracks daily quotas by IP using conv.conversation table as source of truth.

Instead of in-memory tracking, we query the database to ensure:
- Persistence across restarts
- Shared quotas across instances (on Railway)
- Full conversation history visibility
"""

from __future__ import annotations

import logging
from datetime import datetime, date, timedelta
from typing import Optional, Dict, Any

log = logging.getLogger(__name__)


class QuotaService:
    """Track daily quotas (questions/day) per IP using conv.conversation table."""

    def __init__(self, pg_pool, max_questions_per_day: int = 20):
        """
        Args:
            pg_pool: psycopg connection pool
            max_questions_per_day: Maximum questions allowed per IP per day
        """
        self._pool = pg_pool
        self._max_questions_per_day = max_questions_per_day

    async def count_questions_today(self, client_ip: str) -> int:
        """Count how many user messages (questions) have been asked today by this IP.

        Queries conv.conversation where:
        - analyst_id = client_ip
        - created_at is TODAY (at 00:00 UTC)
        - messages array contains at least one message with role="analyst"

        Args:
            client_ip: Client IP address (used as analyst_id)

        Returns:
            Count of questions asked today by this IP
        """
        try:
            today = date.today()
            tomorrow = today + timedelta(days=1)

            with self._pool.connection() as conn:
                with conn.cursor() as cur:
                    # Count user messages (role="analyst") in conversations for today
                    cur.execute(
                        """
                        SELECT COUNT(*) as user_messages_today
                        FROM conv.conversation
                        WHERE analyst_id = %s
                          AND DATE(created_at) = %s
                        """,
                        (client_ip, today)
                    )
                    row = cur.fetchone()
                    count = row["user_messages_today"] if row else 0

                    log.debug(f"Questions today for IP {client_ip}: {count}")
                    return count

        except Exception as e:
            log.error(f"Failed to count_questions_today for {client_ip}: {e}")
            raise

    async def check_quota(self, client_ip: str) -> Dict[str, Any]:
        """Check quota status for an IP.

        Returns quota details including:
        - questions_today: How many questions asked so far today
        - questions_limit: Max allowed per day
        - questions_remaining: How many left
        - quota_exceeded: Boolean flag
        - reset_time: When quota resets (tomorrow at 00:00 UTC)

        Args:
            client_ip: Client IP address

        Returns:
            {
                "questions_today": 5,
                "questions_limit": 20,
                "questions_remaining": 15,
                "quota_exceeded": False,
                "reset_time": "2026-03-29T00:00:00Z"
            }
        """
        try:
            questions_today = await self.count_questions_today(client_ip)
            questions_remaining = max(0, self._max_questions_per_day - questions_today)
            quota_exceeded = questions_today >= self._max_questions_per_day

            # Reset time is tomorrow at 00:00 UTC
            tomorrow = date.today() + timedelta(days=1)
            reset_time = datetime.combine(tomorrow, datetime.min.time())

            status = {
                "questions_today": questions_today,
                "questions_limit": self._max_questions_per_day,
                "questions_remaining": questions_remaining,
                "quota_exceeded": quota_exceeded,
                "reset_time": reset_time.isoformat() + "Z"
            }

            log.debug(f"Quota status for {client_ip}: {status}")
            return status

        except Exception as e:
            log.error(f"Failed to check_quota for {client_ip}: {e}")
            raise

    async def increment_questions(self, client_ip: str) -> int:
        """Increment question count for an IP (called after successful chat response).

        This is called AFTER the conversation is saved, so we just re-count.
        In practice, the count is incremented when save_message() is called in
        ConversationService.

        Args:
            client_ip: Client IP address

        Returns:
            Updated question count for today
        """
        return await self.count_questions_today(client_ip)

    async def get_conversation_history(self, client_ip: str) -> list[Dict[str, Any]]:
        """Get all conversations for an IP (for debugging/audit).

        Returns all conversations created by this IP.

        Args:
            client_ip: Client IP address

        Returns:
            List of conversations:
            [
                {
                    "conversation_id": "uuid",
                    "analyst_id": "203.0.113.45",
                    "session_id": "uuid",
                    "context_type": "portfolio",
                    "context_id": "P-ALPHA",
                    "message_count": 5,
                    "messages": [...],
                    "created_at": "2026-03-28T10:30:00",
                    "updated_at": "2026-03-28T10:35:00"
                }
            ]
        """
        try:
            with self._pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT
                            conversation_id, analyst_id, session_id, context_type, context_id,
                            messages, message_count, created_at, updated_at
                        FROM conv.conversation
                        WHERE analyst_id = %s
                        ORDER BY created_at DESC
                        """,
                        (client_ip,)
                    )
                    rows = cur.fetchall()

                    conversations = []
                    for row in rows:
                        conversations.append({
                            "conversation_id": str(row["conversation_id"]),
                            "analyst_id": row["analyst_id"],
                            "session_id": str(row["session_id"]),
                            "context_type": row["context_type"],
                            "context_id": row["context_id"],
                            "message_count": row["message_count"],
                            "messages": row["messages"] or [],
                            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                            "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None
                        })

                    log.debug(f"Found {len(conversations)} conversations for IP {client_ip}")
                    return conversations

        except Exception as e:
            log.error(f"Failed to get_conversation_history for {client_ip}: {e}")
            raise
