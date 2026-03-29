# ─────────────────────────────────────────────────────────────────────────────
# IBOR UI (React + Vite) Dockerfile
# Multi-stage build: Build → Nginx server
# ─────────────────────────────────────────────────────────────────────────────

# Stage 1: Build with Node.js
FROM node:22-alpine AS builder

WORKDIR /build

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build for production
RUN npm run build

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built artifacts from builder
COPY --from=builder /build/dist /usr/share/nginx/html

# Copy Nginx configuration
RUN cat > /etc/nginx/conf.d/default.conf <<'EOF'
# Enable dynamic DNS resolution
resolver 127.0.0.11 valid=10s;
set $upstream_ibor_middleware ibor-middleware:8080;
set $upstream_ibor_ai_gateway ibor-ai-gateway:8000;

server {
    listen 5173;
    server_name _;

    # Serve static files
    location / {
        root /usr/share/nginx/html;
        index index.html;

        # Support SPA routing: if file not found, serve index.html
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to FastAPI gateway
    location /analyst/ {
        proxy_pass http://$upstream_ibor_ai_gateway/analyst/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }

    # Proxy API calls
    location /api/ {
        proxy_pass http://$upstream_ibor_middleware/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css text/javascript application/javascript application/json;
    gzip_min_length 1000;
}
EOF

# Create non-root user (Alpine style)
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /usr/share/nginx/html /var/cache/nginx /var/log/nginx

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5173/health || exit 1

# Expose port
EXPOSE 5173

# Run Nginx
CMD ["nginx", "-g", "daemon off;"]
