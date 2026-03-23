---
title: "Design Decisions: Multi-Turn Portfolio Intelligence with LangChain + RAG"
date: 2026-03-22
author: Kartik Makker
description: "Why we chose Option A for implementing intelligent multi-turn portfolio analysis"
---

# Design Decisions: Multi-Turn Portfolio Intelligence with LangChain + RAG

## Executive Summary

We designed a **multi-turn analyst chatbot** that learns from past decisions to provide intelligent portfolio guidance. This document captures the key architectural decisions, why we made them, and what alternatives we rejected.

**Core insight**: RAG is for *semantic discovery*, not conversation memory. These require fundamentally different data structures and storage strategies.

---

## Problem Statement

Portfolio analysts need:
1. **Multi-turn conversations** - Ask a question, get a recommendation, ask a follow-up
2. **Institutional memory** - "You did this before. Here's what happened."
3. **Pattern recognition** - "Your past trim decisions succeeded 67% of the time"
4. **No boilerplate** - Use frameworks (LangChain) to handle complexity

**Initial confusion**: Can RAG + pgvector replace all our database needs?

**Answer**: No. RAG is for search. You still need relational storage for memory and tracking.

---

## Architecture Overview

### Three Responsibilities

| Responsibility | Technology | Purpose |
|---|---|---|
| **Conversation Memory** | PostgreSQL (JSONB) | Store full chat history for multi-turn resumption |
| **Decision Tracking** | PostgreSQL (structured) | Track what analyst decided, outcomes, analytics |
| **Semantic Search** | pgvector (embeddings) | Find similar past decisions for pattern matching |

### The Key Insight

These three are **NOT the same thing**:

```
Conversation: "Should I trim AAPL?" → "Recommend trim 50%" → "Okay, trim 50%"
    ↓
Stored as: Full messages in JSONB (for sequential memory)

Decision: Analyst decided to trim 50% at +18% gain on earnings play
    ↓
Stored as: Structured columns (decision_type, decision_pct, outcome_status)

Semantic representation: "earnings play, trim at high gain, hold for event"
    ↓
Stored as: Vector embedding (for RAG search)
```

Why three?
1. **JSONB** preserves order → Claude can resume conversation properly
2. **Structured columns** enable analytics → "Show me all trim decisions with success rate"
3. **Embeddings** enable discovery → "Find similar earnings plays to what I just did"

---

## Design Decision 1: Option A vs Option C

### Options Considered

**Option A: Embed Only Decisions**
```
Conversations: Stored in conversation_interactions (JSONB, no embedding)
Decisions: Stored in analyst_decisions (with embedding for RAG)
RAG: Search only decisions

Effort: 6.5 hours
Clarity: High (clear when to embed)
Noise: Low (only decisions indexed)
Value: High (learning from decisions, not questions)
```

**Option B: Embed All Conversations**
```
Conversations: Stored with embeddings (for finding similar analytical questions)
Decisions: Stored with embeddings (for finding similar decisions)
RAG: Search both simultaneously

Effort: 14 hours
Clarity: Low (ambiguous when conversation ends)
Noise: High (mix of questions + decisions in search results)
Value: Medium (also learn from analytical patterns)
```

### Why We Chose Option A

1. **Cleaner semantics**: A "decision" is discrete (analyst clicked "Save"). A "conversation" is ambiguous (when does it end?).

2. **Lower noise**: RAG searches only return actual decisions, not exploratory questions.

3. **Focused learning**: Core value is in decision patterns ("You trimmed 50% before, succeeded"), not question patterns ("You asked about option theta before").

4. **Cost**: Embed on-demand (per decision) vs continuously (per conversation).

5. **Time-to-MVP**: 6.5 hours vs 14 hours.

---

## Design Decision 2: Who Does What (Claude vs LangChain vs Backend)

### Claude's Job
- **Thinks** - extended thinking to reason over position data
- **Decides** - which tools to call based on what's needed
- **Synthesizes** - combines data from multiple tools into insights

### LangChain's Job
- **Orchestrates** - manages the loop: Claude thinks → calls tools → gets results → loops again
- **Remembers** - maintains ConversationBufferMemory (stores previous messages)
- **Executes** - invokes tools (actually calls functions, receives results, formats them)

### Backend's Job
- **Fetches** - retrieves position data, market data, past decisions
- **Embeds** - creates vector representations of decisions (EXPLICIT, not automatic)
- **Stores** - persists conversations and decisions to PostgreSQL + pgvector

### Concrete Example

```
User: "Should I trim AAPL?"

1. Claude (thinks): "I need position data, market context, and similar past decisions"

2. Claude (decides): "Call get_position, get_market_data, get_similar_decisions"

3. LangChain (orchestrates): Sees Claude wants tools
   → Executes get_position(AAPL)
   → Executes get_market_data(AAPL)
   → Executes get_similar_decisions(AAPL)

4. Backend (fetches):
   → Query: SELECT * FROM positions WHERE ticker='AAPL'
   → API call: yahoo_finance.get_earnings_date('AAPL')
   → Search: SELECT * FROM decision_embeddings WHERE ticker='AAPL' ORDER BY similarity DESC

5. LangChain (formats): Takes all results, gives to Claude

6. Claude (synthesizes): "You bought at $210, now $248. Past trim succeeded 2/3 times. Recommend: trim 50%"

7. Backend (stores): When analyst clicks "Save Decision"
   → INSERT into analyst_decisions (decision_type, decision_pct, ...)
   → embedding = openai.Embedding.create(decision_text)
   → INSERT into analyst_decisions.embedding
```

---

## Design Decision 3: Two-Table Schema (Not Three, Not One)

### Why Not One Table?

Tempting: Store everything in one table with JSON blob.

**Problems:**
- Can't easily aggregate: "Show me all decisions where decision_pct >= 50%"
- Can't track outcomes: "How many trim decisions succeeded?"
- Can't query by decision_type without parsing JSON

### Why Not Three Tables?

Initial design had `chat_sessions`, `chat_messages`, `analyst_decisions`, `decision_embeddings`.

**Problem**: Redundancy. `chat_sessions` was just grouping key for `chat_messages`. `decision_embeddings` could be a column in `analyst_decisions`.

### Final: Two Tables

**Table 1: conversation_interactions** (Memory)
```sql
CREATE TABLE conversation_interactions (
  interaction_id UUID PRIMARY KEY,
  session_id UUID,  -- groups multiple turns
  position_id VARCHAR,
  analyst_id VARCHAR,
  messages JSONB,  -- full chat history in order
  created_at TIMESTAMP
);
```
**Purpose**: Resume conversations, provide LangChain memory

**Table 2: analyst_decisions** (Tracking + RAG)
```sql
CREATE TABLE analyst_decisions (
  decision_id UUID PRIMARY KEY,
  interaction_id UUID,  -- links back to conversation
  position_id VARCHAR,
  analyst_id VARCHAR,
  decision_type VARCHAR,  -- trim, hold, add, sell_all
  decision_pct DECIMAL,
  ai_recommendation TEXT,
  analyst_reasoning TEXT,
  outcome_status VARCHAR,
  embedding VECTOR(1536),  -- pgvector, for RAG search
  created_at TIMESTAMP
);
```
**Purpose**: Track decisions, enable analytics, power RAG search

---

## Design Decision 4: JSONB vs Embedding (Why Both?)

### JSONB in conversation_interactions.messages

```json
{
  "messages": [
    {"role": "analyst", "content": "Should I trim AAPL?"},
    {"role": "ai", "content": "You bought at $210, now $248..."},
    {"role": "analyst", "content": "What if rates spike?"},
    {"role": "ai", "content": "Rates spike would..."}
  ]
}
```

**Why JSONB?**
- Sequential order matters (Claude needs to know conversation flow)
- Full text matters (Claude needs exact wording to resume)
- Can't reconstruct from embedding (vectors are ~1536 floats, not reversible)

**When used**: When analyst resumes session → load JSONB → pass to LangChain memory

---

### Embedding in analyst_decisions.embedding

```
Text: "AAPL earnings play, analyst trimmed 50% at +18% gain, held rest for event"
Vector: [0.234, -0.456, 0.789, ..., 0.012]  (1536 dimensions)
```

**Why embedding?**
- Enables semantic similarity search
- Analyst asks "MSFT earnings play, should I trim?" → find similar AAPL decision
- Can't do this with JSONB (text search is exact match or regex, not semantic)

**When used**: When Claude wants to find similar past decisions → search pgvector → retrieve analyst_decisions rows

---

## Design Decision 5: Embed Decisions EXPLICITLY, Not Automatically

### Anti-pattern
```python
# Don't do this:
@app.post("/chat/message")
async def chat(question):
    response = ai.respond(question)
    # ← automatically embed and store somewhere?
    # ← When? What if analyst doesn't save the conversation?
    # ← Wasteful to embed every response
```

### Pattern (What We Do)

```python
# Only embed when analyst explicitly saves
@app.post("/decisions/save")
async def save_decision(decision_type, decision_pct, reasoning):
    # Analyst clicked "Save Decision" button
    # ← Now embed
    embedding = openai.Embedding.create(decision_text)
    db.insert("analyst_decisions", {..., embedding})
```

**Why explicit?**
- Not every conversation yields a decision
- Analyst may ask "What if?" questions without committing
- Embedding costs money (so embed only valuable decisions)
- Clarity: You control exactly what gets indexed

---

## Design Decision 6: RAG Search Scope (Decisions Only, Not Conversations)

### Options

**Search all conversations** (Option B):
- Analyst asks "What about option pricing?"
- RAG finds: Past option pricing questions + answers
- Value: Low (informational, not learning)
- Noise: High (many exploratory questions)

**Search only decisions** (Option A):
- Analyst asks "Should I trim MSFT?"
- RAG finds: Past trim decisions (AAPL trim 50%, NVDA trim 33%)
- Value: High (pattern matching on actual decisions)
- Noise: Low (only committed decisions)

**We chose**: Decisions only.

**Future phase**: Could add analytical RAG if analysts request "I want to remember past analysis patterns". But MVP focuses on decision patterns.

---

## Design Decision 7: When to Update Outcome Status

### Scenario
```
Day 1: Analyst trims AAPL at +18% gain
       analyst_decisions.outcome_status = "pending"

Day 8: AAPL earnings released, stock +5%
       Analyst manually marks: "Successful outcome"
       analyst_decisions.outcome_status = "successful"

Day 30: Claude learns: "Your trim decisions succeeded 2/3 times"
```

### Design Choice: Manual outcome tracking (not automatic)

**Why not automatic?**
- Hard to define success (up 5% = success? 10%? depends on timeframe)
- Analyst may close position before original target
- Market data integration adds complexity

**Why manual?**
- Analyst knows the intent (was this a good decision?)
- Simple to implement (analyst clicks: outcome = "successful")
- Flexible (analyst can add notes: "Worked, but market rallied hard")

---

## Implementation Roadmap

### Phase 1: Foundation (MVP)
- [ ] Schema: 2 tables (conversation_interactions, analyst_decisions)
- [ ] LangChain: Agent with memory + tool calling
- [ ] Tools: get_position, get_market_data, get_similar_decisions
- [ ] Save decision endpoint + embedding
- [ ] RAG search in claude tools

**Effort**: ~7 hours
**Timeline**: 1 day
**Value**: Analyst can ask multi-turn questions, save decisions, see past patterns

### Phase 2: Enrichment
- [ ] Outcome tracking UI (analyst marks success/failure)
- [ ] Analytics dashboard (decision success rates by type, ticker, analyst)
- [ ] Extended thinking tuning (adjust thinking budget based on query complexity)

**Effort**: ~8 hours
**Timeline**: 1 day

### Phase 3: Analytical RAG (Future)
- [ ] Embed analytical conversations (for learning from exploration)
- [ ] Separate search path for "similar questions I've asked"
- [ ] Merge both decision + analytical results in Claude context

**Effort**: ~8 hours
**Timeline**: 1 day (if needed)

---

## Key Takeaways for Medium Post

1. **RAG ≠ Database**: RAG is semantic search. You still need a relational DB for memory and structured analytics.

2. **JSONB + Embeddings serve different purposes**: JSONB for sequential memory, embeddings for semantic discovery.

3. **Explicit vs automatic**: Embed only when analyst makes a decision. Don't embed every chat turn.

4. **Focused scope**: Start with decision patterns (high value), add analytical patterns later (lower value).

5. **Clear responsibilities**: Claude thinks, LangChain orchestrates, backend executes. Not all three do everything.

6. **Two tables beat three**: Avoid premature schema normalization. Simple schema wins.

---

## Appendix: FAQ

**Q: Why not use Redis for conversation memory instead of PostgreSQL JSONB?**
A: Need to track outcomes over time (which decisions succeeded?). Redis is ephemeral. PostgreSQL is persistent.

**Q: Why not embed conversations automatically when analyst closes chat?**
A: Ambiguous signal (did they finalize? are they coming back?). Explicit "Save Decision" is cleaner.

**Q: Why not use semantic search for everything?**
A: Embeddings lose structured information. Can't query "show me decisions where decision_pct >= 50" on vectors.

**Q: Can we use OpenAI's fine-tuning instead of RAG?**
A: Possible, but slower and more expensive. RAG gives instant access to past decisions. Fine-tuning requires retraining.

**Q: Why LangChain instead of raw Claude API?**
A: LangChain handles: memory persistence, tool orchestration, looping. Saves ~100 lines of boilerplate per endpoint.

---

## References

- Claude API Docs: https://docs.anthropic.com/claude/
- LangChain Docs: https://python.langchain.com/
- pgvector Docs: https://github.com/pgvector/pgvector
- OpenAI Embeddings: https://platform.openai.com/docs/guides/embeddings
