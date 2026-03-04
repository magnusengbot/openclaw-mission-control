# Configuration reference

This page collects the most important config values.

## Root `.env` (Compose)

See `.env.example` for defaults and required values.

### `NEXT_PUBLIC_API_URL`

- **Where set:** `.env` (frontend container environment)
- **Purpose:** Public URL the browser uses to call the backend.
- **Gotcha:** Must be reachable from the *browser* (host), not a Docker network alias.

### `LOCAL_AUTH_TOKEN`

- **Where set:** `.env` (backend)
- **When required:** `AUTH_MODE=local`
- **Policy:** Must be non-placeholder and at least 50 characters.

### `OFFLINE_LOCKDOWN`

- **Where set:** `.env` (backend)
- **Default:** `false`
- **Purpose:** Disable outbound-network features from Mission Control.
- **Effects when `true`:**
  - blocks skills pack synchronization (git clone from remote repos)
  - blocks marketplace install actions that pull from remote sources
  - blocks souls.directory fetch/search network calls
  - disallows `AUTH_MODE=clerk` (requires external auth service)
