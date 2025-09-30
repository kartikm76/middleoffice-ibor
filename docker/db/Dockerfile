# Stable Postgres 16 on Debian Bookworm
FROM postgres:16-bookworm

# Install pgvector packaged for this exact Postgres build
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-16-pgvector \
 && rm -rf /var/lib/apt/lists/*
