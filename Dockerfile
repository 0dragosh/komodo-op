# Build stage
FROM --platform=linux/amd64 golang:1.26-alpine AS builder
ARG APP_VERSION

# Install build dependencies (Only needed if CGO_ENABLED=1)
# RUN apk add --no-cache gcc musl-dev

WORKDIR /app

COPY go.mod ./

# Download dependencies with caching
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy the entire source code
COPY . .

# Build the application statically with caching
# Output binary to /app/komodo-op inside the builder stage
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -ldflags "-s -w -X main.Version=${APP_VERSION}" -o /app/komodo-op ./cmd/komodo-op

# Final stage
FROM --platform=linux/amd64 alpine:latest

# Create a non-root user and group (e.g., ID 1001)
# Using a fixed ID is generally better for consistency
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy the built binary from the builder stage
COPY --from=builder /app/komodo-op /app/komodo-op

# Ensure the binary is executable by the user
RUN chown appuser:appgroup /app/komodo-op && \
    chmod 750 /app/komodo-op && \
    chmod +x /app/komodo-op

# Set default environment variables (can be overridden at runtime)
ENV LOG_LEVEL="INFO"
ENV SYNC_INTERVAL="1h"

# Switch to the non-root user
USER appuser

# Run the application in daemon mode by default
ENTRYPOINT ["/app/komodo-op", "-daemon"]

# Add labels (optional but good practice)
LABEL org.opencontainers.image.source="https://github.com/0dragosh/komodo-op"
LABEL org.opencontainers.image.version=${APP_VERSION}
