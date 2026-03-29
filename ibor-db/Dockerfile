# ─────────────────────────────────────────────────────────────────────────────
# IBOR Database (PostgreSQL + pgvector) Dockerfile
# Pre-loads schema and CSV data on startup
# ─────────────────────────────────────────────────────────────────────────────

FROM pgvector/pgvector:pg16

WORKDIR /data

# Copy initialization scripts (loaded automatically on first startup)
COPY init/*.sql /docker-entrypoint-initdb.d/

# Copy CSV data files (available for COPY commands in SQL scripts)
COPY data/*.csv /data/

# Default environment variables (can be overridden in docker-compose.yml)
ENV POSTGRES_DB=ibordb
ENV POSTGRES_USER=ibor
ENV POSTGRES_PASSWORD=ibor

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB || exit 1

# Expose port
EXPOSE 5432
