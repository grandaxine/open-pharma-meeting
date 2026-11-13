# Selectable Local Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import, select, and run either verified Qwen3 Q8 or Gemma 3 1B Q4 for on-device doctor/patient text de-identification, with clear model status and errors.

**Architecture:** A model profile defines identity, checksum and chat formatting. The local store keeps separate verified slots and an active selection. The detector uses the selected profile; the app presents status and stage-specific errors near the affected control.

**Tech Stack:** Swift 5.9, SwiftUI, llama.cpp, Apple Speech unchanged, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-14-selectable-local-deidentification-models-design.md`

## Global Constraints

- iPadOS 16+, local-only text processing, no audio or raw transcript export through analysis flow.
- Preserve brands, clinical terms and standalone street names; remove doctor/patient identifiers and linked full addresses. Representative names may remain.
- Model files remain user imported and are checked against known SHA-256 digests.
- No TestFlight archive in this task.

## Review Focus

- Unsupported or corrupt GGUF must not displace a working installed model.
- Switching while an operation is active must not alter that operation's model.
- Gemma output must be parsed under its own prompt format; Qwen-only control tokens must be absent.
- A doctor name that is also a brand or street must be resolved by context, not globally whitelisted or globally redacted.
- Cancellation and model load failures must leave audio and transcript intact and show a nearby reason.

---

### Task 1: Verified model profiles and storage

**Files:** Create `Sources/PrivacyPolicyKit/LocalModelProfile.swift`; modify `App/LocalModelStore.swift`; test `Tests/PlatformTests/DeidentificationTests.swift`.

**Interfaces:** `LocalModelProfile` exposes Qwen/Gemma identifier, display name, filename, digest and prompt format; `LocalModelStore` imports and verifies a specified profile, lists installed profiles and reads/writes active profile.

- [ ] Write tests for both profile digests, distinct slots, invalid profile/file rejection and retained active selection.
- [ ] Run focused tests and observe failure.
- [ ] Implement profiles, separate file slots, selection persistence and differentiated integrity errors.
- [ ] Run focused tests and observe pass.
- [ ] Regenerate Xcode project after new Swift file and commit this task.

### Task 2: Model-specific prompts and identity scope

**Files:** Modify `App/LocalLlamaEntityDetector.swift`, `Sources/PrivacyPolicyKit/IdentityRules.swift`, `Sources/PrivacyPolicyKit/EntityResponseParser.swift`; test `Tests/PlatformTests/DeidentificationTests.swift`.

**Interfaces:** Detector takes a `LocalModelProfile`; prompt builder uses matching Qwen or Gemma chat framing and grounded examples; rules/parser preserve brands and standalone streets while identifying doctor/patient mentions.

- [ ] Write tests for prompt framing, doctor/patient names, representative self-introduction, brands, street names and linked full address.
- [ ] Run focused tests and observe failure.
- [ ] Implement the smallest rule and prompt changes; avoid blanket masking of given names.
- [ ] Run focused tests and observe pass; commit this task.

### Task 3: Model and error UI

**Files:** Modify `App/OpenPharmaMeetingApp.swift`, `App/DeidentificationReviewView.swift`, `App/ru.lproj/Localizable.strings`, `docs/PROJECT_CONTEXT.md`, `docs/IMPLEMENTATION_STATUS.md`, and model provenance review.

**Interfaces:** Model picker displays active/installed profile and app version; imports apply to chosen profile; error views use typed local failures and appear beside import/review actions.

- [ ] Add UI state and localized stage-specific messages, preserving current cancellation semantics.
- [ ] Put review/export errors before the long transcript and model import errors beside the model picker.
- [ ] Update docs, regenerate project if needed, and run `swift test`, protocol tests, source scan and generic iOS build.
- [ ] Commit this task and review the whole branch diff.
