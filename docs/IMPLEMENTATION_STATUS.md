# Implementation status — 2026-11-14

## Selectable local text models: implementation underway

On `fix/direct-address-identifiers`, Qwen and ggml-org Gemma 3 1B Q4_K_M now have separate SHA-256 pinned import slots and a persisted active selection. The UI shows model names, source links and app version; import/inference errors are classified and positioned near actions, and the review sheet keeps its error visible above the transcript. Model-specific Qwen/Gemma prompts target doctor/patient names, preserve brands and standalone street names, and use the appropriate chat framing. Deterministic rules cover an explicitly linked full personal address. Added host tests for prompt framing, name propagation and street-name preservation. The existing 0.1.7 (9) version bump was prepared during the prior TestFlight work; this task has **not** created another archive or upload. Apple Speech is unchanged. Host verification: 45 Swift tests, four protocol tests via Python 3.13, source scan and unsigned generic iOS build passed. Gemma performance, recall and license implications for any future redistribution remain device/release gates.

## Unreleased local lexicons for brand and spoken-name hints

The user supplied 28 Novartis brand rows. `BrandLexicon` now records each Latin brand (including paired names) and provisional Russian speech spellings; `NameLexicon` seeds 24 common given names, 12 patronymic alias groups and three spoken name–patronymic groups including joined forms. Only aliases actually found in each transcript window are sent as hints to the on-device model. The lexicons are not blanket privacy or brand whitelists: explicit doctor context still masks a word that is also a listed brand. Greeting-based replacement now links known spaced and joined variants to one placeholder. Russian spellings are heuristic and require review against real ASR output and approved product references; no external dictionary was copied or new dependency added. This is on `fix/direct-address-identifiers`, **not in TestFlight**. Verification: 38 Swift tests, 4 protocol tests, source scan (0 findings), generic iOS build. iPad quality tests remain pending.

## Post-0.1.6 iPad finding: direct address missed

The user tested 0.1.6 (8) on iPad 10. The review screen showed two replacements of a representative's name but retained both occurrences of a colloquial doctor address in the proposed export text. The latest meeting JSON was copied read-only from the paired iPad into `/private/tmp/opms-deid-diagnosis/`; its transcript has 69 segments, one preserved audio chunk, and both address occurrences. No audio was copied or changed. In branch `fix/direct-address-identifiers`, a deterministic greeting-name rule now replaces repeated whole-word occurrences while exempting explicit drug/brand context. The final approval scan also blocks a reintroduced greeting name. Two regression tests reproduce the failure and brand collision. All 32 Swift tests, 4 protocol tests, source scan and generic iOS build pass. **This fix has not been archived or uploaded**; 0.1.6 remains unsafe for unattended export. Do not treat the rules or model as a guarantee of de-identification. Future locally versioned name/brand dictionaries need approved source data and collision tests before inclusion.

## TestFlight 0.1.6 (8): trial fixes uploaded

The post-upload review of 0.1.5 found that a repeated person name could also mask an identically named drug, model import and 610 MB hash verification blocked the UI, and closing review did not release its detector promptly. Build 0.1.6 filters model quotes at whole-term boundaries and in drug/brand context, moves model import and hashing off the main actor with cancellation, and cancels final approval/relinquishes the detector when review closes. The signed archive contains version 0.1.6 (8), `ITSAppUsesNonExemptEncryption = false`, and a matching llama framework dSYM. Xcode Organizer reported **App upload complete** and **Uploaded to Apple** at 19:20 on 2026-11-13. Verification: 30 Swift tests, 4 protocol tests, source scan (0 findings), plist lint, generic iOS build, and signed archive. App Store Connect processing, tester availability, model behavior and memory use on iPad 9/10 remain unverified. The local model remains experimental; human review is required before any text export.

## TestFlight 0.1.5 (7): experimental local text de-identification

The user requested TestFlight before multi-iPad testing. The isolated `feat/local-deidentification` branch now has local GGUF import with pinned SHA-256, a source-built iOS 16.0 llama.cpp framework, on-device identity detection, a review sheet, a second local check, and explicit `.txt` export containing only approved text. Raw meeting JSON remains a separate, clearly labeled manual export. The official Qwen3-0.6B-Q8_0 weights are not bundled; import them through Files. Version 0.1.5 (7) and the framework's iOS 16.0 floor were verified in the signed archive. Xcode Organizer reported **Uploaded to Apple** at 19:08 on 2026-11-13. Upload warned that the llama framework dSYM was missing, limiting crash symbolication. App Store Connect processing and tester availability remain unverified. The model produced overbroad and invented spans in a synthetic Mac trial; those outputs fail closed, but name recall and brand preservation on iPad 9/10 remain unvalidated. Do not use real sensitive conversations or claim anonymity/compliance until device-quality testing and human review establish suitability. Verification: 29 Swift tests, 4 protocol tests, public-source scan, plist lint, unsigned generic iOS build, and signed archive. No cloud analysis connector is enabled.

## TestFlight 0.1.4 (6): opening speech restored in user retest

A 19.941s iPad recording had one intact CAF but first recognized words at 10.8s, excluding capture chunk boundaries as the cause. Its SHA-256 and early audio signal were verified, and a local AVAudioFile slice preserved all frames and the opening waveform. The prior recognition operation canceled on its first final result. It now accumulates final utterances through `SFSpeechRecognitionTaskDelegate` and waits for the whole task to finish; two new tests cover retained and deduplicated words. Eighteen Swift tests, four protocol tests, the public-source scan and unsigned iOS build passed. Xcode Organizer reported **App upload complete** for signed 0.1.4 (6). The user subsequently confirmed recognition starts at the beginning on iPad. No new JSON was compared and broader physical acceptance remains outstanding; existing audio is preserved for retranscription.

## Earlier opening transcription gap

Two separate iPad exports first show recognized words at 30.96s and 25.65s, despite having first audio chunks of about 60s that also contain later recognized words. The JSON includes both chunk metadata entries and transcript segments from both chunks; it does not include audio bytes. Source code retains all completed `.caf` files per meeting with no two-chunk cap; only temporary speech slices are deleted. After Developer Mode was enabled, both original first CAF files were found and copied from the iPad. Their SHA-256 hashes match JSON and signal levels are substantial from the opening seconds. The user supplied manual transcripts of audible speech starting around 1s in both recordings; this content is absent from JSON. The gap arose in recognition output, before export. The user reported recognition from the beginning after the 0.1.4 (6) Speech completion change; the precise Apple Speech behavior in the earlier build remains unknown. Local 40-second listening copies are in `/private/tmp/opms-audio-diagnosis/`, outside the repository.

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
