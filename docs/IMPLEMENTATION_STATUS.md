# Implementation status — 2026-11-13

## TestFlight 0.1.4 (6) uploaded; speech fix pending device verification

A new 19.941s iPad recording has one intact CAF and first recognized words at 10.8s, excluding capture chunk boundaries as the cause. Its SHA-256 and early audio signal were verified, and a local AVAudioFile slice preserved all frames and the opening waveform. The prior recognition operation canceled on its first final result. It now accumulates final utterances through `SFSpeechRecognitionTaskDelegate` and waits for the whole task to finish; two new tests cover retained and deduplicated words. Eighteen Swift tests, four protocol tests, the public-source scan and unsigned iOS build passed. Xcode Organizer created a signed 0.1.4 (6) archive and reported **App upload complete** for App Store Connect. Processing/tester availability and physical recovery of opening words remain unverified; existing audio is preserved for retranscription.

## Opening transcription gap to diagnose

Two separate iPad exports first show recognized words at 30.96s and 25.65s, despite having first audio chunks of about 60s that also contain later recognized words. The JSON includes both chunk metadata entries and transcript segments from both chunks; it does not include audio bytes. Source code retains all completed `.caf` files per meeting with no two-chunk cap; only temporary speech slices are deleted. After Developer Mode was enabled, both original first CAF files were found and copied from the iPad. Their SHA-256 hashes match JSON and signal levels are substantial from the opening seconds. The user supplied manual transcripts of audible speech starting around 1s in both recordings; this content is absent from JSON. The gap arises in recognition output, before export; the precise Apple Speech cause remains unknown. Local 40-second listening copies are in `/private/tmp/opms-audio-diagnosis/`, outside the repository. Resolve recognition loss before text cleanup or brand analysis.

## TestFlight release 0.1.3 (5)

Both marketing version and build number were increased and the generated Xcode project updated. Verification passed: 16 Swift tests, 4 protocol tests, public-source scan, plist lint, and unsigned generic iOS build. Xcode Organizer created a signed 0.1.3 (5) archive and showed **App upload complete**. The archive's `Info.plist` has `ITSAppUsesNonExemptEncryption = false`. App Store Connect processing, tester availability and physical-device validation of the updated UI remain unverified. Remove Xcode's temporary signing team from generated source before commit.

## Transcript reading layout in 0.1.3 (5)

The user supplied an iPad screenshot and JSON showing successful Russian on-device recognition after enabling Siri: 75 seconds, two audio chunks, 83 word segments. Moved the export explanation/action above the transcript and added paragraph presentation at pauses of at least 0.8 seconds; raw JSON segments and timing are unchanged.

## Siri settings guidance in 0.1.3 (5)

After confirming that Dictation was enabled but Siri was off on the iPad, updated English/Russian UI guidance to point directly to Siri settings and then Dictation. The app already requests Speech authorization; iPadOS does not provide an app API to enable Siri or open its system settings directly. The user confirmed recognition works after enabling Siri.

## Export compliance metadata in 0.1.3 (5)

Added `ITSAppUsesNonExemptEncryption = NO` to the app's explicit `Info.plist`. Current code uses CryptoKit SHA-256 for integrity and Apple OS file protection, with no custom encryption. The uploaded archive contains this declaration. Recheck it if cryptography or dependencies change.

## iPad speech restriction and release 0.1.2 (4)

The user confirmed that TestFlight 0.1.1 (3) recorded and finalized an approximately 8-second, one-chunk meeting on iPad 10. Transcription returned `kLSRErrorDomain` code 201: Apple Speech reports Siri or Dictation disabled. The app cannot change device or MDM restrictions. The new `SpeechFailure` classifier and localized UI give actionable guidance for code 201 and missing assets (102), default recognition to Russian, and make the offline notice and transcription button more visible. Russian and English localization resources are packaged in signed 0.1.2 (4); Xcode Organizer showed **App upload complete** and **Uploaded to Apple** on 2026-11-13. App Store Connect processing, tester availability and speech success on the managed iPad remain unverified. The user removed the simulator data.

## TestFlight build 0.1.1 (3)

Xcode Organizer showed **Uploaded to Apple** on 2026-11-13 for a signed 0.1.1 (3) archive containing the capture startup fix. The user later installed and tested it on iPad 10; capture worked, speech did not because Siri or Dictation is disabled. Both the marketing version and build number were increased in the project generator and generated Xcode project; AGENTS.md and CONTRIBUTING.md now require this for every new TestFlight archive.

## iPad recording startup fix

On 2026-11-13, two iPad 10 screenshots showed recording startup failing with a missing `.caf` file. Root cause: file protection was applied before `AVAudioRecorder` created the file. `beginChunk()` now calls `prepareToRecord()` first. Local verification passed: 12 Swift tests, 4 protocol tests, public-source scan and unsigned generic iOS build. Device retest is pending; check GitHub separately for source publication. The affected interrupted records have no audio to recover.

## TestFlight upload

Xcode Organizer reported “App upload complete” for version 0.1.0 (2) on 2026-11-10. App Store Connect processing and tester availability remain unverified. The first upload, 0.1.0 (1), failed on missing app icon metadata and iPad icon. The project now includes an asset catalog with required iPad icons, `CFBundleIconName=AppIcon`, and generator support for the icon resources. A fresh unsigned Release archive succeeded and contained a 152×152 iPad icon. Physical iPad validation remains pending.

Current state supersedes pre-publication observations in the historical design/plan. Read PROJECT_CONTEXT.md for the full handoff.

## Published baseline

Repository: https://github.com/grandaxine/open-pharma-meeting — public, owner `grandaxine`, branch `main`.

Last verified published `main` before the 0.1.2 changes: `8f9d0b45602eb0a9ae5ceb3f52eccc8ae3cfea87` (`fix: prepare audio capture for TestFlight 0.1.1`), checked with `git ls-remote` on 2026-11-13. Check the remote for later commits.

Initial commit: `777338b6e2105b58a02a42db575c970d1931b9ef` — `feat: initialize open pharma meeting platform`.

CI for 0.1.1: https://github.com/grandaxine/open-pharma-meeting/actions/runs/43377484557 — **completed / success**, confirmed through GitHub connector after the push. Swift tests, native-export schema validation, protocol checks, source scan, reproducibility check and unsigned iPad build all passed.

## Milestone progress

| Deliverable | Status |
| --- | --- |
| Actual Xcode project and native iPad application | Implemented; generic iOS build passed |
| Six module boundaries and seven cross-platform contracts | Implemented; some enterprise contracts are interfaces only |
| Audio capture/pause/resume/chunks/journal/recovery | Source implemented; physical-device acceptance outstanding |
| Local on-device transcription/timestamps/timeout/cancellation | Source implemented; actual Speech/device acceptance outstanding |
| Local storage, validated models, JSON import/export | Implemented with host coverage; fault-injection coverage incomplete |
| Ten public schemas, fixtures and OpenAPI draft 0.1 | Implemented; structural tests and native-export validation passed |
| Corporate testing without AI service | In-memory mock implemented; deployable HTTP backend is milestone 2 |
| Governance/security/license/Android roadmap/CI | Present; Apache-2.0; no third-party runtime packages |
| Public-source readiness and publication | Initial baseline and icon fix pushed to `main`; supplied archive/prototype and local `Tmp/` exports excluded |
| Hardware validation / full Milestone 1 acceptance | Pending; see VALIDATION.md |

## Verification and review record

12 XCTest cases and 4 Python protocol tests passed locally and CI passed. A Swift-produced Meeting export passed independent JSON Schema validation. The independent implementation review identified four important bugs: imported media-duration overflow, filename contract mismatch, timestamp truncation and mock mutation replay. Regression tests failed before fixes and passed afterward. Native runtime tests for capture lifecycle and Speech remain absent; compilation is not evidence of hardware reliability.

Original source was authored using public Apple API patterns; the supplied archive has no license/provenance statement and remains ignored. The repository uses deterministic native Xcode static-library targets, plus a Swift package for host tests. The originally proposed nested repository was superseded by the user-initialized OPMS root.

## Remaining work and known limits

Follow docs/VALIDATION.md for both target iPads, offline locales, long/locked/background recordings, rotation gaps, interruptions, low disk, crash recovery and privacy checks. No gapless recording, reliable locked-device recording, secure flash erasure or regulatory certification is claimed.

Production identity, Keychain-backed SecureStorage, tenant authorization, deployed corporate backend, executable HTTP conformance, enterprise report synchronization, retention/MDM automation and pharmaceutical safety review workflows remain subsequent milestones. No production upload or credential collection is enabled.

## Continuity update

Project memory is stored in AGENTS.md and docs/PROJECT_CONTEXT.md. The 2026-11-10 icon fix and TestFlight upload record were published in `0c09216`; this later status refresh is local until committed and pushed. Inspect Git status and the remote branch before claiming it published. Git staging required sandbox escalation, after which commit and push succeeded. The local `Tmp/meeting.json` export must remain private and is covered by `.gitignore`.
