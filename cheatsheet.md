## Middleoffice IBOR – Runbook Cheatsheet

This quick reference lists the exact shell commands to bring the full stack online on macOS (Colima + Docker, Spring Boot structured APIs, and the Python AI Gateway), plus a few sample curl calls for smoke-testing.

> All commands assume your project root is:
>
> `/Users/kartikmakker/Kartik_Workspace/middleoffice-ibor`

### 1. Infrastructure – Docker & Database

```bash
# Start Colima (Docker runtime)
colima start

# Launch Postgres + pgvector container
docker-compose up -d

# (Optional) Reload schemas + sample data
./load_all.sh full
```

### 2. Spring Boot Structured API (Java 21+ Runtime)

```bash
# Ensure the shell uses OpenJDK 23
export JAVA_HOME=$(/usr/libexec/java_home -v 23)
export PATH="$JAVA_HOME/bin:$PATH"

# Run the Spring Boot service
mvn -f /Users/kartikmakker/Kartik_Workspace/middleoffice-ibor/ibor-server/pom.xml spring-boot:run

# To stop, press Ctrl+C (or kill the Java process).
```

### 3. Python AI Gateway (FastAPI + uvicorn)

```bash
cd /Users/kartikmakker/Kartik_Workspace/middleoffice-ibor/ai-gateway

# Set env vars (update OPENAI_API_KEY with your key)
export OPENAI_API_KEY="sk-..."  # required
export STRUCTURED_API_BASE="http://localhost:8080/api"  # default
export PYTHONPATH="/Users/kartikmakker/Kartik_Workspace/middleoffice-ibor/ai-gateway/src"

# Start the gateway (dev mode with autoreload)
uv run uvicorn ai_gateway.app:app --host 127.0.0.1 --port 8000 --reload

# To stop, press Ctrl+C (or `pkill -f "uvicorn ai_gateway.app:app"`).
```

### 4. Smoke-Test Commands

#### Spring Boot Structured API

```bash
# Positions snapshot
curl -s 'http://localhost:8080/api/positions?asOf=2025-01-03&portfolioCode=P-ALPHA&page=1&size=5' | jq

# PnL proxy
curl -s 'http://localhost:8080/api/pnl?portfolioCode=P-ALPHA&asOf=2025-01-03&prior=2025-01-01' | jq
```

#### AI Gateway Deterministic Endpoints

```bash
curl -s -X POST 'http://127.0.0.1:8000/agents/analyst/positions' \
  -H 'Content-Type: application/json' \
  -d '{"as_of":"2025-01-03","portfolio_code":"P-ALPHA"}' | jq

curl -s -X POST 'http://127.0.0.1:8000/agents/analyst/pnl' \
  -H 'Content-Type: application/json' \
  -d '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03","prior":"2025-01-01"}' | jq
```

#### AI Gateway LLM Chat Endpoint

```bash
curl -s -X POST 'http://127.0.0.1:8000/analyst/analyst-llm/chat' \
  -H 'Content-Type: application/json' \
  -d '{"question":"What are positions for P-ALPHA as of 2025-01-03?","portfolioCode":"P-ALPHA","asOf":"2025-01-03"}' | jq

curl -s -X POST 'http://127.0.0.1:8000/analyst/analyst-llm/chat' \
  -H 'Content-Type: application/json' \
  -d '{"question":"Explain portfolio P-ALPHA PnL between 2025-01-01 and 2025-01-03","portfolioCode":"P-ALPHA","asOf":"2025-01-03"}' | jq
```

### 5. Cleanup / Shutdown

```bash
# Stop AI gateway
pkill -f "uvicorn ai_gateway.app:app"

# Stop Spring Boot
pkill -f "ibor-server"

# Stop Docker containers
docker-compose down

# Optional: stop Colima
colima stop
```

Keep this file handy to spin up the environment quickly whenever you need to demo or develop against the IBOR platform.

API Key:
REDACTED