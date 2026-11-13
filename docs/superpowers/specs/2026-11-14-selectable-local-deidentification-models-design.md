# Selectable local de-identification models

## Intent

Allow an iPad user to compare Qwen3-0.6B-Q8_0 and Gemma 3 1B Q4_K_M for local text de-identification. Keep Apple Speech as the on-device transcription engine. Export remains an explicit, reviewed text-only action; audio and raw transcript stay local.

## Approaches

- **Selected: two verified model profiles.** Import each approved GGUF into its own slot, verify its published digest, show the active model, and use its matching chat template and prompt. This supports switching without silently replacing a model.
- A generic GGUF picker is more flexible but cannot establish model provenance, prompt compatibility, or expected output shape. Do not offer it in this iteration.
- Bundling model weights would remove import friction but increases app size and introduces redistribution obligations. Keep models user imported.

## Behavior

The model screen lists Qwen and Gemma with installed/verified status, active selection, and app version. An import failure identifies the stage (unsupported file, digest mismatch, insufficient storage, load, generation, or invalid response) without logging conversation text. Review and export errors appear beside their actions and remain visible while scrolling.

The de-identification detector targets doctor and patient identity. Representative names may remain. Model-specific prompts request exact source spans in constrained JSON; Qwen uses its supported non-thinking form, while Gemma uses its own template without Qwen control tokens. Examples cover doctor greetings, standalone later references, representative self-introduction, brands, and place names. Deterministic checks protect obvious doctor/patient references and contact details; no rule globally masks words merely because they appear in a name list. Preserve drug, company, competitor, medical, and standalone street names. Treat a full residential/contact address tied to a doctor or patient as identifying information. Human review remains mandatory.

## Verification and limits

Use the same labeled Russian transcripts to compare missed doctor/patient identifiers and incorrectly removed brands/streets across both models. Verify import integrity, switching, error placement, cancellation, memory, and latency on iPad 9 and 10 before another TestFlight archive. No model is assumed superior from parameter count or quantization alone. Review the Gemma model license and the selected GGUF's provenance before adding its digest. No cloud audio or raw-transcript path is introduced.
