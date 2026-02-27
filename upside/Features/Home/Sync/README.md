# Home Remote Sync Contract

## App Configuration
Set these keys in `Info.plist` for network sync:

- `BACKEND_BASE_URL` (required)
  - Example: `https://api.upside.app`
- `BACKEND_HOME_STATE_PATH` (optional)
  - Default: `v1/home-state/me`
- `BACKEND_AUTH_TOKEN` (preferred)
  - Sent as `Authorization: Bearer <token>`
- `BACKEND_API_TOKEN` (legacy fallback)
  - Sent as `Authorization: Bearer <token>`

If `BACKEND_BASE_URL` is missing, the app runs local-only persistence.

## Endpoints
User-scoped endpoint with role query:

- `GET /<BACKEND_HOME_STATE_PATH>?role=creator|brand`
  - `200`: returns `HomePersistenceSnapshot` JSON
  - `404`: no remote state yet
- `PUT /<BACKEND_HOME_STATE_PATH>?role=creator|brand`
  - Request body: `HomePersistenceSnapshot` JSON
  - `2xx`: sync success
  - `409`: server has a newer snapshot; response includes latest server snapshot

## Payload
The app sends/reads this shape (milliseconds since epoch for dates):

- `schemaVersion: Int`
- `lastUpdatedAt: Date`
- `filters: HomeFilters`
- `profile: HomeProfileDraft`
- `conversations: [Conversation]`
- `swipedCardKeys: [String]`
- `savedCardKeys: [String]`

## Conflict Rule
- App compares `lastUpdatedAt` local vs remote.
- Remote applies only if newer than local.
- Local changes are debounced (~600ms) before push.
- Push/pull retries transient failures (network, 429, 5xx) with short exponential backoff.
- On `409`, app resolves with server snapshot and updates local state if server is newer.
