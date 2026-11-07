# Platform-independent contracts

The contract describes behavior and wire data, independent of implementation language. Swift protocols live in the six Sources modules; Kotlin implementations may have idiomatic async/cancellation APIs.

| Contract | Inputs/outputs | Required behavior |
| --- | --- | --- |
| AudioRecorder | meeting/configuration -> RecordingMetadata | Explicit consent, native permission, start/pause/resume/stop, recorded-media timeline, interruption errors, finalized chunk integrity and recovery journal |
| TranscriptionEngine | recording + language + progress/cancellation -> Transcript | Advertise on-device language support; no silent remote fallback; ordered media timestamps; atomic result replacement |
| MeetingRepository | UUID + versioned Meeting <-> local durable records | Atomic saves, bounded validated imports, explicit corruption reporting, no path traversal, no implicit network fetch |
| SecureStorage | opaque key/data -> opaque data/absence | Native OS credential storage; no credentials in meeting JSON, logs or exports; explicit deletion and OS protection policy |
| EnterpriseConnector | approved discovery URL, transcript, job IDs, report/policy revisions -> capabilities/status/results | Company-owned endpoints, auth integration, opt-in approved submission, idempotency, asynchronous polling and cancellation-aware calls, TLS, server authorization |
| AccessPolicyManager | resource/action + verified identity + policy revision -> allow/deny or revised policy | Deny unknown identity; independent resources; server authorizes changes and audits revisions |
| ReportRenderer | typed ReportArtifact + target format -> exported bytes | Preserve report type, provenance/review fields; no autonomous regulatory inference; disclose export consequences |

Wire identifiers are UUID strings; timestamps are RFC3339 UTC; media offsets are seconds from concatenated recorded audio. Swift emits UTC creation/consent timestamps with microsecond precision and explicitly parses RFC3339 fractional seconds for iPadOS 16 compatibility. Speech segment times retain fractional seconds. Errors distinguish unsupported capability, permission, integrity/validation, storage, cancellation, timeout, authorization and revision conflicts; UI strings are not a wire error contract.

MVP provides a local repository, native iOS capture/speech, JSON renderer and a read-policy evaluator. SecureStorage and production AccessPolicyManager/EnterpriseConnector implementations remain future enterprise work; the app holds no access tokens. The in-memory mock has no real security guarantees.
