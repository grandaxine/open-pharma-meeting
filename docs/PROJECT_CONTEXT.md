# Project memory — Open Pharma Meeting

Last updated: 2026-11-13. This file is the handoff for future sessions; no hidden conversational memory is required.

## TestFlight 0.1.4 (6) uploaded; speech fix pending iPad retest (2026-11-13)

A third, 19.941s iPad recording has one intact CAF file and its first recognized word at 10.8s. Its SHA-256 matches the stored metadata, with substantial signal from the first seconds; the gap is independent of 60s capture chunks and 45s recognition slicing. A local AVAudioFile reproduction produced a slice with all 319,050 frames and near-perfect correlation with the opening signal, further narrowing the loss to Speech results/handling. The old `RecognitionOperation` canceled its task on the first `isFinal` callback. It now uses `SFSpeechRecognitionTaskDelegate`, accumulates final utterances, and completes only after `didFinishSuccessfully`; unit tests cover accumulation and deduplication. Eighteen Swift tests, four protocol tests, the public-source scan and unsigned iOS build pass. Xcode Organizer created a signed 0.1.4 (6) archive and reported **App upload complete** for App Store Connect. Processing/tester availability and recovery of missing opening words on iPad are not yet verified. Existing recordings retain their audio and can be retranscribed in the new build.

## Repeated missing opening transcription (2026-11-13)

Two distinct iPad meeting exports have no recognized words before 30.96s (75.20s recording) and 25.65s (85.99s recording), respectively. Both have a 60-second first audio chunk and recognized words within it (56 and 57 segments); the second chunks also have words. This rules out JSON dropping the first chunk or an offset applied only at the second chunk. The JSON deliberately excludes audio. The recorder appends every completed `.caf` under the meeting's Application Support folder; transcription deletes only temporary speech slices, and there is no two-chunk retention limit. After the user enabled Developer Mode, `devicectl` listed both original first CAF files on the iPad and copied them to a private local temp folder. Both are 60.007s, 16 kHz mono PCM, and their SHA-256 hashes match the JSON. RMS levels in the first 25 seconds are comparable to later recognized sections; SoX VAD detects activity near the start. The user supplied manual opening transcripts with intelligible speech beginning around 1s in both recordings; those words are absent from the exported JSON. The loss is in recognition output, before JSON export, though the exact Apple Speech behavior remains undiagnosed. Address this before text cleanup or brand analysis. The raw audio on the iPad was not modified.

## TestFlight 0.1.3 (5) uploaded (2026-11-13)

After the user's request, both version fields were increased in `scripts/generate_project.py` and the Xcode project was regenerated. Local verification passed: 16 Swift tests, 4 Python protocol tests, public-source scan, plist lint, and unsigned generic iOS build. Xcode Organizer created a signed 0.1.3 (5) archive and reported **App upload complete** for App Store Connect. The archived app contains `ITSAppUsesNonExemptEncryption = false`; the export action is above the paragraph-style transcript and the Siri settings guidance is included. App Store Connect processing, tester availability, and physical-device validation of the new layout are not yet verified. The temporary Xcode signing team selection must not be committed to the generated project.

## Transcript reading layout (2026-11-13)

The user confirmed on-device Russian transcription now succeeds after enabling Siri. Their exported 75-second sample has 83 word segments and four inter-word pauses of at least 0.8 seconds. The meeting detail now places the JSON export action before the transcript and displays words as readable paragraphs split at pauses of 0.8 seconds or more. This is timing-based paragraphing, not speaker diarization; raw segment timing and JSON remain unchanged. This change is included in 0.1.3 (5).

## Siri settings guidance (2026-11-13)

The user confirmed Dictation was enabled but Siri was disabled on the iPad, and enabled Siri manually. The app already requests Speech authorization at transcription time. There is no supported app API to enable Siri or deep-link to its system settings; `UIApplication.openSettingsURLString` opens only the app's own settings. Updated English/Russian in-app guidance to lead with the Siri settings path, then Dictation, with an IT fallback for managed devices. This guidance is included in 0.1.3 (5); the user confirmed transcription works after enabling Siri.

## Export compliance declaration for next build (2026-11-13)

`App/Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO`, verified in the uploaded 0.1.3 (5) archive. Current app code uses CryptoKit SHA-256 integrity hashes and Apple OS file protection; it does not implement custom encryption. Apple says `NO` applies when an app uses no encryption or only encryption exempt from export documentation. Reassess the declaration if future dependencies or cryptographic features change.

## iPad speech restriction and localized UI (2026-11-13)

The user confirmed that TestFlight 0.1.1 (3) recorded and finalized an approximately 8-second, one-chunk meeting on the supervised iPad 10. Speech recognition then returned `kLSRErrorDomain` code 201, which Apple defines as Siri or Dictation disabled. This is a device setting or possible organization policy restriction; the app cannot override it without changing its on-device-only architecture. `SpeechFailure` now classifies codes 201 and 102, and the UI shows actionable guidance while preserving the audio. The app now includes Russian/English localization, defaults the new meeting recognition language to `ru-RU`, makes the offline/MDM notice clearer, and uses a prominent transcription button. Xcode Organizer showed **App upload complete** and **Uploaded to Apple** for signed 0.1.2 (4) on 2026-11-13; App Store Connect processing, tester availability and physical-device speech success remain unverified. The user removed the simulator data personally.

## TestFlight upload (2026-11-13)

Xcode Organizer created and uploaded Open Pharma Meeting 0.1.1 (3) with the capture startup fix; it showed **Uploaded to Apple** for build 3. The user later installed and tested this build on iPad 10. AGENTS.md and CONTRIBUTING.md require marketing version and build number increases before every new TestFlight archive. The initial `simctl erase` failed with a macOS permission error; the user later deleted the simulator data. Xcode's temporary team selection was removed from the generated project after upload. Check remote `main` separately before claiming source publication; an app upload is not a Git push.

## iPad capture startup failure (2026-11-13)

Two iPad 10 screenshots showed `NSCocoaErrorDomain Code=4` for a missing new `.caf` file when recording started. `NativeAudioRecorder.beginChunk()` set file protection immediately after constructing `AVAudioRecorder`, before the audio file existed. The recorder now calls `prepareToRecord()` before setting `completeUnlessOpen` protection, then starts capture. Apple documents that preparation creates the file. Local verification: 12 Swift tests, 4 protocol tests, public-source scan and unsigned generic iOS build passed. Physical-device retest is pending; the two interrupted meetings with missing CAF files contain no recoverable audio. The fix was included in the uploaded 0.1.1 (3) archive.

## TestFlight upload (2026-11-10)

Xcode Organizer reported **“App upload complete”** for Open Pharma Meeting 0.1.0 (2), bundle ID `org.openpharmameeting.OpenPharmaMeeting`, under Evgeniy Tikhonov's Apple Developer team. App Store Connect processing and tester availability were not verified. An earlier 0.1.0 (1) upload failed because the app lacked `CFBundleIconName` and a 152×152 iPad icon. The fix adds `App/Assets.xcassets/AppIcon.appiconset`, connects it in `scripts/generate_project.py`, and sets `CFBundleIconName` in `App/Info.plist`. A fresh unsigned Release archive succeeded locally; its built app contained `AppIcon76x76@2x~ipad.png` at 152×152 and `CFBundleIconName=AppIcon`. The signed archive and upload succeeded through Xcode UI. The Xcode project is generated and intentionally keeps no developer team, so select the team locally before a future upload. No physical-device acceptance has been completed.

## Mission and accepted direction

Open-source, vendor-neutral, privacy-first meeting intelligence for pharmaceutical companies. Each company owns infrastructure, recordings, transcripts, processing rules, AI models, identity, retention and compliance workflows. No maintainer-operated central service is required. Native-first architecture with shared language-independent contracts; initial scope is Milestone 1 for iPad 9/A13 and iPad 10/A14, iPadOS 16+.

The user supplied a detailed specification, approved proceeding after design/planning, configured Git/GitHub in their own Terminal and pushed the initial implementation. Continue autonomous authorized implementation where possible; do not repeatedly ask for routine confirmations. Communicate with the user in Russian unless they switch language.

## Confirmed publication and evidence

- Public repository/owner: https://github.com/grandaxine/open-pharma-meeting (`grandaxine`).
- Initial commit: `777338b6e2105b58a02a42db575c970d1931b9ef` — `feat: initialize open pharma meeting platform`.
- Last verified published `main` before the 0.1.2 changes, checked by `git ls-remote` on 2026-11-13: `8f9d0b45602eb0a9ae5ceb3f52eccc8ae3cfea87` — `fix: prepare audio capture for TestFlight 0.1.1`. Check the remote for later commits.
- GitHub Actions run for 0.1.1: https://github.com/grandaxine/open-pharma-meeting/actions/runs/43377484557 — **completed / success**, confirmed through GitHub connector after the push.
- CI covers 12 XCTest cases, native-export JSON Schema validation, 4 Python protocol tests, candidate source scan, generated artifact reproducibility and unsigned generic iOS build. No simulator UI or hardware execution was demonstrated.
- Local development used Xcode 26.5/Swift 6.3.2. The initial published tree had 66 files; starter archive/prototype/audio files were absent. Check Git status and the remote branch before claiming subsequent documentation edits published.

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

On 2026-11-10, `git add` required escalation for `.git/index.lock`; `git commit` and `git push origin main` then succeeded. `git ls-remote` confirmed the remote commit after escalation when sandbox DNS failed. `Tmp/meeting.json` is a local meeting export containing transcript/recording fields; `/Tmp/` is ignored and its contents must stay out of the public repository.

Local sandbox host-test invocation that worked:

```sh
OPMS_FIXTURE_PATH=/private/tmp/opms-native-fixture.json \
CLANG_MODULE_CACHE_PATH=/private/tmp/opms-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/opms-modules \
swift test --disable-sandbox --scratch-path /private/tmp/opms-build
```

Local Python with jsonschema was `/usr/local/bin/python3.13`; default `python3` lacked it. Prefer a task-local venv when needed. Generic iOS build used `/private/tmp/opms-derived` and `CODE_SIGNING_ALLOWED=NO`. CoreSimulator was unavailable; device-target compile still succeeded. See README for portable commands and CI workflow for hosted validation.
