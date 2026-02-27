# Upside Backend (Production-Style Skeleton)

FastAPI + SQLAlchemy backend with authenticated, user-scoped Home sync.

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

API base: `http://127.0.0.1:8787`

## 3) Auth model (dev)

On startup, backend auto-seeds one dev user + token from env/config:

- `SEED_USER_ID` (default: `dev-user-1`)
- `SEED_USER_EMAIL` (default: `dev@upside.app`)
- `SEED_BEARER_TOKEN` (default: `upside-dev-token`)

Use header:

```http
Authorization: Bearer upside-dev-token
```

## 4) Endpoints

- `GET /health`
- `GET /v1/home-state/me?role=creator|brand`
- `PUT /v1/home-state/me?role=creator|brand`

`PUT` enforces last-write-wins by timestamp:
- If incoming `lastUpdatedAt` is older than server state, API returns `409` with the latest server snapshot.

## 5) iOS app wiring (Run Scheme env vars)

Set in Xcode Run Scheme > Environment Variables:

- `BACKEND_BASE_URL=http://127.0.0.1:8787`
- `BACKEND_HOME_STATE_PATH=v1/home-state/me`
- `BACKEND_AUTH_TOKEN=upside-dev-token`

Notes:
- App sends `role` as query item.
- Simulator can call localhost directly.

## 6) Quick curl test

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

## 7) Run tests

```bash
python3 -m pytest backend/tests -q
```

## 8) Next production upgrades

- Replace dev token table auth with JWT verification (Auth0/Firebase/Clerk).
- Add Alembic migrations + separate staging/prod databases.
- Add rate limiting, request IDs, structured logging, and observability.
