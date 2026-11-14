# Validation record and remaining work

## Local text de-identification feasibility

On 2026-11-13, only a physical iPad 10/A14 running iPadOS 27.2.1 was connected; iPad 9/A13 was unavailable. The first synthetic CPU inference exposed overbroad and invented spans. TestFlight 0.1.8 subsequently imported Gemma on iPad 10, but its output failed local validation; Qwen opened review on the same meeting, while the user reports substantial name misses. Offline inference, 1,000-word latency, memory, thermal, cancellation, and brand-preservation measurements across both devices remain incomplete. Export remains behind model parsing, human review and a second local scan; these checks do not establish real-world de-identification quality or production readiness.

## Field evaluation of names — current TestFlight 0.1.8

The user reports that Qwen misses many names in iPad trials; Gemma can reject the same meeting before review. Neither model has demonstrated adequate de-identification. The updated target is **all people's names**, regardless of role, while retaining brands, drugs, companies, medical terms, institutions and standalone street names. TestFlight 0.1.8 still uses the earlier doctor/patient prompt, so representative-name misses must be counted rather than treated as acceptable.

For each permitted local trial, record the device model/iPadOS, active GGUF, language, audio duration, transcription completeness, and whether a review sheet opens. Compare the raw transcript and proposed text **on the iPad**. Count each occurrence of a given name, surname or patronymic in the source and each occurrence left visible in the proposed text. Separately count brands, drug names, company names and other non-person names incorrectly replaced. Note unusual speech forms (joined patronymics, misrecognized names) by category without copying the actual identifier into a shared report. Repeat at least one scenario on iPad 9 and iPad 10 and include short and longer dialogues.

Suggested privacy-safe tally: `trial-01 | iPad 10 | Qwen | 82 s | 6 name occurrences | 3 missed | 1 brand masked | review opened`. Keep source audio and JSON local; do not upload raw meeting JSON or automatically approved text to a cloud service while known name misses remain. The model's final local check is not proof that all names were removed. Use these counts to select the next extraction design and regression cases.

Development environment: macOS, Xcode 26.5, Swift 6.3.2. Actual current command results are recorded in docs/IMPLEMENTATION_STATUS.md at handoff. CI definitions are not evidence that GitHub CI has run.

## Physical-device acceptance — not yet performed

Run on both iPad 9/A13 and iPad 10/A14 with iPadOS 16+ (include minimum supported OS and currently deployed company OS versions):

- Microphone and Speech permission denied/revoked; consent cancellation; visible recording state.
- On supervised iPads, check whether Siri or Dictation is disabled by device settings or MDM (`kLSRErrorDomain` 201), whether language assets are missing (102), and whether the app gives actionable guidance without losing audio.
- Airplane-mode capture and transcription with supported installed locales; unsupported locale fails without outbound traffic.
- 5-minute, 1-hour and multi-hour recordings; pause/resume; measured rotation gaps; recorded-media timestamp alignment and word accuracy at boundaries.
- Background/lock, competing audio session/interruption, route changes, app termination, relaunch recovery and unreadable final CAF. Never automatically restart microphone capture.
- Low disk before start/during capture, file-write failure, memory pressure, thermal/battery load, large import limits and cancellation/timeout under stress.
- Hash mismatch, missing audio, corrupt metadata, symlink/path traversal attempts, stale journal and duplicate IDs.
- Data Protection before/after lock, backup exclusion, speech temp cleanup after termination, sharing/MDM boundaries and device retention policy.
- Accessibility, orientation, large text, explicit JSON export/import, deletion, selection changes during capture/transcription.

## Known limits

No live transcription, diarization, sample-perfect gapless rotation, configurable retention, guaranteed background recording, imported audio archive, production identity, remote backend authorization, regulated workflow or enterprise report-sync UI is implemented. Journal protection may stop capture on lock. This is acceptable only as a documented pre-production limitation pending device validation and revised capture strategy.

Only positive schema fixtures plus selected invalid mutations are automated today. Expand semantic/fuzz/native lifecycle tests and executable HTTP conformance before claiming enterprise compatibility. The in-memory mock is deterministic and model-free, not a deployed backend.
