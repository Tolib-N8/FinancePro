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

**API docs (dev only):** `http://localhost:8000/docs`

## Architecture

### Backend (`backend/app/`)

FastAPI async app with SQLAlchemy 2 async + asyncpg. All DB access goes through `AsyncSession` from `app/database.py`. The dependency `DBSession = Depends(get_db)` and `Auth = Depends(verify_token)` are re-exported from `app/dependencies.py` for use in routers.

Auth is a static Bearer token (`APP_API_KEY` env var) — no JWT, single-user self-hosted app.

**Request flow:** Router → Service (`app/services/`) → ORM model. Routers never contain business logic. Services never import from routers.

`transaction_service.py` is the most complex service — it calls `exchange_service.convert()` to update account balances in the account's currency and store `amount_base` in the base currency on every create/update/delete.

**AI layer (`app/ai/`):**
- `client.py` — raw httpx calls to Gemini REST API (`gemini-1.5-flash`). No SDK. Uses `generateContent` for single calls and `streamGenerateContent?alt=sse` for chat streaming.
- `categorizer.py` — BackgroundTask triggered after transaction POST/PUT.
- `ocr.py` — BackgroundTask triggered after receipt upload; resizes image with Pillow before sending to Gemini vision.
- `assistant.py` — builds a system prompt from live DB snapshot, maintains last 20 messages, streams SSE to Flutter.
- `forecaster.py` — aggregates 6 months of SQL data, calls Haiku, caches result in `forecasts` table (TTL 24h).

**Exchange rates (`app/services/exchange_service.py`):** Fetches from `open.er-api.com/v6/latest/{base}`, 1-hour in-memory cache, hardcoded fallback rates for when API is unreachable. UZS, TJS, RUB use fallback only (not in ECB dataset).

### Frontend (`frontend/lib/`)

Flutter with Riverpod 2 (provider-per-file pattern, no codegen for providers). Navigation via go_router with a `ShellRoute` wrapping all main screens.

**Adaptive layout:** `ShellScreen` uses `LayoutBuilder` — `NavigationRail` for width ≥ `AppConstants.navBreakpoint`, `BottomNavigationBar` below it.

**API client:** `core/api/api_client.dart` wraps Dio with a Bearer token header. All providers get the client via `ref.read(apiClientProvider.future)`. The base URL and API key are stored in `shared_preferences` and configured in Settings screen.

**Data models:** All in `core/models/` as `freezed` classes with `json_serializable`. `build.yaml` configures `field_rename: snake` so JSON snake_case automatically maps to Dart camelCase.

**Exchange rates in Flutter:** `providers/exchange_provider.dart` calls `open.er-api.com` directly (not through backend). `convertAmount()` helper does two-step conversion via base currency. Used in Dashboard net-worth calc, Accounts screen total, and TransactionForm preview.

**Lock screen:** `providers/lock_provider.dart` stores PIN in `shared_preferences`. `app.dart` watches `lockProvider` — when `true`, renders `LockScreen` instead of the router entirely.

## Key conventions

- Backend responses for transaction detail use `TransactionDetail` schema (includes `comments` and `receipts`); list endpoints use `TransactionOut` (no nested data).
- `get_transaction()` always uses `selectinload` for category, comments, and receipts to avoid lazy-load errors in async context.
- Flutter `Transaction` model has `@Default([]) List<Receipt> receipts` — missing field in JSON silently defaults to empty list.
- When editing backend schemas that are imported by other schemas, rebuild the Docker image.
- `.env.example` still references `CLAUDE_API_KEY` — the actual env var used is `GEMINI_API_KEY`.
