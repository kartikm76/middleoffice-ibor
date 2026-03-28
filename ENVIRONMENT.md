# Environment Configuration & Setup

## Overview

This project uses **frozen, deterministic dependency management** to ensure consistent behavior across environments and time.

- **Python**: Managed by `uv` with locked dependencies in `ibor-ai-gateway/uv.lock`
- **Java**: Spring Boot 3.5.5 with Maven (requires Java 21)
- **Database**: PostgreSQL 16 with pgvector (Docker)

---

## ✅ One-Time Setup

### 1. Install System Dependencies

```bash
# macOS
brew install uv openjdk@21 postgresql docker

# Or with Colima for Docker (Apple Silicon)
brew install colima
colima start
```

### 2. Set JAVA_HOME Permanently

Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"
```

Then reload:
```bash
source ~/.zshrc  # or ~/.bash_profile
```

### 3. Initialize Python Environment (Frozen)

```bash
cd ibor-ai-gateway
./setup-env.sh
```

This creates `.venv` from the locked `uv.lock` file—no guessing, no drift.

---

## 🚀 Running Services

```bash
# Start all services (PostgreSQL + Spring Boot + FastAPI + React)
./start_all.sh
```

This script:
1. ✅ Starts PostgreSQL in Docker
2. ✅ Initializes database schema
3. ✅ Starts Spring Boot (Java 21, requires JAVA_HOME)
4. ✅ Syncs Python venv from `uv.lock` if needed
5. ✅ Starts FastAPI on port 8000

**Service endpoints:**
- Spring Boot: `http://localhost:8080` (Swagger: `/swagger-ui.html`)
- FastAPI: `http://localhost:8000` (Docs: `/docs`)
- React UI: `http://localhost:5173`
- PostgreSQL: `localhost:5432`

---

## 🔒 Frozen Dependencies

### What is "Frozen"?

The `ibor-ai-gateway/uv.lock` file locks **every single transitive dependency** to a specific version. Running `uv sync --frozen` creates an identical environment every time.

### Never Manually Install Packages

❌ **DON'T:**
```bash
pip install some-package
python -m pip install some-package
```

✅ **DO:**
```bash
# Add to ibor-ai-gateway/pyproject.toml, then:
uv sync
```

This updates `uv.lock` and ensures all teammates get the same versions.

### Why This Matters

- **Reproducibility**: Same code + same dependencies = same behavior
- **No "Works on my machine"**: Lock files eliminate environment drift
- **Team consistency**: Everyone syncs to the same `uv.lock`
- **CI/CD**: Deployments use identical frozen environments

---

## 🔧 Dependency Management

### Adding a Dependency

```bash
cd ibor-ai-gateway

# Add to pyproject.toml (manually or via command)
uv add package-name  # Interactive, updates pyproject.toml + uv.lock
# Or manually edit pyproject.toml, then:
uv sync
```

### Updating Locked Dependencies

```bash
# Refresh lock file (respects version constraints in pyproject.toml)
uv lock
# Then sync to get the changes
uv sync
```

### Viewing Environment

```bash
cd ibor-ai-gateway
.venv/bin/pip list          # Installed packages
cat uv.lock | grep "^name" | wc -l  # Total packages (including transitive)
```

---

## 🐛 Troubleshooting

### "ModuleNotFoundError: No module named 'X'"

→ Run `uv sync --frozen` to ensure venv is in sync with `uv.lock`

```bash
cd ibor-ai-gateway
uv sync --frozen
```

### "FastAPI fails to start"

→ Check that PYTHONPATH includes the `src/` directory:

```bash
cd ibor-ai-gateway
PYTHONPATH=./src .venv/bin/python -m uvicorn ai_gateway.main:app --reload
```

### "JAVA_HOME not set"

→ Spring Boot won't start. Set it:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
mvn spring-boot:run  # from ibor-middleware/
```

### "PostgreSQL connection refused"

→ Ensure Docker/Colima is running:

```bash
colima status  # Should show "RUNNING"
colima start   # If not running
docker ps      # Verify docker-postgres-1 is up
```

### Rebuilding Everything from Scratch

```bash
cd /path/to/ibor-analyst

# Stop services
./stop_all.sh 2>/dev/null || true

# Clean up
docker compose down -v  # Remove DB volumes
rm -rf ibor-ai-gateway/.venv

# Rebuild
./ibor-ai-gateway/setup-env.sh
./start_all.sh
```

---

## 📋 Environment Files

| File | Purpose | Status |
|------|---------|--------|
| `ibor-ai-gateway/pyproject.toml` | Python dependency definitions | ✅ Committed to git |
| `ibor-ai-gateway/uv.lock` | **Frozen dependency versions** | ✅ Committed to git |
| `ibor-ai-gateway/.env` | API keys, secrets (auto-created) | ⚠️ `.gitignore`d, not committed |
| `ibor-middleware/pom.xml` | Java Maven dependencies | ✅ Committed to git |
| `.java-version` | Java version specification | ✅ Committed to git |

---

## 🚫 What NOT to Do

- ❌ Manually edit `uv.lock` — let `uv` manage it
- ❌ Use `pip install` directly — breaks reproducibility
- ❌ Commit `.env` files with secrets
- ❌ Mix `pip`, `uv`, and `conda` in the same project
- ❌ Update Maven/Java versions without updating version files
- ❌ Assume your local environment matches the lock files

---

## ✅ Checklist Before Each Session

```bash
# 1. Verify Java 21 is set
java -version  # Should show 21.x

# 2. Verify Docker/Colima is running
colima status

# 3. Sync frozen Python environment
cd ibor-ai-gateway && uv sync --frozen

# 4. Start services
cd .. && ./start_all.sh
```

---

## 📚 References

- **uv documentation**: https://docs.astral.sh/uv/
- **Spring Boot docs**: https://spring.io/projects/spring-boot
- **FastAPI docs**: https://fastapi.tiangolo.com/
- **PostgreSQL**: https://www.postgresql.org/docs/
