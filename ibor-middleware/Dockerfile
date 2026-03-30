# ─────────────────────────────────────────────────────────────────────────────
# IBOR Middleware (Spring Boot) Dockerfile
# Multi-stage build: Maven build → Runtime image (JRE 21)
# ─────────────────────────────────────────────────────────────────────────────

# Stage 1: Build with Maven
FROM maven:3.9-eclipse-temurin-21-jammy AS builder

WORKDIR /build

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:resolve

# Copy source code
COPY src ./src

# Build application (skip tests for speed in Docker)
RUN mvn clean package -DskipTests -q -Dspring-boot.build-image.skip=true

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime with minimal JRE
FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

# Copy built JAR from builder stage (Spring Boot executable JAR with all dependencies)
COPY --from=builder /build/target/ibor-server-*.jar app.jar

# Install curl for health check
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Expose port
EXPOSE 8080

# Run application
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
