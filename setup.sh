#!/usr/bin/env bash
set -euo pipefail

ROOT="ibor-hybrid-starter"
echo "Creating $ROOT ..."
rm -rf "$ROOT"
mkdir -p "$ROOT"/{docker/init,data,server/src/main/java/com/example/ibor/{llm,rag,structured,web},server/src/main/resources,client-angular/src/{app,assets,environments}}

# -----------------------------
# Top-level README
# -----------------------------
cat > "$ROOT/README.md" <<'EOF'
# IBOR Hybrid Starter (Step 1–4)

## Step 1 — Postgres in Docker (relational + pgvector)
```bash
cd docker
docker compose up -d