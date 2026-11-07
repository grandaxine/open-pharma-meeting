# Open Pharma Meeting Protocol — working title, draft 0.1

JSON Schema 2020-12 and OpenAPI 3.1 are the public, language-independent boundary. `.invalid` schema IDs identify documents only; they are not services and validators must resolve them locally. `openapi.json` is a complete JSON-form OpenAPI document; no default `servers` entry is intentional. Deployment supplies a company-approved HTTPS origin.

## Data rules

Meeting contains RecordingMetadata, independent AccessPolicy, optional Transcript and typed ReportArtifact values. All identifiers are UUIDs. Dates are RFC3339 UTC. Language identifiers are BCP47 locale strings. Media timestamps are nonnegative seconds on concatenated recorded audio; pause wall time and rotation gaps are excluded. TranscriptSegment.end must be >= start; starts must be ordered. References must match their enclosing meeting/job. Chunk filenames must be safe relative `.caf` basenames and unique. SHA-256 is corruption detection, not a signed origin claim.

Structural JSON Schema validation must be followed by semantic checks for time ordering, cross-object identity, uniqueness and state transitions. Native MeetingCodec implements the MVP semantic subset. General semantic validation for every future backend payload remains backend work. Maximum imported meeting JSON is 100 MiB. The MVP accepts at most 24 hours of total recorded media (each chunk also bounded to 24 hours); semantic validation enforces the aggregate limit. Servers must define lower limits if needed and advertise them in namespaced capabilities before clients submit data.

`schemaVersion: "0.1"` is the only current accepted version. Negotiate using ConnectorCapabilities.protocolVersions. Unknown major versions must never be silently decoded; new incompatible drafts require explicit support. Additive interoperable data belongs in Meeting.extensions under reverse-domain keys (e.g. `org.example.compliance`). Consumers preserve these values without interpreting them as instructions. Ordinary unknown object properties may be ignored and are not guaranteed round-trip retention. Never put secrets in extensions.

Private is default for audio, raw transcript and reports independently. Restricted lists verified organization employee IDs; Organization grants only verified members of that organization. Tenant membership and owner identity come from trusted server state, not client claims. Backend authorization and audit are mandatory for every policy change and read/process operation.

## Discovery and identity

A company/MDM provisions the approved discovery URL. GET `/.well-known/open-pharma-meeting` returns capabilities, API base URL, issuer and scopes; there is no global directory. Discover the issuer's OIDC metadata and use authorization code + PKCE S256 through the native browser. Register mobile redirect URIs with company identity administrators. Validate TLS and approved origins; reject redirects carrying bearer credentials to another origin. Do not invent project-operated token endpoints.

The OpenAPI bearer scheme represents access tokens obtained from that OIDC integration, not a proprietary login API. Servers enforce scopes, issuer/audience/expiry and tenant binding. Before implementation, each company defines processing policies, approvals, residency, model/prompt governance, retention and audit.

## Mutations and asynchronous work

All PUT/POST operations require UUID Idempotency-Key. Scope by authenticated tenant + subject + operation/route. Retain request fingerprint and original status/body for at least 24 hours. Replay identical requests without repeating side effects, including concurrent requests; changed body with same key returns 409. Do not persist content in logs to implement this. The key is not authorization.

Transcript submission creates or replaces the approved transcript. Path meeting ID and body meetingID must agree; ownership creation is bound to authenticated subject/tenant by the server. Processing creates a queued job using a company-approved processingPolicyID, returns 202 with Location and Retry-After seconds. Poll with backoff; respect 429/503 Retry-After. States: queued -> running -> succeeded/failed/cancelled; queued may also fail/cancel. Terminal states do not revert. Result retrieval before success returns 409; failed jobs never return a fabricated success artifact. No job-cancellation endpoint is defined in draft 0.1.

Recheck policy before processing and before returning results, including after revocation. Scope report synchronization to meeting/report IDs; GET returns ETag. Policy/report PUT requires If-Match, with 412 for stale revisions. Policy revision increments atomically on success. List reports uses opaque stable cursor pagination (limit 1–100); nextCursor is omitted at end. Errors use code/message/requestID without sensitive content. Treat inaccessible resources as 404 where needed to prevent enumeration.

No audio-upload operation exists. Companies must explicitly negotiate any future audio-processing capability and obtain approved consent/policy before enabling it. AuditEvent is a server-side append-only event shape, not an endpoint accepting untrusted audit claims.

## Pharmaceutical extensions

Optional namespaced payload types: `medical-information`, `product-complaint`, `potential-adverse-event`, `compliance-review`, `field-documentation`, `training-summary`. Company schemas define their content and version. Reports should include source segment IDs, provenance, review status, approved escalation route and reviewer actions. Safety-relevant artifacts MUST set requiresHumanReview=true. Signal generation never determines reportability or satisfies an escalation obligation automatically. Authorized humans follow company-defined procedures and time requirements; the MVP performs no safety detection or regulatory decision-making.
