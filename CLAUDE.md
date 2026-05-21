# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the project

**Start (dev mode with hot-reload):**
```bash
cp .env.example .env   # fill in POSTGRES_PASSWORD, APP_API_KEY, GEMINI_API_KEY
sudo docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

**Rebuild backend after Python dependency or schema changes:**
```bash
sudo docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build backend
```

**Run Flutter desktop:**
```bash
cd frontend
flutter pub get
flutter run -d linux
```

**Regenerate Dart freezed/json models after editing `*.dart` model files:**
```bash
cd frontend
dart run build_runner build --delete-conflicting-outputs
```

**Apply new Alembic migration:**
```bash
sudo docker compose exec backend alembic upgrade head
```

**Generate a new migration:**
```bash
sudo docker compose exec backend alembic revision --autogenerate -m "description"
```

**Run backend tests:**
```bash
sudo docker compose exec backend pytest
```

**API docs (dev only):** `http://localhost:8000/docs`

## Architecture

### Backend (`backend/app/`)

FastAPI async app with SQLAlchemy 2 async + asyncpg. All DB access goes through `AsyncSession` from `app/database.py`. The dependency `DBSession = Depends(get_db)` and `Auth = Depends(verify_token)` are re-exported from `app/dependencies.py` for use in routers.

Auth is a static Bearer token (`APP_API_KEY` env var) — no JWT, single-user self-hosted app.

**Request flow:** Router → Service (`app/services/`) → ORM model. Routers never contain business logic. Services never import from routers.

**Core services:**
- `transaction_service.py` — most complex service; calls `exchange_service.convert()` to update account balances and store `amount_base` in base currency on create/update/delete
- `exchange_service.py` — fetches from `open.er-api.com/v6/latest/{base}`, 1-hour in-memory cache, hardcoded fallback for UZS/TJS/RUB
- `account_service.py` — account CRUD and balance operations
- `analytics_service.py` — aggregates spending/income data for charts
- `statement_import_service.py` — bulk statement import. CSV/TXT parsed deterministically via `csv.Sniffer` + multilingual (EN/RU) `HEADER_ALIASES`; XLSX parsed with `openpyxl` (header row auto-detected, reuses `HEADER_ALIASES` via the shared `_rows_to_entries`); PDFs first try the embedded text layer via `pdftotext` (poppler) — deterministic, **no AI quota used** (`_parse_alif_text` handles the Alif Mobi layout), and only scanned PDFs with no text layer fall back to Gemini vision; images and non-tabular text also fall back to Gemini. The Gemini path sends the whole document in one call with a 32k-token budget and salvages rows from truncated JSON. Exposed as `POST /api/v1/accounts/{id}/import-statement`; the router (`accounts.py`) deduplicates against existing DB rows via `_tx_signature` (date+type+amount+currency+normalized description) and queues **one batched** AI categorization task (`categorize_batch`, ~80 rows/call) — never one call per row, which would exhaust the 20-requests/day free Gemini quota

**AI layer (`app/ai/`):**
- `client.py` — raw httpx calls to Gemini REST API (`gemini-2.5-flash`). No SDK. Uses `generateContent` for single calls and `streamGenerateContent?alt=sse` for chat streaming. `gemini_url()` raises a clear `RuntimeError` if `GEMINI_API_KEY` is unset
- `categorizer.py` — BackgroundTask triggered after transaction POST/PUT
- `ocr.py` — BackgroundTask triggered after receipt upload; resizes image with Pillow before sending to Gemini vision
- `assistant.py` — builds system prompt from live DB snapshot, maintains last 20 messages, streams SSE to Flutter
- `forecaster.py` — aggregates 6 months of SQL data, calls Gemini 2.5 Flash, caches result in `forecasts` table (TTL 24h)

### Frontend (`frontend/lib/`)

Flutter with Riverpod 2 (provider-per-file pattern, no codegen for providers). Navigation via go_router with a `ShellRoute` wrapping all main screens.

**Adaptive layout:** `ShellScreen` uses `LayoutBuilder` — `NavigationRail` for width ≥ `AppConstants.navBreakpoint`, `BottomNavigationBar` below it.

**API client:** `core/api/api_client.dart` wraps Dio with a Bearer token header. All providers get the client via `ref.read(apiClientProvider.future)`. The base URL and API key are stored in `shared_preferences` and configured in Settings screen.

**Data models:** All in `core/models/` as `freezed` classes with `json_serializable`. `build.yaml` configures `field_rename: snake` so JSON snake_case automatically maps to Dart camelCase.

**Exchange rates in Flutter:** `providers/exchange_provider.dart` calls `open.er-api.com` directly (not through backend). `convertAmount()` helper does two-step conversion via base currency. Used in Dashboard net-worth calc, Accounts screen total, and TransactionForm preview.

**Lock screen:** `providers/lock_provider.dart` stores PIN in `shared_preferences`. `app.dart` watches `lockProvider` — when `true`, renders `LockScreen` instead of the router entirely.

**Key providers:**
- `api_client_provider.dart` — Dio wrapper with auth header
- `transaction_provider.dart` — CRUD + categorize actions
- `account_provider.dart` — account management
- `category_provider.dart` — category CRUD
- `analytics_provider.dart` — dashboard data fetching
- `chat_provider.dart` — AI chat session management
- `exchange_provider.dart` — currency conversion
- `lock_provider.dart` — PIN lock state

## Key conventions

- Backend responses for transaction detail use `TransactionDetail` schema (includes `comments` and `receipts`); list endpoints use `TransactionOut` (no nested data)
- `get_transaction()` always uses `selectinload` for category, comments, and receipts to avoid lazy-load errors in async context
- Flutter `Transaction` model has `@Default([]) List<Receipt> receipts` — missing field in JSON silently defaults to empty list
- When editing backend schemas that are imported by other schemas, rebuild the Docker image
- Python deps are declared in `backend/pyproject.toml`, but the `Dockerfile` does **not** install from it — it has its own hardcoded `uv pip install` list. Adding a dependency requires editing **both**, then `--build backend`.
- No AI SDK is used — all AI calls (categorize, OCR, chat, forecast, statement import) go through `app/ai/client.py` via raw httpx to the Gemini REST API. Only `GEMINI_API_KEY` matters
- `pytest`/`pytest-asyncio` are installed only in the Docker `development` stage; there is no test suite in the repo yet, so `pytest` currently collects nothing
- `.env.example` still references `CLAUDE_API_KEY` — the actual env var used is `GEMINI_API_KEY`
- All async database operations use `AsyncSession`; never use synchronous SQLAlchemy methods
- Backend environment variables: `DATABASE_URL`, `GEMINI_API_KEY`, `APP_API_KEY`, `RECEIPTS_DIR`, `BASE_CURRENCY` (default: USD)
- Frontend API configuration is user-configurable via Settings screen (stored in `shared_preferences`)
