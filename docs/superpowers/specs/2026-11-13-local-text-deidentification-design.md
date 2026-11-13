# Local Text De-identification — Design

## Intent and boundary

Prepare meeting text for analysis outside the iPad while keeping the original audio, transcript, prompts, model input, and review edits on the device. Only an explicitly approved, reduced text artifact may cross the export or future enterprise connector boundary. No audio is uploaded. The app must not claim that a model output is legally anonymous or that the feature alone establishes compliance; the company determines the lawful basis, recipient, retention, and review policy.

## Approaches

- **Rules only:** predictable and cheap on iPad 9/10, but misses contextual identifiers and unusual Russian phrasing.
- **Local LLM only:** catches context, but may miss identifiers or alter meaning; output is hard to validate by itself.
- **Chosen working design — hybrid, entirely local:** exact detectors and a small local language model propose redactions; deterministic validation, human review, and a fail-closed release gate limit omissions. No remote inference or silent fallback.

## Data flow

1. Start from the saved local transcript, never from audio sent elsewhere. Assemble paragraphs while retaining segment offsets only in the private workspace. Do not feed meeting UUID, title, creation time, recording metadata, or access policy into the export artifact.
2. Detect direct identifiers (names, contacts, addresses, document numbers, precise dates) with local rules. Ask the local model for spans that may identify a person through context, including workplace/role combinations, rare events, and patient details. Do not rely on the model to rewrite the whole conversation.
3. Merge overlapping spans and replace them with typed, meeting-scoped placeholders such as `[PERSON_1]` and `[LOCATION_1]`. Generalize or remove clinical details when they can identify a patient; preserve drug names, product brands, objections, and medically relevant meaning when safe. Keep any replacement map only in protected local storage, never in the transferable artifact.
4. Show a side-by-side local review with highlighted changes and residual-risk warnings. The reviewer can redact more or reject the draft. A failed, unavailable, timed-out, or unvalidated model leaves export/submission disabled. No automatic submission.
5. After explicit approval, create a separate analysis artifact containing only reviewed text, language, and a non-identifying schema/version marker. Existing raw meeting JSON export stays clearly labeled as raw and is never used by the analysis action. The future company connector accepts only this reviewed artifact through its own authorization and policy checks. Any wire change belongs in a versioned public contract; namespaced extensions remain preserved.

## Implementation constraints and checks

Create a separate local de-identification component behind a model interface. Before adding a runtime/model dependency, review its license, provenance, security, model terms, Russian quality, and offline behavior. Benchmark candidate runtimes on both iPad 9/A13 and iPad 10/A14 for memory, latency, battery, and thermal limits. Keep iPadOS 16 support; no Apple Intelligence requirement. Model files and prompts must not generate network traffic or telemetry.

Test with synthetic Russian/English transcripts covering direct and indirect identifiers, patients, brands, false positives, model omissions, malformed spans, interruption, and cancellation. Assert byte-for-byte that outbound artifacts contain no audio, raw transcript, local IDs, timestamps, or replacement map. A human-approved sample and device tests are required before enabling any connector. Legal/privacy review by the operating company remains necessary for each real deployment.
