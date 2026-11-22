# PCMarket API v1

Versioned JSON API for the PCMarket iOS and Android apps. It is built on the
same domain services as the web application: `ListingSearch`, `CartSummary`,
`Checkout::PlaceOrder`, `Checkout::Form`, `ConversationStarter`,
`OfferResponse`, `Notifier`, the guarded `Order` transitions and Pundit
policies.

- Base URL: `/api/v1`
- Specification: [`openapi.yaml`](openapi.yaml), also served at `GET /api/v1/openapi.yaml`
- Human reference: `GET /api/docs`

## Authentication

`POST /api/v1/auth/sessions` accepts `email` and `password` and returns a bearer
token **once**:

```json
{
  "data": {
    "token": "…",
    "token_type": "Bearer",
    "expires_at": "2027-02-20T10:00:00Z",
    "user": { "id": 42, "email": "buyer@example.com" }
  },
  "meta": { "message": "Signed in." }
}
```

Send it on every authenticated request:

```
Authorization: Bearer <token>
```

Tokens are stored as SHA-256 digests and expire after 90 days by default.
`DELETE /api/v1/auth/sessions` revokes the current token. Every successful use
updates `last_used_at`, at most once per hour.

Sign-in respects Devise lockable, confirmable and the application's
suspended/banned status. Google sign-in (`POST /api/v1/auth/google`) verifies
the ID token with Google's tokeninfo endpoint. It requires at least one allowed
client ID in `GOOGLE_CLIENT_IDS` (comma-separated web, iOS and Android IDs) or
the legacy `GOOGLE_CLIENT_ID`. Without either variable the endpoint is disabled
and returns `503 google_sign_in_unavailable`. Accepted tokens must have a
verified email, an allowed audience, a Google issuer (`accounts.google.com` or
`https://accounts.google.com`) and a future `exp`. Registration respects
`registrations_enabled` and requires `terms_accepted: true`.

## Envelope

Successful responses:

```json
{
  "data": {},
  "meta": { "page": 1, "per_page": 24, "total": 120, "total_pages": 5 }
}
```

`data` is an object or an array. `meta` may also carry facets, active filters,
cursors or the unread total, depending on the endpoint.

Errors:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Los datos enviados no son válidos.",
    "details": { "title": ["no puede estar en blanco"] }
  }
}
```

| Status | Meaning |
|---|---|
| 400 | Missing or malformed parameters |
| 401 | Missing, invalid or expired token |
| 403 | Authenticated but not allowed |
| 404 | Resource not found |
| 409 | Invalid state transition |
| 422 | Validation failed |
| 429 | Rate limited |
| 503 | Maintenance mode (non-staff) |

Messages are translated with the request locale.

## Locale

Pass `?locale=en` or an `Accept-Language` header (`es`, `en`, `fr`, `de`, `it`,
`pt`). Invalid values fall back to Spanish. Enum names (conditions, labels,
tags, help categories) and validation messages follow the request locale.

## Pagination

Collections accept `page` and `per_page`. `per_page` defaults to 24 (12 for PC
Finder, 20 for notifications) and is capped at 100. Messages use a descending
cursor: read `meta.next_before` and send it as `?before=`.

## Caching

Anonymous category, listing, store, config and legal reads send
`Cache-Control: public, max-age=60` and an `ETag`. Send `If-None-Match` to
receive `304 Not Modified`.

## Rate limits

- 300 requests / 5 minutes per bearer token.
- 60 requests / 5 minutes per IP for anonymous API traffic.
- 10 login attempts / minute per IP and per email.
- 30 messages / 10 minutes per sender (domain rule).

Exceeding a limit returns `429` with the standard error envelope.

## CORS

Origins are read from `API_CORS_ORIGINS` (comma separated). No origin is allowed
by default.

## Versioning policy

- The path version (`/api/v1`) is stable. Breaking changes ship under a new
  version.
- Additive fields and endpoints may appear in `v1` without a version bump;
  clients must ignore unknown fields.
- Deprecated endpoints are announced in the spec (`deprecated: true`) for at
  least one app release before removal.
- `GET /api/v1/config` exposes `min_app_version` so old clients can prompt for
  an update.

## Local development

```bash
bin/rails server
curl http://localhost:3000/api/v1/config
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/me
```
