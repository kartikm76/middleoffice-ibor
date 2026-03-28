# Security Architecture: 6-Layer Guardrails

## Executive Summary

IBOR Analyst implements a **6-layer security framework** designed to protect against abuse, control costs, and maintain system stability during Phase 1 (closed beta) and beyond.

**Layers:**
1. **Rate Limiting** — Per-IP request throttling
2. **Input Validation** — XSS/injection prevention
3. **Authentication** — Email whitelist → OAuth
4. **Quotas** — Daily usage caps
5. **Cost Controls** — API spending limits
6. **Monitoring** — Complete audit trail

---

## Layer 1: Rate Limiting

**Purpose:** Prevent DDoS attacks and abusive request patterns.

**Implementation:** Token bucket algorithm per client IP

**Configuration:**
```
RATE_LIMIT_ENABLED=true
RATE_LIMIT_RPM=30  # 30 requests per minute per IP
```

**How it works:**
1. Each IP gets a bucket with 30 tokens
2. Every request consumes 1 token
3. Bucket refills every 60 seconds
4. When empty: return 429 Too Many Requests

**Response Headers:**
```
X-RateLimit-Limit: 30
X-RateLimit-Remaining: 22
```

**Bypass scenarios:**
- Health checks (`/health`, `/docs`) skip rate limits
- Internal services (localhost) not rate limited

---

## Layer 2: Input Validation

**Purpose:** Block malicious queries and prevent injection attacks.

**Validation Rules:**

### Question Input
```
Length: 10-2000 characters
Pattern: No SQL keywords (drop, delete, exec, etc.)
         No XSS patterns (script, onload, etc.)
Encoding: UTF-8 only
```

**Configuration:**
```
MAX_QUESTION_LENGTH=2000
MIN_QUESTION_LENGTH=10
BANNED_KEYWORDS=sql,drop,delete,exec  # Comma-separated
```

### Portfolio Code
```
Pattern: ^[A-Z0-9\-_]{1,20}$
Examples: P-ALPHA, FUND-001, PORT_XYZ ✓
Examples: p-alpha, 123-456, ../../../ ✗
```

**Rejected Patterns:**
```python
# SQL Injection
"Robert'; DROP TABLE Students;--"
"' UNION SELECT * FROM..."

# XSS
"<script>alert('xss')</script>"
"javascript:alert(...)"

# Command Injection
"; rm -rf /"
"| cat /etc/passwd"
```

**Error Response (400 Bad Request):**
```json
{
  "detail": "Question contains potentially malicious patterns."
}
```

---

## Layer 3: Authentication

**Phase 1 (Current):** Email whitelist
**Phase 2:** OAuth (Google/GitHub)
**Phase 3:** API keys + subscription tiers

### Phase 1: Email Whitelist

**Configuration:**
```
EMAIL_WHITELIST_ENABLED=true
EMAIL_WHITELIST=user1@example.com,user2@example.com,team@example.com
```

**Implementation Plan:**
- Add email field to chat request
- Validate against whitelist before processing
- Log all requests with email for audit trail
- Return 401 Unauthorized if not whitelisted

**Coming in next update** — UI component for email input

---

## Layer 4: Quotas

**Purpose:** Control resource consumption and fair-use.

**Daily Limits per IP:**

```
MAX_QUESTIONS_PER_DAY=100
MAX_TOKENS_PER_DAY=500000
```

**How quotas work:**

1. Each IP tracked separately by date
2. Quota counter resets at UTC midnight
3. When limit exceeded: 429 Too Many Requests

**Response (when quota exceeded):**
```json
{
  "detail": "Daily question limit exceeded (100 questions per day)",
  "today_usage": {
    "questions": 101,
    "tokens": 487500
  }
}
```

**Token Estimation:**
- Each LLM call estimates ~1,000 tokens
- Market data lookup: ~500 tokens each
- Quoted in response for transparency

**Monitoring:**
```
# Check current usage
GET /admin/quotas/{ip_address}

Response:
{
  "ip": "203.0.113.42",
  "date": "2026-03-28",
  "questions": 45,
  "tokens": 234500,
  "remaining_questions": 55,
  "remaining_tokens": 265500
}
```

---

## Layer 5: Cost Controls

**Purpose:** Prevent runaway API bills; ensure predictable spending.

**Configuration:**
```
COST_TRACKING_ENABLED=true
MAX_DAILY_SPEND_USD=50.0
```

**How it works:**

1. Every API call tracked for token count
2. Token count converted to USD using current pricing:
   - Claude 3.5 Sonnet input: $0.003 per 1K tokens
   - Claude 3.5 Sonnet output: $0.015 per 1K tokens
3. Daily spend accumulated
4. When limit exceeded: Request rejected with 429

**Cost Estimation Algorithm:**
```python
input_tokens = 5000  # From API
output_tokens = 1500  # From API response

input_cost = (input_tokens / 1000) * 0.003
output_cost = (output_tokens / 1000) * 0.015
total_cost = input_cost + output_cost  # ~$0.0405
```

**Response (when limit exceeded):**
```json
{
  "detail": "Daily spending limit exceeded ($50.00)",
  "today_spend": "$48.50",
  "remaining_budget": "$1.50",
  "cost_of_request": "$2.00"
}
```

**Monitoring Dashboard (Coming):**
```
Today's spend: $23.50 / $50.00 (47%)
Average per request: $0.52
Requests remaining: ~48
Last request cost: $0.38
```

**Emergency Override:**
```bash
# If you need to process urgent request
railway variables set MAX_DAILY_SPEND_USD=100

# Don't forget to reduce back after emergency
railway variables set MAX_DAILY_SPEND_USD=50
```

---

## Layer 6: Monitoring & Logging

**Purpose:** Complete audit trail for security, compliance, and debugging.

**What's Logged:**
```json
{
  "timestamp": "2026-03-28T14:32:15Z",
  "client_ip": "203.0.113.42",
  "endpoint": "/analyst/chat",
  "method": "POST",
  "question_preview": "What are my top positions?",
  "response_status": 200,
  "response_time_ms": 2340,
  "tokens_used": 6500,
  "cost_usd": 0.038,
  "error": null
}
```

**Configuration:**
```
LOG_ALL_REQUESTS=true
ALERT_ON_QUOTA_VIOLATION=true
```

**Query Recent Logs:**
```bash
# Via FastAPI admin endpoint
GET /admin/logs?limit=100

# Get logs for specific IP
GET /admin/logs?client_ip=203.0.113.42&limit=50

# Get logs for specific date
GET /admin/logs?date=2026-03-28&limit=100
```

**Monitoring Alerts (via logging):**
- ⚠️ Rate limit exceeded → WARNING level
- 💰 Cost approaching limit → WARNING level
- ❌ Invalid input pattern → INFO level
- 🔐 Quota violation → ERROR level

**Log Retention:**
- In-memory: Last 10,000 requests
- Database: All requests (for audit trail)
- Analytics: Daily summaries

---

## Threat Model & Mitigations

| Threat | Impact | Mitigation | Layer |
|--------|--------|-----------|-------|
| **DDoS Attack** | Service unavailable | Rate limiting (30 req/min) | 1 |
| **SQL Injection** | Data breach | Input validation, pattern blocking | 2 |
| **XSS via Question** | Session hijacking | HTML encoding, sanitization | 2 |
| **Brute Force Guessing** | Unauthorized access | Email whitelist (Phase 1) | 3 |
| **Quota Bypass** | Over-consumption | Daily counter per IP | 4 |
| **Cost Runaway** | Unexpected bill | Spending limit hard stop | 5 |
| **Unauthorized Use** | Billing abuse | API key validation (Phase 2) | 3 |
| **Malformed Requests** | Crashes | Request validation | 2 |
| **Replay Attacks** | Duplicate requests | Session tokens (Phase 2) | 3 |

---

## Security Checklist for Deployment

### Before going live:

- [ ] Rate limiting enabled (`RATE_LIMIT_ENABLED=true`)
- [ ] Input validation enabled (banned keywords configured)
- [ ] Email whitelist set (`EMAIL_WHITELIST_ENABLED=true`, addresses populated)
- [ ] Quotas configured (daily question/token limits set)
- [ ] Cost tracking enabled (`COST_TRACKING_ENABLED=true`)
- [ ] Cost limit set to realistic amount (`MAX_DAILY_SPEND_USD=50`)
- [ ] Request logging enabled (`LOG_ALL_REQUESTS=true`)
- [ ] HTTPS enforced on Railway (auto-configured)
- [ ] CORS properly configured (only allow intended origins)
- [ ] API keys/secrets not in code (using environment variables)
- [ ] Database connections encrypted (Railway provides SSL)

### Daily operations:

- [ ] Review spending vs. limit
- [ ] Check error logs for anomalies
- [ ] Monitor response times (should be <5s for typical queries)
- [ ] Verify quota resets at midnight UTC

---

## Advanced: Custom Security Policies

To extend the security layer:

### Add Custom Input Filters
```python
# In security.py
CUSTOM_PATTERNS = [
    r"market manipulation",  # Business rule
    r"insider trading",      # Compliance rule
]

# Add to InputValidator.validate_question()
for pattern in CUSTOM_PATTERNS:
    if re.search(pattern, question, re.IGNORECASE):
        return False, f"Question contains prohibited topic: '{pattern}'"
```

### Implement IP Reputation
```python
# Check IP against known blocklists
async def check_ip_reputation(client_ip: str) -> bool:
    # Integration with AbuseIPDB, Project Honey Pot, etc.
    pass
```

### Add Geographic Restrictions
```python
# Allow only specific countries
ALLOWED_COUNTRIES = ["US", "CA", "GB", "AU"]

async def check_geo_restriction(client_ip: str) -> bool:
    # Lookup IP geolocation
    # Return True if in ALLOWED_COUNTRIES
    pass
```

---

## Future: Phase 2 & Beyond

### Phase 2 (Q2 2026):
- OAuth integration (Google/GitHub)
- User-level quotas (replace IP-based)
- API key system
- Premium tier (higher quotas)

### Phase 3 (Q3 2026):
- Subscription billing (Stripe)
- Usage analytics dashboard
- Custom quotas per user tier
- Fraud detection (ML-based)
- Advanced audit logging

---

## Glossary

| Term | Meaning |
|------|---------|
| **Rate Limit** | Max requests per time window (30/min) |
| **Quota** | Max resource consumption per period (100 questions/day) |
| **Cost Limit** | Max API spend per period ($50/day) |
| **Whitelist** | Allowed list (email addresses) |
| **Token** | LLM unit of text (roughly 4 chars = 1 token) |
| **Middleware** | Code that intercepts every request |
| **Guardrail** | Safety mechanism to prevent abuse |

---

## Support & Escalation

**Issue:** User is rate-limited repeatedly
**Action:** Check if legitimate heavy user; increase quota

**Issue:** Cost approaching daily limit
**Action:** Review usage patterns; warn user via email

**Issue:** Suspicious activity pattern
**Action:** Review logs; consider IP blocklist

**Issue:** Production incident (cost spike)
**Action:** Reduce quota/spending limit immediately

---

**Document Version:** 1.0
**Last Updated:** 2026-03-28
**Status:** Ready for Phase 1 deployment
