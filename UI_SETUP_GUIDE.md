# IBOR AI Analytics UI - Full Setup & Access Guide

## ✅ Status: UI is Up and Running

The IBOR Analytics Dashboard is **fully operational** and ready to use.

---

## 🌐 Access the UI

### **URL: http://localhost:5174/**

Open this link in your browser to access the complete portfolio analytics interface.

---

## 🎯 What You Can Do

### **Left Panel: Portfolio Snapshot**
- Total AUM and market composition
- P&L delta for the day
- Asset class breakdown

### **Center Panel: Position & Transaction Grids**
- **Positions Grid:** 50+ holdings across equities, bonds, futures, FX, options
  - Click any position to see transaction history
- **Transactions Grid:** Detailed trade history (when a position is selected)

### **Right Panel: AI Chat Analyst** 🤖
- Ask questions about your portfolio
- Get AI-powered analysis with market context
- Two toggles to control behavior:
  - **Include market data:** Toggle yfinance market data (faster when OFF)
  - **Portfolio context:** Toggle local portfolio data emphasis

---

## 💬 Chat Features

### **Try These Questions:**
```
1. What are my current positions?
2. Analyze my concentration risk in technology stocks
3. How did my portfolio perform today?
4. What is my exposure to US equities vs bonds?
5. Which positions are my largest holdings?
6. Tell me about my currency risk across EUR and GBP
7. What is my sector allocation?
```

### **Chat Settings**

**Include Market Data** (toggle)
- ✅ ON (default): Fetches live yfinance data, market context, news
  - Response time: 20-30 seconds
  - Rich with earnings dates, price changes, analyst targets
- ❌ OFF: IBOR data only, no external market data
  - Response time: 15-20 seconds
  - Faster, portfolio-focused

**Portfolio Context** (toggle)
- ✅ ON: Emphasize local portfolio data with minimal AI narrative
  - Shows actual holdings first
  - AI commentary filtered for market conditions only
- ❌ OFF: Full AI narrative with formattable response

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│  React UI (Vite dev server)                        │
│  http://localhost:5174                             │
└────────┬────────────────────────────────────────────┘
         │
    Proxy routes:
    ├─ /api/* → localhost:8080 (Spring Boot)
    ├─ /analyst/* → localhost:8000 (FastAPI)
    │
┌───┴────────────────────────────────────────────────┐
│  FastAPI AI Gateway (/analyst)                    │
│  http://localhost:8000                            │
│  ├─ /chat endpoint (posts to this)                │
│  ├─ Conversation RAG storage                      │
│  ├─ Market data caching (5-min TTL)               │
│  └─ Claude API integration                        │
└───┬──────────────────────────┬─────────────────────┘
    │                          │
┌───┴───────────────────┐  ┌───┴────────────────────┐
│ Spring Boot IBOR API  │  │ PostgreSQL + pgvector  │
│ http://localhost:8080 │  │ localhost:5432/ibor    │
│ ├─ /positions         │  │ ├─ ibor.* (facts)      │
│ ├─ /pnl               │  │ ├─ conv.* (RAG)        │
│ ├─ /prices            │  │ └─ stg.* (staging)     │
│ └─ /trades            │  │                         │
└──────────────────────┘  └──────────────────────┘
```

---

## 🚀 Running All Services

### **One-Command Start** (from project root)

```bash
./start_all.sh
```

This will start:
1. PostgreSQL (Docker)
2. Spring Boot (localhost:8080)
3. FastAPI (localhost:8000)
4. Vite UI (localhost:5174)

### **Stop All Services**

```bash
./stop_all.sh
```

---

## 📊 Recent Optimizations

### **Optimization #1: HikariCP Pool (10 → 25 connections)**
- Reduces database connection queueing
- Expected 10-20% improvement under load
- Requires Spring Boot restart (already configured)

### **Optimization #2: Market Data Caching (5-min TTL)**
- Cache yfinance snapshots, news, earnings
- 2-3% faster on repeated questions about same stocks
- Already active and verified

### **Performance Baseline**
- Average response: 23.9 seconds
- Range: 19.6 - 29.0 seconds
- 100% success rate in testing

---

## 🔧 UI Configuration

### **Files Modified for Chat Integration**

**src/components/AiChat.jsx**
- Added `marketContents` state toggle
- Updated API call to include `market_contents` and `portfolio_code`
- Added UI checkbox for market data control

**vite.config.js**
- Proxy `/api/*` → Spring Boot (8080)
- Proxy `/analyst/*` → FastAPI (8000)
- Dev server on port 5173 (falls back to 5174 if in use)

**src/App.jsx**
- Portfolio data loaded on startup
- Positions passed to AiChat component
- Transactions shown when position selected
- Theme toggle (dark/light)

---

## 📝 Example Workflow

1. **Open http://localhost:5174/**
   - Dashboard loads with portfolio data
   - 50 positions displayed in grid

2. **Ask a Question in Chat**
   - "What is my tech concentration?"
   - Chat submits to `/analyst/chat` endpoint

3. **View AI Response**
   - Claude analyzes positions + market data
   - Response shows:
     - Real holdings (AAPL $123,995, MSFT $114,561, etc.)
     - Current prices and market moves
     - Risk analysis and recommendations

4. **Toggle Market Data** (optional)
   - Turn OFF "Include market data" for faster responses
   - Useful for portfolio-only questions

---

## 🐛 Troubleshooting

### **Chat not responding?**
1. Check if FastAPI is running: `curl http://localhost:8000/health`
2. Check if Spring Boot is running: `curl http://localhost:8080/health`
3. Check vite logs: `tail -20 /tmp/vite.log`

### **Portfolio data empty?**
1. Verify PostgreSQL is running: `docker ps | grep postgres`
2. Run data bootstrap: `./ibor-starter/2_data_bootstrap.sh full`
3. Restart Spring Boot

### **Slow responses?**
- Try toggling "Include market data" OFF
- Check network latency: `curl -w "Total: %{time_total}s\n" http://localhost:8000/health`

---

## 📚 Documentation

- **Optimization Details:** `/internal/PERFORMANCE_OPTIMIZATION_RESULTS.md`
- **Chat Test Results:** `/internal/chat_response.txt`
- **API Endpoints:** Spring Boot Swagger at `http://localhost:8080/swagger-ui.html`
- **FastAPI Docs:** `http://localhost:8000/docs`

---

## ✨ Key Features

✅ **Real-time Portfolio Analytics**
- 50 positions across 6 asset classes
- Multi-currency (USD, EUR, GBP)
- Futures, options, bonds, equities

✅ **AI-Powered Analysis**
- Natural language questions
- Claude API integration
- Market context awareness

✅ **Performance Optimized**
- Parallel API calls
- 5-minute market data cache
- Connection pool tuning

✅ **Conversation Memory**
- Stores conversation history
- Semantic search across past analyses
- 5-minute embedding scheduler

---

## 🎬 Next Steps

1. **Open Browser:** http://localhost:5174/
2. **Load Portfolio:** Click "Submit" in filter bar (or use defaults)
3. **Ask a Question:** Type in chat panel
4. **Explore Features:** Toggle market data, select positions for transaction history

---

**Status:** ✅ All services running, UI fully operational
**Last Updated:** 2026-03-27 19:45 EDT

