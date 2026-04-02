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
- `BACKEND_FEED_PATH` (optional)
  - Default: `v1/feed`
- `BACKEND_SWIPE_PATH` (optional)
  - Default: `v1/swipes`
- `BACKEND_SWIPE_RESET_PATH` (optional)
  - Default: `v1/swipes/me`

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

Feed and swipe event endpoints:

- `GET /<BACKEND_FEED_PATH>?role=creator|brand&limit=20&offset=0`
  - `200`: returns card list for the role
  - Cards may include optional ranking metadata: `matchScore`, `matchReason`, `rankingDebug`
- `POST /<BACKEND_SWIPE_PATH>`
  - Body: `{ "role": "...", "cardKey": "...", "action": "skip|save|match" }`
  - `2xx`: event accepted
- `DELETE /<BACKEND_SWIPE_RESET_PATH>?role=creator|brand`
  - `200`: clears swipe history for this user + role (testing reset)

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
