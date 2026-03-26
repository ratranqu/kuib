# Multi-stage Dockerfile for KUIB
# Stage 1: Build the Swift application
FROM swift:6.2-noble AS builder

WORKDIR /build

# Copy package manifest first for dependency caching
COPY Package.swift .
COPY Sources/ Sources/
COPY Tests/ Tests/

# Build in release mode
RUN swift build -c release --static-swift-stdlib

# Stage 2: Runtime image
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash kuib

WORKDIR /app

# Copy the built binary
COPY --from=builder /build/.build/release/kuib .

# Copy static assets
COPY Resources/ Resources/

# Set ownership
RUN chown -R kuib:kuib /app

USER kuib

# Default environment variables
ENV KUIB_HOST=0.0.0.0
ENV KUIB_PORT=8080
ENV KUIB_LOG_LEVEL=info

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

ENTRYPOINT ["./kuib"]
