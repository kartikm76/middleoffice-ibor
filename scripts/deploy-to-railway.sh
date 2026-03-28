#!/bin/bash
set -e

# Deploy ibor-analyst to Railway using CLI (no web UI)
# Requires: railway CLI installed, RAILWAY_TOKEN set

echo "🚀 ibor-analyst Railway Deployment Script"
echo "==========================================="

# 1. Check prerequisites
echo ""
echo "1️⃣  Checking prerequisites..."

if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Install from: https://docs.railway.app"
    exit 1
fi

if [ -z "$RAILWAY_TOKEN" ]; then
    echo "⚠️  RAILWAY_TOKEN not set. Attempting to use railway login..."
    railway login
fi

echo "✅ Railway CLI ready"

# 2. Link to Railway project
echo ""
echo "2️⃣  Initializing Railway project..."

if [ ! -f ".railway/config.json" ]; then
    railway init
else
    echo "ℹ️  Using existing Railway project"
fi

# 3. Add PostgreSQL (if not already added)
echo ""
echo "3️⃣  Adding PostgreSQL database..."

if ! railway variable list | grep -q DATABASE_URL; then
    echo "📦 Adding PostgreSQL service..."
    railway add --database postgres
    sleep 5  # Wait for database to initialize
else
    echo "ℹ️  PostgreSQL already configured"
fi

# 4. Deploy services
echo ""
echo "4️⃣  Deploying services..."
echo "   - ibor-ai-gateway (Python FastAPI)"
echo "   - ibor-middleware (Java Spring Boot)"
echo "   - ibor-ui (React Vite frontend)"

railway up --detach

echo "⏳ Waiting for services to be ready... (this may take 2-3 minutes)"
sleep 30

# 5. Set environment variables
echo ""
echo "5️⃣  Configuring environment variables..."

read -p "Enter ANTHROPIC_API_KEY (sk-ant-...): " ANTHROPIC_KEY
if [ -n "$ANTHROPIC_KEY" ]; then
    railway variable set ANTHROPIC_API_KEY="$ANTHROPIC_KEY"
    echo "✅ ANTHROPIC_API_KEY set"
fi

read -p "Enter database password (PostgreSQL): " DB_PASSWORD
if [ -n "$DB_PASSWORD" ]; then
    railway variable set SPRING_DATASOURCE_PASSWORD="$DB_PASSWORD"
    echo "✅ SPRING_DATASOURCE_PASSWORD set"
fi

# Get the auto-generated DATABASE_URL
DATABASE_URL=$(railway variable list | grep DATABASE_URL | awk -F'=' '{print $2}' | xargs)
if [ -n "$DATABASE_URL" ]; then
    railway variable set SPRING_DATASOURCE_URL="$DATABASE_URL"
    railway variable set PG_DSN="$DATABASE_URL"
    echo "✅ Database connection variables set"
fi

# 6. Get public URLs
echo ""
echo "6️⃣  Retrieving public URLs..."

API_URL=$(railway variable list | grep RAILWAY_PUBLIC_DOMAIN | grep ibor-ai-gateway | awk -F'=' '{print $2}' | xargs)
MIDDLEWARE_URL=$(railway variable list | grep RAILWAY_PUBLIC_DOMAIN | grep ibor-middleware | awk -F'=' '{print $2}' | xargs)
UI_URL=$(railway variable list | grep RAILWAY_PUBLIC_DOMAIN | grep ibor-ui | awk -F'=' '{print $2}' | xargs)

if [ -n "$API_URL" ]; then
    railway variable set VITE_API_URL="https://$API_URL"
    echo "✅ Frontend API URL configured: https://$API_URL"
fi

# 7. Initialize database schema
echo ""
echo "7️⃣  Initializing database schema..."

read -p "Initialize database now? (y/n): " INIT_DB
if [ "$INIT_DB" = "y" ]; then
    for script in ibor-db/init/0{1..9}-*.sql; do
        if [ -f "$script" ]; then
            echo "   Executing $script..."
            railway run psql < "$script"
        fi
    done
    echo "✅ Database schema initialized"
else
    echo "⏭️  Skipping database initialization"
fi

# 8. Summary
echo ""
echo "✅ Deployment Complete!"
echo "==========================================="
echo ""
echo "📍 Service URLs:"
echo "   API Gateway:    https://$API_URL/docs"
echo "   Middleware:     https://$MIDDLEWARE_URL/swagger-ui.html"
echo "   Frontend:       https://$UI_URL"
echo ""
echo "📊 Monitor deployments:"
echo "   railway logs -s ibor-ai-gateway --follow"
echo "   railway logs -s ibor-middleware --follow"
echo "   railway logs -s ibor-ui --follow"
echo ""
echo "🔧 Useful commands:"
echo "   railway variable list     (view all env vars)"
echo "   railway open              (open Railway dashboard)"
echo "   railway redeploy          (redeploy latest)"
echo "   railway delete            (remove project)"
echo ""
