# Gemma Entity Extraction Evaluation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task. Steps use checkbox syntax.

**Goal:** Determine whether Gemma 3 1B Q4_K_M can identify all personal names in short Russian transcripts without masking brands or other non-person names, then change the app only if a safe candidate-based contract passes the evaluation.

**Architecture:** Keep model weights and user recordings outside Git. Use a small, versioned synthetic fixture for expected person spans and protected terms. Run the pinned GGUF with the same llama.cpp revision and greedy constrained decoding as the app. A candidate approach may narrow model output to literal source substrings; existing local span validation remains mandatory.

**Tech Stack:** Swift/SwiftPM, llama.cpp CLI for offline research, Python standard library for aggregate scoring.

**Spec:** User approval to evaluate candidate-based Gemma extraction after the 0.1.8 iPad failure.

## Global Constraints

- No audio, transcript, or model weights in Git; no network or cloud inference.
- Preserve drug/brand, competitor, medical-term, and standalone street mentions.
- Reject malformed or unmatched model output; never silently export on model failure.
- Do not create a TestFlight archive in this task.

## Review Focus

- Names, surnames and patronymics of representatives, doctors and patients must all be detected; role labels are unnecessary.
- Personal names repeated in direct address and later references must be covered.
- Brand/person collisions and standalone streets must remain context-sensitive.
- Empty or hallucinated model output must not be counted as a successful privacy result.
- Evaluation must distinguish recall, false positives, format failure, and runtime failure.

### Task 1: Synthetic evaluation fixture

**Files:** Create `Tests/Fixtures/deidentification_eval.json`.

- [x] Add short synthetic cases covering direct address, patient context, representative identity, names outside the seed lexicon, brand/name collision, competitor brands, and streets.
- [x] Mark exact substrings that must be masked and exact terms that must remain.
- [x] Validate fixture structure and labels with a standard-library check.

### Task 2: Offline comparison

**Files:** Create `scripts/evaluate_gemma.py` for local research; update `docs/IMPLEMENTATION_STATUS.md` and `docs/PROJECT_CONTEXT.md` with results.

- [x] Prepare the pinned Gemma GGUF and matching llama.cpp CLI outside the repository.
- [x] Compare an approximation of the current prompt/grammar with candidate-constrained alternatives on the fixture. The candidate mode failed the fixture, so a second copy of the private iPad transcript was unnecessary.
- [x] Report per-case identity recall, protected-term retention, malformed/unmatched responses, and model errors in `docs/GEMMA_EVALUATION.md`. Keep private source and generated text outside Git.

### Task 3: Conditional app change

**Files:** If evaluation passes, modify `Sources/PrivacyPolicyKit/LocalModelProfile.swift`, `App/LocalLlamaEntityDetector.swift`, and relevant Swift tests.

- [ ] Write a failing test for exact person-name candidate output and rejected noncandidate text; use a role-neutral `person` kind.
- [ ] Implement only the validated Gemma path; retain Qwen behavior and final local checks.
- [ ] Run `swift test`, protocol tests, source scan, and generic iOS build. If evaluation fails, document the gap and leave app code unchanged.

**Gate result:** Candidate extraction masked 16/17 person occurrences but only preserved 15/20 protected terms. Even an oracle binary question about each known occurrence labeled all 20 protected terms as people. Task 3 is intentionally not started. No app source or TestFlight build changed.
