# Local Text De-identification — Design

## Intent and boundary

Record audio and transcribe it on the iPad, then de-identify the resulting text locally. The original audio, raw transcript, local-model input, and review edits remain on the device. Only an explicitly approved text artifact may cross the future enterprise connector boundary; audio is never uploaded, and this workflow does not require editing the retained audio file. Remove names and details that permit identification of a physician or patient. Preserve drug names, company and competitor brands, medical terminology, visit content, and other information unrelated to personal identification. The app must not claim that model output is legally anonymous or that this feature alone establishes compliance; the operating company determines lawful basis, recipient, residency, retention, and review policy.

## Purpose of cloud analysis

An approved cloud LLM will help the medical representative document the visit: key messages, brands and competitors mentioned, objections, stages against the company's visit model, and suggestions for preparing the next visit. It will also surface possible regulatory concerns such as off-label claims, unsupported promises, comparisons without cited evidence, or inducements to a physician. Each output must point to relevant passages, express uncertainty, and remain a draft for qualified human review. Company-owned policy and prompts govern analysis; no autonomous regulatory decision is made.

## Approaches

- **Rules only:** predictable and cheap on iPad 9/10, but misses contextual identifiers and unusual Russian phrasing.
- **Local LLM only:** catches context, but may miss identifiers or alter meaning; output is hard to validate by itself.
- **Chosen working design — hybrid, entirely local:** exact detectors and a small local language model propose redactions; deterministic validation, human review, and a fail-closed release gate limit omissions. No remote inference or silent fallback.

## Data flow

1. Start from the saved local transcript. Assemble readable paragraphs while retaining offsets only in the private workspace. Exclude meeting UUID, title, exact visit time, recording metadata, and access policy from the outbound artifact. Relative passage references may be retained if needed to verify findings.
2. Detect names and direct identifiers with local rules. Ask the local model for spans that could identify a physician or patient through context, such as a rare role/workplace combination or distinctive patient story. Do not ask it to rewrite the conversation. Distinguish drug and competitor brand names from person names; a protected term list is an aid, not an exemption for an identifying phrase.
3. Merge validated spans and replace only identifying content with typed, meeting-scoped placeholders such as `[DOCTOR_1]` and `[PATIENT_1]`. Preserve non-identifying clinical facts, drug names, competitor brands, objections, and claims for later verification. Generalize a clinical detail only when its combination would identify a patient. Keep any replacement map in protected local storage, never in the transferable artifact.
4. Show a side-by-side local review with highlighted replacements and residual-risk warnings. The reviewer can restore an incorrectly removed brand or redact more identifying text. A failed, unavailable, timed-out, or unvalidated model leaves submission disabled. No automatic cloud call.
5. After explicit approval, create a separate analysis artifact containing only reviewed text, language, and minimal non-identifying references. Existing raw meeting JSON export stays clearly labeled as raw and is never used by the analysis action. The future company connector accepts only this artifact through company authorization and policy checks. Any wire change belongs in a versioned public contract; namespaced extensions remain preserved.

## Implementation constraints and checks

Create a separate local de-identification component behind a model interface. Before adding a runtime/model dependency, review its license, provenance, security, model terms, Russian quality, and offline behavior. Benchmark candidate runtimes on both iPad 9/A13 and iPad 10/A14 for memory, latency, battery, and thermal limits. Keep iPadOS 16 support; no Apple Intelligence requirement. Model files and prompts must not generate network traffic or telemetry.

Test with synthetic Russian/English transcripts covering physician and patient identifiers, competitor/drug brands, rare clinical context, false positives, model omissions, malformed spans, interruption, and cancellation. Verify that outbound artifacts contain no audio, raw meeting JSON, local IDs, exact visit times, or replacement map, while preserving expected brand and claim spans. A human-approved sample and device tests are required before enabling any connector. Legal/privacy review by the operating company remains necessary for each real deployment.
