# Validation record and remaining work

Development environment: macOS, Xcode 26.5, Swift 6.3.2. Actual current command results are recorded in docs/IMPLEMENTATION_STATUS.md at handoff. CI definitions are not evidence that GitHub CI has run.

## Physical-device acceptance — not yet performed

Run on both iPad 9/A13 and iPad 10/A14 with iPadOS 16+ (include minimum supported OS and currently deployed company OS versions):

- Microphone and Speech permission denied/revoked; consent cancellation; visible recording state.
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
