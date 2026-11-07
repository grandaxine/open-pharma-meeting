# Starter source review — 2026-11-07

Inspected all nine files in `OpenPharmaMeeting_iPad_Source_v1.zip` and the extracted `MeetingTranscriber-iPad` directory. This is a source review, not a completed public-source clearance or runtime validation.

## Reuse assessment

- MeetingRecorder: reuse the AVAudioRecorder approach, permission request, mono AAC configuration and pause/resume. Replace wall-clock duration with recorded-media duration; explicitly apply Data Protection, handle interruptions and persist recording lifecycle before capture starts. A single M4A is vulnerable to termination before finalization; use bounded independently finalized chunks with a recoverable manifest.
- OfflineTranscriber: retain capability checks and mandatory `requiresOnDeviceRecognition = true`. Preserve timestamped Speech segments with chunk offsets. Add cancellation, timeout, exactly-once continuation completion and protected temporary files. Unsupported locales fail closed. Forty-five-second slices need physical-device accuracy and endurance tests.
- MeetingStore: replace unversioned flat models and silent load failures. Keep atomic writes and backup exclusion, but propagate protection/backup errors, retain corrupt records for recovery and expose diagnostics without content. Store in Application Support rather than user Documents.
- ContentView: reuse general split-view navigation and explicit recording controls. Require participant-consent acknowledgment before recording; prevent deletion/export of active capture; expose recovery and permission failures. Remove arbitrary gateway and bearer-token input from MVP.
- CorporateAPI: do not adopt the ad hoc synchronous text API. Replace with a model-agnostic EnterpriseConnector contract; no production networking in milestone 1.
- Info.plist/project.yml: retain iPad family, iPadOS 16 minimum and permission descriptions. Commit an actual Xcode project; avoid a mandatory XcodeGen dependency.

## Provenance and publication

Archive has no LICENSE or authorship/assignment statement. User supplied code is not proof of redistribution rights. Prefer an original implementation informed by public Apple interfaces; do not copy starter source into the public repository until provenance is established. Archive and extracted prototype stay outside the new publishable repository.

No credentials or private meeting content were apparent in the inspected source; placeholder gateway and bundle identifiers are present. This does not replace a full staged-file/history scan. No third-party dependencies are declared. Apple SDKs are platform dependencies, not redistributed project code. Apache-2.0 is preferred for original project code, with full license text and a third-party inventory before release.

## Tooling observations

Xcode 26.5 and Swift 6.3.2 are installed. XcodeGen is absent. The supplied starter has no generated .xcodeproj and no tests, so no successful build has been demonstrated. GitHub CLI reports invalid authentication for `grandaxine`; ownership is not verified and no remote has been created.
