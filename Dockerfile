FROM oven/bun:1 AS base
WORKDIR /app

# Install curl for Coolify health checks
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Install deps
COPY backend/package.json backend/bun.lock* ./
RUN bun install --frozen-lockfile || bun install

# Copy source
COPY backend/src/ ./src/
COPY backend/tsconfig.json ./

# Create uploads dir
RUN mkdir -p /app/uploads

EXPOSE 8000

CMD ["bun", "run", "src/index.ts"]
