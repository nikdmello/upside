# Upside Backend

FastAPI + SQLAlchemy backend with authenticated, user-scoped Home sync.
This repo now includes:
- JWT-first auth (JWKS or HS256), with optional dev token fallback
- idempotent writes via `Idempotency-Key`
- request IDs via `X-Request-ID`
- Alembic migrations

## 1) Install deps

```bash
python3 -m pip install -r backend/requirements.txt
```

For backend tests:

```bash
python3 -m pip install -r backend/requirements-dev.txt
```

## 2) Run API

```bash
./backend/run.sh
```

When `AUTO_MIGRATE=true` (default in development), app startup runs Alembic `upgrade head`.
It also auto-stamps legacy local DBs that have app tables but no `alembic_version` row.

API base (local): `http://127.0.0.1:8787`

If testing on a physical iPhone, use your Mac LAN IP in app config, for example:
`http://192.168.1.167:8787`

## 3) Configuration

Environment variables:

- `APP_ENV=development|staging|production`
- `DATABASE_URL=...` (Postgres required for staging/production)
- `AUTO_MIGRATE=true|false` (should be `false` in staging/production)
- `CORS_ALLOW_ORIGIN=*`

Auth config:

- JWT (recommended):
  - `JWT_JWKS_URL=...` (for RS256/issuer-managed keys), or
  - `JWT_HS256_SECRET=...` (for local/test HS256)
  - Optional: `JWT_ISSUER=...`, `JWT_AUDIENCE=...`
  - Optional: `JWT_ALGORITHMS=RS256` (comma-separated)
- Dev fallback token auth:
  - `ALLOW_DEV_TOKEN_AUTH=true|false`
  - `SEED_USER_ID=...`
  - `SEED_USER_EMAIL=...`
  - `SEED_BEARER_TOKEN=...`

## 4) Migrations (Alembic)

Create or update schema:

```bash
alembic -c backend/alembic.ini upgrade head
```

Create new migration:

```bash
alembic -c backend/alembic.ini revision --autogenerate -m "describe change"
```

## 5) Auth model (dev fallback)

On startup, backend auto-seeds one dev user + token from env/config:

- `SEED_USER_ID` (default: `dev-user-1`)
- `SEED_USER_EMAIL` (default: `dev@upside.app`)
- `SEED_BEARER_TOKEN` (default: `upside-dev-token`)

Use header:

```http
Authorization: Bearer upside-dev-token
```

## 6) Endpoints

- `GET /health`
- `GET /v1/feed?role=creator|brand&limit=20&offset=0`
- `GET /v1/home-state/me?role=creator|brand`
- `PUT /v1/home-state/me?role=creator|brand`
- `POST /v1/swipes`
- `DELETE /v1/swipes/me?role=creator|brand`

`GET /v1/feed` behavior:
- Excludes cards this user already swiped on (`skip|save|match`).
- Re-ranks remaining cards from swipe signals:
  - personal signals from this user's recent swipes
  - global signals from all users in the same role pool
- Supports `debugRanking=true` query param to return ranking diagnostics.

`PUT` enforces last-write-wins by timestamp:
- If incoming `lastUpdatedAt` is older than server state, API returns `409` with the latest server snapshot.

Idempotency:
- Send `Idempotency-Key` on `PUT`.
- Replaying same key + same payload returns same success status.
- Reusing same key with different payload returns `409`.

Swipe example:

```bash
curl -i -X POST 'http://127.0.0.1:8787/v1/swipes' \
  -H 'Authorization: Bearer upside-dev-token' \
  -H 'Content-Type: application/json' \
  -d '{"role":"brand","cardKey":"creator-@nikdmello","action":"match"}'
```

Reset swipe history for current user (useful for testing):

```bash
curl -i -X DELETE 'http://127.0.0.1:8787/v1/swipes/me?role=brand' \
  -H 'Authorization: Bearer upside-dev-token'
```

Request IDs:
- API accepts `X-Request-ID` or generates one.
- Response always includes `X-Request-ID`.

## 7) iOS app wiring (Run Scheme env vars)

Set in Xcode Run Scheme > Environment Variables:

- `BACKEND_BASE_URL=http://127.0.0.1:8787` (simulator)
- `BACKEND_BASE_URL=http://<your-mac-lan-ip>:8787` (physical device)
- `BACKEND_HOME_STATE_PATH=v1/home-state/me`
- `BACKEND_AUTH_TOKEN=upside-dev-token`

Notes:
- App sends `role` as query item.
- Simulator can call localhost directly.

## 8) Quick curl test

```bash
curl -i http://127.0.0.1:8787/health
```

```bash
curl -i -X PUT 'http://127.0.0.1:8787/v1/home-state/me?role=brand' \
  -H 'Authorization: Bearer upside-dev-token' \
  -H 'Content-Type: application/json' \
  -d '{"schemaVersion":1,"lastUpdatedAt":1761333074000,"filters":{},"profile":{"displayName":"Upside Demo","headline":"Brand • Growth Team","bio":"Test","location":"Dubai","email":"demo@upside.app","websiteOrHandle":"upside.app"},"conversations":[],"swipedCardKeys":[],"savedCardKeys":[]}'
```

```bash
curl -s 'http://127.0.0.1:8787/v1/home-state/me?role=brand' \
  -H 'Authorization: Bearer upside-dev-token' | jq
```

Idempotency example:

```bash
curl -i -X PUT 'http://127.0.0.1:8787/v1/home-state/me?role=brand' \
  -H 'Authorization: Bearer upside-dev-token' \
  -H 'Idempotency-Key: demo-001' \
  -H 'Content-Type: application/json' \
  -d '{"schemaVersion":1,"lastUpdatedAt":1761333074000,"filters":{},"profile":{"displayName":"Upside Demo","headline":"Brand • Growth Team","bio":"Test","location":"Dubai","email":"demo@upside.app","websiteOrHandle":"upside.app"},"conversations":[],"swipedCardKeys":[],"savedCardKeys":[]}'
```

## 9) Run tests

```bash
python3 -m pytest backend/tests -q
```

## 10) Next production upgrades

- Add Redis-backed idempotency key TTL cleanup and distributed locks.
- Add rate limiting + abuse controls.
- Add structured JSON logs + tracing export (OpenTelemetry).
- Add role-based authorization policies per endpoint.
