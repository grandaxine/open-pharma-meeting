# Local Text De-identification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a reviewed, text-only analysis artifact on iPad without transmitting audio, raw transcript, or identifying details of a physician or patient.

**Architecture:** `PrivacyPolicyKit` owns a platform-independent span detector contract, deterministic checks, span merging, and an outbound artifact type. An iOS-only adapter runs a small language model locally; the SwiftUI app presents redactions and exports only after review and a second local check. The company cloud connector and visit-analysis prompts are a separate project and remain disabled here.

**Tech Stack:** Swift 5.9, SwiftUI, Foundation, iPadOS 16+, existing Apple Speech transcript; candidate official Qwen3-0.6B-Q8_0 GGUF and `llama.cpp` iOS runtime, subject to Task 1 gates.

**Spec:** `docs/superpowers/specs/2026-11-13-local-text-deidentification-design.md`

## Global Constraints

- All detection, model inference, review, and draft storage run on the iPad; no remote inference, telemetry, or fallback.
- Audio stays local; only an explicitly approved text artifact can leave this workflow.
- Remove physician/patient identity cues while preserving drug names, company and competitor brands, medical terms, objections, claims, and other non-identifying visit content.
- Preserve the existing `protocol/0.1/` wire contract; a later connector needs its own versioned analysis-artifact contract and company authorization.
- Keep the six-module layout and iPadOS 16 floor. Do not add a runtime or model until license, provenance, and security review. Do not put model binaries or real meeting data in public Git.
- Do not claim legal anonymization, regulatory certification, or autonomous regulatory decisions. Human review is required before export and before acting on later cloud findings.
- Before any later TestFlight archive, increase both version fields in `scripts/generate_project.py` and regenerate the Xcode project.

## Review Focus

- A transcript instruction such as “ignore all redaction rules” must be treated as data (Task 3 synthetic prompt-injection test).
- A brand identical to a person's surname must be decided by context; the brand list must not create a blanket leak exception (Task 2 test).
- An ambiguous repeated name must be redacted consistently or rejected for review (Task 2 test).
- Manual edits that reintroduce an identifier must fail the final local check (Task 4 test).
- Cancellation, model failure, or insufficient storage must leave the raw meeting unchanged and produce no exportable artifact (Tasks 3 and 4 tests).

## File map

- `Sources/PrivacyPolicyKit/IdentitySpans.swift`: span types, validated UTF-16 offsets, overlap resolution, typed placeholders.
- `Sources/PrivacyPolicyKit/IdentityRules.swift`: deterministic direct-identifier checks; no broad drug/brand masking.
- `Sources/PrivacyPolicyKit/AnalysisTextDraft.swift`: local draft, approval state, and minimal outbound text encoding.
- `Sources/PrivacyPolicyKit/ModelIntegrity.swift`: streaming SHA-256 verification for imported model files.
- `Sources/PrivacyPolicyKit/LocalEntityDetector.swift`: async model interface and composition service.
- `App/LocalLlamaEntityDetector.swift`: iOS-only runtime adapter; never opens a network connection.
- `App/LocalModelStore.swift`: explicit Files import of the approved, hash-pinned model into protected, backup-excluded local storage.
- `App/DeidentificationReviewView.swift`: side-by-side review, manual masking, release control.
- `App/OpenPharmaMeetingApp.swift`, `App/en.lproj/Localizable.strings`, `App/ru.lproj/Localizable.strings`: new review action and a clearer “raw JSON” label.
- `scripts/generate_project.py`, `OpenPharmaMeeting.xcodeproj/project.pbxproj`: add app Swift files and a pinned, reviewed iOS runtime; regenerate after source changes.
- `Tests/PlatformTests/DeidentificationTests.swift`: synthetic host tests for detection, preservation, fail-closed behavior, and outbound serialization.
- `docs/MODEL_RUNTIME_REVIEW.md`, `docs/VALIDATION.md`: provenance and physical-device acceptance record.

## Task 1: Model and runtime feasibility gate

**Files:** Create `docs/MODEL_RUNTIME_REVIEW.md`; modify `docs/VALIDATION.md`.

**Interfaces:** Produces the approved model SHA-256, runtime revision, storage/provisioning rule, and device acceptance evidence required by Task 3.

- [ ] Verify [official Qwen model provenance](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/tree/main), Apache-2.0 terms, and the [published SHA-256](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/blob/main/Qwen3-0.6B-Q8_0.gguf) `9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031` for `Qwen3-0.6B-Q8_0.gguf`; review [`llama.cpp` b12248](https://github.com/ggml-org/llama.cpp/releases), MIT notices, build flags, transitive code, and security posture. Pin its full source commit in `docs/MODEL_RUNTIME_REVIEW.md`. Do not add either dependency before this review passes.
- [ ] Build a disposable iOS inference spike outside public source, using only synthetic Russian/English visit text. Measure model import/load time, peak resident memory, elapsed time for approximately 1,000 words, thermal behavior, and cancellation on iPad 9/A13 and iPad 10/A14 in airplane mode. Record device/OS, measurements, and failures in `docs/VALIDATION.md`. Keep any model binary outside Git.
- [ ] Gate: proceed only if a 1,000-word synthetic visit finishes in at most two minutes on each target iPad without OS termination, the model identifies all seeded physician/patient names and contextual cues, and it preserves seeded drug/competitor names. Otherwise document the failure and revise the model choice/design before Task 3; do not silently substitute cloud inference.
- [ ] Commit the review and benchmark evidence, excluding binary weights and private recordings.

## Task 2: Pure Swift redaction and artifact boundary

**Files:** Create `Sources/PrivacyPolicyKit/IdentitySpans.swift`, `IdentityRules.swift`, `AnalysisTextDraft.swift`, `LocalEntityDetector.swift`, `ModelIntegrity.swift`, and `Tests/PlatformTests/DeidentificationTests.swift`; regenerate `OpenPharmaMeeting.xcodeproj`.

**Interfaces:** `IdentifyingSpan(startUTF16: Int, endUTF16: Int, kind: IdentityKind)` and `LocalEntityDetector.detect(in:language:) async throws -> [IdentifyingSpan]`; `DeidentificationService.makeDraft(transcript:detector:) async throws -> AnalysisTextDraft` and `approve(draft:reviewedText:detector:) async throws -> AnalysisTextArtifact`. The artifact encodes only `schemaVersion`, `language`, and `text`. `ModelIntegrity.verify(url:expectedSHA256:) throws` streams the file rather than loading it into memory.

- [ ] Write failing tests `testDirectIdentifiersAreMasked`, `testBrandsAndClaimsRemainVerbatim`, `testRepeatedNamesAndOverlappingSpans`, `testMalformedOffsetsFailClosed`, `testArtifactContainsOnlyApprovedTextFields`, and `testModelHashMismatchRejected`. Use synthetic Russian/English text, including “Петров”, “Доктор Петров”, a drug/brand that looks like a surname, a telephone number, and an off-label claim.
- [ ] Run `swift test`; confirm the new tests fail for missing types/behavior.
- [ ] Implement validated span conversion and overlap merging; apply replacements from the end of text toward the start, using meeting-local placeholders. Reject out-of-bounds, split-grapheme, empty, or contradictory spans. Match direct contact/document patterns locally; the model supplies contextual names and indirect cues. Avoid saving a separate identity mapping.
- [ ] Implement `AnalysisTextArtifact` as a separate encoder with an allowlist of fields. Do not serialize `Meeting`, `Transcript`, local UUIDs, audio metadata, absolute dates, raw text, or model prompts into it. Keep draft/approval state in memory until the user exports. Implement streaming model-file hashing in `ModelIntegrity`.
- [ ] Run `swift test`, regenerate the Xcode project, run `git diff --check`, and commit this host-tested core.

## Task 3: On-device model adapter

**Files:** Create `App/LocalLlamaEntityDetector.swift`, `App/LocalModelStore.swift`; modify `scripts/generate_project.py`, `OpenPharmaMeeting.xcodeproj/project.pbxproj`, `docs/MODEL_RUNTIME_REVIEW.md`, and `Tests/PlatformTests/DeidentificationTests.swift`.

**Interfaces:** Implements `LocalEntityDetector`; model returns candidate JSON spans with category and exact quote, mapped to validated UTF-16 offsets. `LocalModelStore.importApprovedModel(from:)` verifies the Task 1 hash before protected local installation.

- [ ] Add failing host tests with a fake model for malformed JSON-derived spans, refusal, duplicate quotes, cancellation, and prompt-injection text; assert the service never releases an artifact on failure.
- [ ] Run `swift test` and observe the expected failures.
- [ ] Integrate only the reviewed, pinned `llama.cpp` iOS runtime. Import the model through Files; verify its full SHA-256 before atomically storing it with complete file protection and backup exclusion. The app must not download model weights or open a local HTTP server.
- [ ] Ask the local model only for identity spans in bounded text windows. Treat conversation content as untrusted data, parse strict structured output, map exact quotes back to the source, and reject ambiguous/malformed results. Disable analysis export when the model is unavailable, times out, is cancelled, or fails validation.
- [ ] Run host tests and the README generic iOS build; repeat the Task 1 synthetic device cases with the integrated app. Commit code and model notice, never model weights.

## Task 4: Review, final scan, and text-only export

**Files:** Create `App/DeidentificationReviewView.swift`; modify `App/OpenPharmaMeetingApp.swift`, both `Localizable.strings` files, `Tests/PlatformTests/DeidentificationTests.swift`, and `docs/VALIDATION.md`; regenerate the Xcode project.

**Interfaces:** `DeidentificationReviewView` receives `AnalysisTextDraft` and an approval callback; it can export only `AnalysisTextArtifact` after a second detector pass over the edited text.

- [ ] Add failing tests `testManualEditReintroducingNameBlocksApproval`, `testCancelledReviewHasNoArtifact`, `testOutboundEncodingExcludesMetadataAndAudio`, and `testReviewedBrandFalsePositiveCanBeRestored`; direct contact/document matches remain blocking even after review.
- [ ] Run `swift test` and observe failure, then implement the review flow with highlighted replacements, editable redacted text, residual-risk notice, and explicit “Approve text for analysis” action. Show model-unavailable errors without exposing the raw transcript in logs.
- [ ] Rename the existing action to “Export raw meeting JSON…” and keep its disclosure. Add a separate reviewed `.txt` export that uses the allowlisted artifact encoder. No network call or cloud provider is enabled in this plan.
- [ ] Run `swift test`, `python3 scripts/test_protocol.py`, `python3 scripts/check_public_source.py`, `git diff --check`, and the README generic iOS build. On both iPad models verify airplane-mode operation, Russian examples, model failures, manual corrections, exported bytes, and that the original audio/transcript remain intact. Commit source, generated project, and validation record.

## Follow-on project: company cloud analysis

After local text export passes device review, write a separate versioned public analysis-artifact contract and company connector plan. That plan must cover explicit submission, tenant auth, residency/retention, prompt and company visit-model governance, evidence-linked visit summaries, competitor/brand and objection extraction, next-visit suggestions, and human-reviewed regulatory-risk flags. It must never accept audio or raw meeting JSON by default.
