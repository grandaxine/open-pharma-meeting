# Open Pharma Meeting

Native, local-first iPad meeting capture and on-device transcription, with an open protocol for company-owned processing. No maintainer-operated service, account, analytics or model provider is required.

**Status:** Milestone 1 implementation; not a validated pharmaceutical production system. Physical iPad 9/A13 and iPad 10/A14 acceptance testing remains outstanding. Protocol 0.1 is a draft.

## Run

Open `OpenPharmaMeeting.xcodeproj` in Xcode 15+ with an iOS 16+ SDK. Select the OpenPharmaMeeting scheme, choose a signing team and unique bundle identifier, then run on an iPad. No package download or XcodeGen is required. The committed project uses six native static-library targets; `Package.swift` exposes the same modules for host tests.

1. Obtain required participant consent, choose a language, and tap Record meeting.
2. Pause/resume or stop to finalize audio. Capture remains available without internet.
3. Choose Transcribe on this iPad. Apple Speech must support on-device recognition for the chosen language and have the needed assets. Unsupported configurations fail closed; no remote fallback.
4. Export JSON explicitly if needed. Export includes metadata and the transcript, not audio. Imported JSON does not import referenced audio files.
5. After a crash/relaunch, interrupted records remain visible; recover readable pending audio explicitly.

```sh
swift test
python3 -m pip install -r requirements-dev.txt
python3 scripts/test_protocol.py
python3 scripts/check_public_source.py
xcodebuild -project OpenPharmaMeeting.xcodeproj -scheme OpenPharmaMeeting \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/opms-derived \
  CODE_SIGNING_ALLOWED=NO build
```

## Included

- MeetingCaptureKit: native PCM/CAF chunk capture, pause/resume, interruption stop, journal, storage reserve and SHA-256 integrity checks.
- TranscriptionKit: replaceable engine protocol; sequential on-device Apple Speech with timestamps, timeout and cancellation.
- MeetingDataKit: versioned models, semantic validation, atomic local persistence, JSON import/export and interrupted-record discovery.
- PrivacyPolicyKit: independent Private/Restricted/Organization resource policies; Private by default.
- EnterpriseConnectorKit: company adapter contract and in-memory mock service simulator. No production networking or identity integration is enabled.
- ReportKit: extensible structured report model and JSON rendering.

[Architecture](ARCHITECTURE.md), [protocol](protocol/0.1/README.md), [OpenAPI](protocol/0.1/openapi.json), [schemas](protocol/0.1/schemas), [Android roadmap](docs/ANDROID_ROADMAP.md), [security](SECURITY.md), [validation](docs/VALIDATION.md), [compatibility](docs/COMPATIBILITY.md).

## Subsequent milestones

2. HTTP mock/reference backend, bidirectional integration and executable HTTP conformance suite.
3. Company-managed OIDC/PKCE, native Keychain-backed credential implementation, server-enforced policies and report synchronization.
4. Pharmaceutical review/escalation extensions, enterprise deployment guides and expanded conformance testing.

The included in-memory mock is a test aid, not an enterprise backend or an authorization implementation. No autonomous regulatory decisions or safety determinations are made. Model selection, prompts, versions, residency, retention, approvals and audit belong to the company backend.

## License and development

Apache-2.0 for original project code; see LICENSE and [third-party inventory](THIRD_PARTY_NOTICES.md). Supplied unlicensed starter files and archive are excluded from publication. See CONTRIBUTING.md, GOVERNANCE.md and CODE_OF_CONDUCT.md. No regulatory certification is asserted.
