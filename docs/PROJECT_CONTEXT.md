# Project memory — Open Pharma Meeting

Last updated: 2026-11-07. This file is the handoff for future sessions; no hidden conversational memory is required.

## Mission and accepted direction

Open-source, vendor-neutral, privacy-first meeting intelligence for pharmaceutical companies. Each company owns infrastructure, recordings, transcripts, processing rules, AI models, identity, retention and compliance workflows. No maintainer-operated central service is required. Native-first architecture with shared language-independent contracts; initial scope is Milestone 1 for iPad 9/A13 and iPad 10/A14, iPadOS 16+.

The user supplied a detailed specification, approved proceeding after design/planning, configured Git/GitHub in their own Terminal and pushed the initial implementation. Continue autonomous authorized implementation where possible; do not repeatedly ask for routine confirmations. Communicate with the user in Russian unless they switch language.

## Confirmed publication and evidence

- Public repository/owner: https://github.com/grandaxine/open-pharma-meeting (`grandaxine`).
- Initial commit: `777338b6e2105b58a02a42db575c970d1931b9ef` — `feat: initialize open pharma meeting platform`.
- GitHub Actions run: https://github.com/grandaxine/open-pharma-meeting/actions/runs/42345635063 — **completed / success**, confirmed through GitHub connector after the user pushed.
- CI covers 12 XCTest cases, native-export JSON Schema validation, 4 Python protocol tests, candidate source scan, generated artifact reproducibility and unsigned generic iOS build. No simulator UI or hardware execution was demonstrated.
- Local development used Xcode 26.5/Swift 6.3.2. Initial published tree has 66 files; starter archive/prototype/audio files were absent. Repository was clean immediately after the user's initial push. This memory update introduces new local documentation changes; inspect Git status before claiming them committed.

## Implementation map

- `App/OpenPharmaMeetingApp.swift`: SwiftUI split-view meeting list, explicit consent, language, record/pause/resume/stop, transcription/cancel, recovery and JSON import/export. No production network UI.
- `Sources/MeetingCaptureKit`: native AVAudioRecorder, 16 kHz mono 16-bit PCM CAF, approximately 60-second finalized chunks, journal, interruption stop, storage reserve, SHA-256 corruption checks and explicit pending-file recovery.
- `Sources/TranscriptionKit`: Apple on-device Speech only; sequential <=45-second slices, timestamp offsets, 90-second request timeout, main-actor exactly-once completion/cancellation gate, protected temporary audio.
- `Sources/MeetingDataKit`: versioned Codable models, JSONValue extension preservation, semantic validation, explicit RFC3339 fractional-date codec, local atomic storage, backup exclusion, import limits and corruption reporting.
- `Sources/PrivacyPolicyKit`: independent Private/Restricted/Organization policies and local read evaluator. Private defaults; no real multi-user or server authorization.
- `Sources/EnterpriseConnectorKit`: seven-contract architecture includes EnterpriseConnector/SecureStorage interfaces; in-memory mock supports transcript/jobs/results/report/policy exercises with replay caches. No deployed HTTP backend or production OIDC/Keychain adapter.
- `Sources/ReportKit`: structured report artifacts and JSON renderer.
- `protocol/0.1`: ten schemas, fixtures, OpenAPI 3.1 JSON and protocol semantics. `.invalid` schema identifiers are not services. API supports discovery, OIDC integration metadata, transcript submission, async jobs, results, reports, policy revisions and idempotency.
- `OpenPharmaMeeting.xcodeproj`: committed deterministic native static-library targets; `Package.swift` exposes the same modules for host tests. No third-party runtime dependencies. XcodeGen is unnecessary.
- `scripts/`: project/protocol generators, fixture validators and supplementary candidate-file scan. Test dependency: jsonschema 4.26.0.

## Decisions and important fixes

Use repository root OPMS, not the originally proposed nested repository. Native Xcode targets avoid local Swift package manifest-cache failures observed in the sandbox. Original source was authored instead of copying the unlicensed supplied prototype; prototype/archive remain local ignored references.

Independent review found and fixes addressed: imported duration overflow/UI integer trap, CAF filename validation mismatch, fractional timestamp loss and mock mutation replay bugs. Regression tests observed failures then passed. Current codec emits fractional UTC timestamps at microsecond precision; creation defaults use whole seconds. Namespaced extension values survive round trips; ordinary unknown fields need not. Current supported wire version is exactly 0.1.

Limits: JSON import <=100 MiB, total media <=24 hours, free-space reserve 250 MiB checked at start/rotation. Sequential CAF rotation may lose samples at boundaries; no gapless promise. Recorded-media time excludes pauses and gaps. SHA-256 detects corruption, not malicious manifest replacement.

## Security and unimplemented scope

No telemetry, default server, model provider, production upload, credentials or remote Speech fallback. Application Support storage is excluded from backup. Active journals/audio use completeUnlessOpen; finalized metadata and speech slices use complete protection. New opens/atomic rewrites can fail while locked, causing a safe interruption; reliable locked recording is not established. Process termination can leave protected speech temp files. Exports leave app protection; imported JSON does not restore audio.

Server-side tenant authorization, SSO/OIDC PKCE, actual Keychain adapter, retention/MDM integration, report sync UI and production corporate connector remain future work. The local evaluator/mock is not a security boundary. Revocation cannot recall already downloaded/exported copies. Pharmaceutical detections/escalations are optional future human-reviewed workflows, never autonomous regulatory decisions. No regulatory certification claimed.

## Next work, in order

1. Physical-device acceptance on both target iPads: consent/permissions, supported/unsupported locales in airplane mode, long recordings, rotation gaps, pause/resume, screen lock/background, interruptions/route changes, low storage, termination/relaunch recovery, audio integrity, transcription accuracy/cancellation/timeout, protection/backups and export behavior. Use `docs/VALIDATION.md` as checklist. Capture evidence before improving claims.
2. Expand automated capture lifecycle, Speech completion/cancellation, atomic-write failure, storage/retention and semantic validation coverage. Current host tests do not validate native microphone/Speech lifecycle.
3. Milestone 2: deployable company-owned HTTP mock/reference backend, actual bidirectional connector and executable HTTP/authorization conformance harness. In-memory simulator already exists; do not rebuild it as if absent.
4. Milestone 3: OIDC authorization code/PKCE S256, native credential implementation, server-enforced policies, report synchronization.
5. Milestone 4: pharmaceutical extension schemas/human escalation, expanded conformance, deployment guides. Android roadmap is `docs/ANDROID_ROADMAP.md`; native Kotlin implementation is future, without rewriting iOS or forcing the same speech engine.

## Environment gotchas

Workspace: `/Users/Gleam/Documents/OPMS`. User Terminal successfully authenticated `gh` with repo/workflow scopes and performed init/remote/commit/push. This agent environment previously denied `.git/config` and `.git/index.lock` writes and CLI DNS/keychain access. Do not ask for tokens. GitHub connector GET/fetch can verify repository and Actions despite CLI failures. Recheck capabilities rather than assume unchanged forever.

Local sandbox host-test invocation that worked:

```sh
OPMS_FIXTURE_PATH=/private/tmp/opms-native-fixture.json \
CLANG_MODULE_CACHE_PATH=/private/tmp/opms-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/opms-modules \
swift test --disable-sandbox --scratch-path /private/tmp/opms-build
```

Local Python with jsonschema was `/usr/local/bin/python3.13`; default `python3` lacked it. Prefer a task-local venv when needed. Generic iOS build used `/private/tmp/opms-derived` and `CODE_SIGNING_ALLOWED=NO`. CoreSimulator was unavailable; device-target compile still succeeded. See README for portable commands and CI workflow for hosted validation.
