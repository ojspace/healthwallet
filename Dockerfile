FROM oven/bun:1 AS base
WORKDIR /app

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
