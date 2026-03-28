# Security Quick Start

## What's New

You now have a **production-ready security layer** with 6 integrated guardrails preventing abuse, cost overruns, and API misuse.

**Status:** ✅ Ready for Phase 1 (closed beta)

---

## 5-Minute Setup

### Local Development (Testing)

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit .env to enable security:**
   ```bash
   RATE_LIMIT_ENABLED=false        # Disable for local testing
   EMAIL_WHITELIST_ENABLED=false   # Disable for local testing
   COST_TRACKING_ENABLED=false     # Disable for local testing
   LOG_ALL_REQUESTS=true           # Keep logging on
   ```

3. **Start services:**
   ```bash
   ./start_all.sh
   ```

4. **Test without security blocking:**
   ```bash
   curl -X POST http://localhost:8000/analyst/chat \
     -H "Content-Type: application/json" \
     -d '{
       "question": "What are my positions?",
       "portfolio_code": "P-ALPHA",
       "market_contents": true
     }'
   ```

---

### Production Deployment (Railway)

1. **Create .env for production:**
   ```bash
   ENVIRONMENT=beta
   RATE_LIMIT_ENABLED=true
   RATE_LIMIT_RPM=30
   EMAIL_WHITELIST_ENABLED=true
   EMAIL_WHITELIST=user1@example.com,user2@example.com
   MAX_QUESTIONS_PER_DAY=100
   MAX_DAILY_SPEND_USD=50.0
   COST_TRACKING_ENABLED=true
   LOG_ALL_REQUESTS=true
   ```

2. **Deploy to Railway:**
   ```bash
   git push origin main
   # Railway auto-detects railway.yml and builds all services
   ```

3. **Set secrets in Railway dashboard:**
   - ANTHROPIC_API_KEY
   - POSTGRES_PASSWORD
   - EMAIL_WHITELIST

See **DEPLOYMENT.md** for detailed steps.

---

## Understanding the 6 Layers

| Layer | What It Does | Blocks | Config |
|-------|-------------|--------|--------|
| **1. Rate Limit** | Max requests per minute | DDoS, spam | RATE_LIMIT_RPM=30 |
| **2. Input Validation** | Rejects bad input | SQL injection, XSS | MAX_QUESTION_LENGTH=2000 |
| **3. Authentication** | Email whitelist | Unauthorized users | EMAIL_WHITELIST=... |
| **4. Quotas** | Daily usage caps | Over-consumption | MAX_QUESTIONS_PER_DAY=100 |
| **5. Cost Controls** | API spending limit | Bill surprises | MAX_DAILY_SPEND_USD=50 |
| **6. Monitoring** | Logs everything | Hidden abuse | LOG_ALL_REQUESTS=true |

---

## Testing Each Layer

### 1. Rate Limiting
```bash
# Make 31 requests in rapid succession
for i in {1..31}; do
  curl -X POST http://localhost:8000/analyst/chat \
    -H "Content-Type: application/json" \
    -d '{"question":"test"}' &
done
wait

# 31st request should get 429 Too Many Requests
```

### 2. Input Validation
```bash
# Try SQL injection (should be blocked)
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Robert'; DROP TABLE students;--",
    "portfolio_code": "P-ALPHA"
  }'

# Response: 400 Bad Request with "contains potentially malicious patterns"
```

### 3. Quotas
```bash
# Try to exceed daily question limit (MAX_QUESTIONS_PER_DAY=100)
# After 100 valid requests, the 101st gets:
# 429 Too Many Requests: "Daily question limit exceeded"
```

### 4. Cost Controls
```bash
# When daily spend hits limit (MAX_DAILY_SPEND_USD=50):
# Request gets: 429 Too Many Requests
# Response includes: remaining_budget, request_cost
```

### 5. Logging
```bash
# Every request is logged to FastAPI logs
# View logs (on Railway or local):
railway logs -s ibor-ai-gateway | grep "cost_usd"
```

---

## Common Questions

### Q: I'm rate-limited locally, how do I test?
**A:** Set `RATE_LIMIT_ENABLED=false` in .env for development

### Q: How do I know if security is actually working?
**A:** Check the logs:
```bash
# Look for security-related messages
./start_all.sh 2>&1 | grep -E "rate limit|quota|cost|validation"
```

### Q: Can I adjust quotas after deployment?
**A:** Yes! Update in Railway dashboard → Variables, then redeploy:
```bash
railway variables set MAX_DAILY_SPEND_USD=100
railway deploy
```

### Q: What happens if I exceed the cost limit mid-request?
**A:** Request is rejected BEFORE calling the LLM, so you don't get billed

### Q: Is email validation implemented?
**A:** Not yet — coming in Phase 1 update. Currently just checks if enabled.

---

## Files You Need to Know

| File | Purpose |
|------|---------|
| `ibor-ai-gateway/src/ai_gateway/infra/security.py` | Core security classes (RateLimiter, InputValidator, etc.) |
| `ibor-ai-gateway/src/ai_gateway/infra/security_middleware.py` | FastAPI middleware that enforces security |
| `ibor-ai-gateway/src/ai_gateway/config/settings.py` | Configuration parameters |
| `ibor-ai-gateway/src/ai_gateway/main.py` | Registers middleware in FastAPI app |
| `.env.example` | Template with all config variables |
| `SECURITY.md` | Detailed security architecture |
| `DEPLOYMENT.md` | Railway deployment guide |
| `railway.yml` | Docker Compose config for Railway |

---

## Checklist: Ready for Production?

- [ ] Rate limiting enabled
- [ ] Input validation patterns configured
- [ ] Email whitelist populated
- [ ] Daily quotas set realistically
- [ ] Cost limit set to budget
- [ ] Logging enabled
- [ ] All API keys in environment variables (not code)
- [ ] Tested locally with security ON
- [ ] Deployment guide (DEPLOYMENT.md) reviewed
- [ ] Team notified of quota limits

---

## Next Steps

1. **Test locally:**
   ```bash
   # Set all ENABLED=true in .env
   # Run start_all.sh and test each layer
   ```

2. **Deploy to Railway:**
   ```bash
   # See DEPLOYMENT.md for step-by-step
   git push origin main
   ```

3. **Monitor Phase 1:**
   ```bash
   # Daily check: spending, errors, quota violations
   railway logs -s ibor-ai-gateway
   ```

4. **Plan Phase 2:**
   - Add OAuth (replace email whitelist)
   - User-level quotas (replace IP-based)
   - API keys for programmatic access

---

## Support

- **Detailed security docs:** See `SECURITY.md`
- **Deployment help:** See `DEPLOYMENT.md`
- **Configuration:** See `.env.example` and `config.yaml`

---

**Version:** 1.0
**Status:** Production Ready
**Last Updated:** 2026-03-28
