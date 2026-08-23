# ==============================================================================
# Nearo Backend Multi-Stage Production Dockerfile
# Base: Python 3.11 Slim with PostGIS / GDAL runtime libraries
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build Dependencies
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libgeos-dev \
    libgdal-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Final Production Runner
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Install minimal runtime libraries for PostGIS / Geospatial extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libgeos-c1v5 \
    gdal-bin \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Create unprivileged system user and group
RUN groupadd -g 1001 nearo && \
    useradd -u 1001 -g nearo -m -s /bin/bash nearouser

# Copy application source
COPY --chown=nearouser:nearo . /app

# Switch to non-root user
USER nearouser

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health || exit 1

EXPOSE 8000

# Run asynchronous Uvicorn server with production workers
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4", "--proxy-headers", "--forwarded-allow-ips=*"]
