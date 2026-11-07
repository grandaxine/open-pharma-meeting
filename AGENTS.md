# Project continuity

Read `docs/PROJECT_CONTEXT.md` and `docs/IMPLEMENTATION_STATUS.md` before starting work. They record the current architecture, verified publication/CI, known limitations and next steps. Update both when material progress changes. The initial plan/design under `docs/superpowers/` is historical; current implementation status supersedes outdated plan assumptions.

## Non-negotiable constraints

- Native-first: Swift/SwiftUI/AVFoundation/Apple Speech on iPadOS 16+; Kotlin/Compose/native adapters for future Android. No Flutter, Apple Intelligence or KMP in the iOS MVP.
- No maintainer-operated central service, telemetry, remote speech fallback or default third-party data submission. Private policies independently protect audio, transcript and reports.
- Public contracts live in `protocol/0.1/`; preserve namespaced extensions. Companies own identity, authorization, AI/prompt governance, residency, retention and human review/escalation.
- No autonomous regulatory decisions or unsupported certification claims.
- Do not publish supplied starter source/archive: provenance is unestablished and both are ignored. Current implementation is original. No new dependency without license/provenance/security review.

## Repository and verification

- Public repository: `https://github.com/grandaxine/open-pharma-meeting`, owner `grandaxine`, default branch `main`.
- Six Swift modules have native static-library Xcode targets and a matching Swift package. Regenerate project with `python3 scripts/generate_project.py` after adding/removing Swift files. Regenerate protocol with `python3 scripts/generate_protocol.py` when its generator changes; commit generator and outputs together.
- Run `swift test`, `python3 scripts/test_protocol.py`, `python3 scripts/check_public_source.py` and the generic iOS build from README. Python protocol tests require `requirements-dev.txt`.
- Successful compilation/CI is not physical-device validation. Keep outstanding iPad 9/10 tests and enterprise functionality explicit.
- Some Codex environments deny `.git` writes and CLI networking/keychain even when the user's Terminal works. Use the GitHub connector for read verification when available; report actual blockers. Never claim a commit/push from local edits alone or access tokens through chat.
