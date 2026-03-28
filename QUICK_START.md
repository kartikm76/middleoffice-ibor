# Quick Start - Frozen Environment

## One-Time Setup (First Time Only)

```bash
# Set JAVA_HOME in ~/.zshrc or ~/.bash_profile
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"

# Reload shell
source ~/.zshrc

# Verify Java 21
java -version

# Start Colima (Docker on Apple Silicon)
colima start

# Initialize Python environment from frozen uv.lock
cd ibor-ai-gateway
./setup-env.sh
```

---

## Every Session (Start Services)

```bash
cd /path/to/ibor-analyst

# Start all 4 services (PostgreSQL, Spring Boot, FastAPI, React UI)
./start_all.sh

# Wait for output:
# ✓ PostgreSQL is running
# ✓ Spring Boot is running (PID: xxxxx)
# ✓ FastAPI is running (PID: xxxxx)
```

---

## Access Services

| Service | URL |
|---------|-----|
| React UI | http://localhost:5173 |
| FastAPI Docs | http://localhost:8000/docs |
| Spring Boot Swagger | http://localhost:8080/swagger-ui.html |
| PostgreSQL | localhost:5432 |

---

## Test the Chat Endpoint

```bash
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question":"What are the top 3 positions?"}'
```

---

## Stop Services

```bash
./stop_all.sh
```

---

## Important: Frozen Dependencies

❌ **DON'T do this:**
```bash
pip install something
python -m pip install something
```

✅ **DO this instead:**
```bash
cd ibor-ai-gateway
uv add package-name  # Updates pyproject.toml + uv.lock
```

---

## Troubleshooting

### FastAPI won't start
```bash
cd ibor-ai-gateway
uv sync --frozen
```

### Java not found
```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
java -version  # Should show 21.x
```

### Docker not running
```bash
colima status  # Check if running
colima start   # Start if needed
```

### Complete reset
```bash
./stop_all.sh
docker compose down -v
rm -rf ibor-ai-gateway/.venv
./ibor-ai-gateway/setup-env.sh
./start_all.sh
```

---

## Full Documentation

See `ENVIRONMENT.md` for complete reference.
