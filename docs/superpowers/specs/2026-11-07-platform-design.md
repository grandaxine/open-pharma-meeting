# Open Pharma Meeting — Milestone 1 design

## Intent and scope

Deliver an original native iPad recorder and local post-recording transcription application for iPad 9/A13 and iPad 10/A14, iPadOS 16+. A company must never depend on maintainer-operated infrastructure. SwiftUI, AVFoundation and Apple Speech are the initial implementation; no Apple Intelligence, Flutter, KMP or hosted AI. Future Android uses Kotlin/Compose and native recording with its own replaceable speech implementation.

The user supplied the scope and asked for immediate implementation. The implementation choices below are the engineer's proposed decisions.

## Repository and components

Create `open-pharma-meeting/` as a standalone publishable repository, excluding the starter archive and extracted prototype. Include an Xcode project plus a Swift package for testable module code. Six module boundaries: MeetingCaptureKit, TranscriptionKit, MeetingDataKit, EnterpriseConnectorKit, PrivacyPolicyKit and ReportKit. The app composes these; modules never depend on SwiftUI. Native framework implementations are conditionally compiled where host tests require it.

MeetingDataKit owns versioned Codable models and safe local storage. Capture persists a manifest before starting audio, writes bounded chunks, finalizes completed chunks and exposes interrupted records for explicit recovery. No automatic recording restart after interruption. Protect files with completeUnlessOpen where needed for locked recording; metadata uses complete protection. Exclude the storage directory and temporary speech audio from backup and fail visibly if protection cannot be configured. Check recording errors and available storage. Never claim recovery of an unfinished container that the OS cannot decode.

TranscriptionKit sequentially processes short audio fragments, requires on-device recognition, exposes language availability and timestamps relative to the concatenated media timeline. Pauses are excluded from that timeline. Permission failure, unsupported locales, cancellation, timeout and interrupted transcription preserve audio and the prior completed transcript. No network fallback. Languages and on-device asset availability must be validated on hardware.

The UI shows a meeting list, explicit consent acknowledgment, start/pause/resume/stop, recording status, language choice, local transcription progress and timestamped results. Export is explicit and labeled as disclosure outside app protection. Recovery lists incomplete recordings. No telemetry, analytics, external upload, arbitrary endpoint UI or token field in MVP.

## Platform-independent interfaces

Document language-neutral contracts and matching Swift protocols:

- AudioRecorder: start(meetingID, configuration), pause, resume, stop -> RecordingMetadata; state/errors and chunk integrity events.
- TranscriptionEngine: capabilities(locale), transcribe(recording, locale, cancellation, progress) -> Transcript.
- MeetingRepository: list, get, save, delete, import/export and recover; atomic writes, bounded input validation and no path traversal.
- SecureStorage: put/get/delete opaque credentials, with native Keychain later and Android Keystore-backed implementation later; never credentials in meeting JSON.
- EnterpriseConnector: discover, authenticate, submit transcript, create job, poll status, retrieve results, sync reports, update access policies. MVP includes interfaces only; corporate networking belongs to later milestones.
- AccessPolicyManager: evaluate a resource action against explicit identity/policy and request server policy revision. Private is default; unknown identity fails closed. Local policy is defense in depth, never server authorization.
- ReportRenderer: render a typed ReportArtifact to a selected export format without making regulatory decisions.

## Open Pharma Meeting Protocol 0.1

Draft JSON Schema 2020-12 definitions for Meeting, Transcript, TranscriptSegment, RecordingMetadata, AccessPolicy, ProcessingJob, ProcessingResult, ReportArtifact, AuditEvent and ConnectorCapabilities. Stable UUID identifiers, RFC3339 UTC timestamps, explicit schemaVersion, locale tags and seconds-based media offsets. Optional namespaced extensions preserve unknown fields through import/export; unsupported major versions are rejected. Validate required types, finite nonnegative times, ordered ranges, references and payload limits. Make clear which checks are schema constraints and which require semantic validation.

Draft OpenAPI 3.1 defines company-owned discovery, OIDC/PKCE integration metadata, transcript submission, asynchronous jobs, status/result retrieval, report synchronization and policy revisions. No maintainer URL or default server. Mutation requests use scoped idempotency keys; same key/different body conflicts. Define 202/Location/Retry-After, terminal states, errors, tenant scoping, pagination and optimistic concurrency. No audio upload by default. Publish fixtures and language-independent conformance expectations; a functioning mock backend and HTTP conformance harness are milestone 2 unless inexpensive fixtures suffice for milestone 1.

## Security and governance

Independent Private/Restricted/Organization policies for audio, raw transcript and reports. Corporate backends derive tenant and subject from authenticated identity and enforce every read/write and processing action. Policy revisions require server authorization and audit. Revocation cannot erase previously downloaded/exported data: company MDM, retention, remote wipe and device policy remain necessary. Do not imply private device files have multi-user isolation beyond OS controls.

Document OWASP MASVS as a baseline, with a mapping and unverified controls; no certification claims. OAuth/OIDC PKCE, TLS, Keychain credentials, residency, model/prompt governance, retention and approval workflows are enterprise responsibilities to implement in later milestones. Pharmaceutical extension payloads support medical information, complaints, potential adverse events, compliance, field documentation and training. Safety-relevant outputs require human review and company-defined escalation; no autonomous regulatory classifications or decisions.

Prepare README, ARCHITECTURE, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, GOVERNANCE, Android roadmap, compatibility guidance, license inventory, CI and release checklist. Apache-2.0 for original code; do not copy starter source absent provenance. No runtime third-party dependencies initially. Review every publishable file and Git history for secrets, private data and restricted code before public creation. Confirm authenticated owner and publication authorization before publication.

## Validation and acceptance

Test model round trips, privacy defaults, malformed/future contracts, repository atomicity/path safety/recovery and transcript chunk offsets. Build the actual iPad target without code signing on macOS; host package tests plus schema fixture validation in CI. Record actual command outcomes, never infer passing CI from a workflow file.

Hardware validation remains mandatory: both target iPads, airplane mode, supported/unsupported locales, locked/background recording, interruptions, low disk, termination/relaunch recovery, long recordings, thermal/battery behavior, protection/backup checks and transcription accuracy at chunk boundaries. Remaining milestones must be labeled unimplemented rather than represented as production features.

## Builder review resolutions

The builder review found no additional product decisions needed. Engineer-selected defaults: rotate capture into 60-second files; measure and disclose rotation gaps rather than promise gapless recording. Speech tasks use at most 45 seconds and a 90-second timeout. Set a 100 MiB JSON import limit and a 250 MiB free-space reserve before starting or rotating capture, with an explicit stop/error when the reserve is crossed. These are initial testable safety limits, not hardware performance claims.

An active journal uses completeUnlessOpen-compatible protection; finalized metadata is strengthened to complete protection when possible. Reopening protected files while locked may fail and must stop capture visibly without losing completed chunks. Locked recording remains a physical-device acceptance gate, not a promised capability based on the protection flag alone.

Forward compatibility guarantees preservation of namespaced `extensions` only. Unknown ordinary fields may be ignored by consumers and are not guaranteed round-trip preservation; producers must place portable additions inside extensions. Unknown major versions fail closed. A mock backend and executable HTTP conformance suite are milestone 2; milestone 1 supplies their contracts and fixture requirements.
