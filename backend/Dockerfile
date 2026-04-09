FROM python:3.12-slim AS base
WORKDIR /app

RUN apt-get update && apt-get install -y \
    libpq-dev gcc poppler-utils \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

COPY pyproject.toml .
RUN uv pip install --system \
    "fastapi>=0.115" "uvicorn[standard]>=0.30" \
    "sqlalchemy[asyncio]>=2.0" "asyncpg>=0.29" "alembic>=1.13" \
    "pydantic>=2.7" "pydantic-settings>=2.3" \
    "anthropic>=0.28" "python-multipart>=0.0.9" \
    "aiofiles>=23.0" "pdf2image>=1.17" "Pillow>=10.0" \
    "httpx>=0.27" "tenacity>=8.3" "python-dateutil>=2.9"

FROM base AS development
RUN uv pip install --system watchfiles pytest pytest-asyncio httpx

FROM base AS production
COPY . .
RUN chmod +x entrypoint.sh
CMD ["./entrypoint.sh"]
