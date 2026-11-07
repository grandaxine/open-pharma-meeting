# Compatibility and conformance

Protocol 0.1 is a draft, not an established interoperability certification. A backend can implement the OpenAPI contract without modifying the eventual production-capable app adapter; the MVP has no production connector yet.

Run `python scripts/test_protocol.py` for structural fixture conformance. Swift tests add local semantic checks. An executable HTTP/authorization conformance harness is planned for milestone 2; fixture success alone is not backend conformance.

Required third-party backend test matrix:

- Validate every request/response against the ten schemas, and semantic invariants from protocol/0.1/README.md. Exercise valid fixtures, malformed UUIDs/times, unknown versions, negative/reversed ranges, mismatched meeting/job/report IDs, oversized payloads and unknown namespaced extensions.
- Company discovery and OIDC metadata use HTTPS and approved issuer/API origins. Require PKCE S256 and correct scopes/audience/expiry; reject ID tokens as access tokens. No maintainer service is contacted.
- Authenticated subjects cannot cross tenant boundaries or enumerate hidden resources. Repeat tests for all three visibility modes and each independently protected resource. Do not trust tenant/user IDs supplied in JSON.
- Duplicate idempotent mutations return the original resource/status/body during the 24-hour window. Different payload with same key returns 409. Scope keys by verified tenant, subject and operation; concurrent requests have one effect.
- Jobs return 202, Location and Retry-After; test queued/running/terminal transitions, retries, failures, permission revocation before execution and result unavailability before success.
- Report synchronization round-trips artifact content and review state. Reject stale If-Match with 412; pagination has stable cursors and no cross-tenant leakage.
- Policy writes require authorization and If-Match; atomically increment revision and audit the action. Previously downloaded copies cannot be recalled; disclose this limitation.
- Logs/audit contain no transcript/audio/prompt content or credentials. Retention, residency, model governance and human approval are verified against the deploying company's documented procedures.

Native iOS and future Kotlin producers must pass the same fixtures. Version identifiers and extension namespaces are platform-independent. Unknown ordinary fields can be ignored and need not survive round trips; extensions must be retained. Unsupported protocol versions fail closed with a clear capability error.
