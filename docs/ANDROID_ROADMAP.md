# Android roadmap

Add a native Android application without rewriting the iOS application or changing protocol 0.1. Start in `android/` when implementation is authorized; none is included in the iOS milestone.

1. Kotlin and Jetpack Compose provide UI, lifecycle and accessibility. Map the seven contracts in PLATFORM_CONTRACTS.md to suspend functions/Flow with structured cancellation.
2. AudioRecorder uses Android native audio APIs with explicit microphone consent, foreground recording service where required, bounded files and a durable journal. Measure format/codec support, timing, interruption and battery behavior on an agreed hardware/API baseline. CAF is the iOS MVP capture format; negotiate future portable audio formats before cross-device audio exchange. Audio is not uploaded by default.
3. Choose an on-device speech adapter based on Android capability checks and company policy. RecognitionService/other approved local engines may differ from Apple Speech. Unsupported locales fail closed; never force a shared engine or hosted provider for code reuse.
4. Implement MeetingRepository with app-private encrypted/device-protected policy as approved by company security, atomic operations and the same JSON payloads. Use Keystore-backed credential storage and explicit backup exclusions; validate locked-device behavior.
5. Generate or hand-map Kotlin models from the committed schemas and run the same positive/negative fixtures and semantic tests. Verify unknown namespaced extensions survive round trips. Coordinate new audio media types through a versioned protocol amendment, not platform-specific meeting/report schemas.
6. Implement OIDC authorization code + PKCE S256 with native browser integration, company discovery, TLS validation and the same asynchronous job/report/policy semantics. Tenant authorization remains server-side.
7. Run mobile security review, offline/long-recording/recovery tests and enterprise device management validation. Android release readiness is independent of iOS readiness.

Optional Kotlin Multiplatform is limited to proven shared business-rule value after both native implementations exist. Do not move native audio, speech or credential behavior into a common engine solely for code reuse. The shared interoperability layer remains language-independent JSON Schema, OpenAPI and conformance fixtures.
