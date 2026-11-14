# Gemma name extraction: offline evaluation

Date: 2026-11-14. This is a research result, not a privacy certification.

## Goal and method

The user clarified that every person's name should be removed regardless of whether they are a representative, doctor, or patient. Brand, drug, company, institution, medical-term, and standalone street names must remain. The 12 cases in `Tests/Fixtures/deidentification_eval.json` are synthetic and mark 17 person-name occurrences and 20 protected-term occurrences, including name/brand and name/street collisions. No iPad transcript or model weights are in Git.

`scripts/evaluate_gemma.py` runs the SHA-256-pinned Gemma 3 1B Q4_K_M with a Mac CPU build of the same llama.cpp source revision used by the app (`3837bf0`). It uses greedy decoding, a 2048-token context, and GBNF-constrained output. The baseline mode is an approximation of the 0.1.8 instruction without dynamic lexicon hints; it is **not** an exact app comparison. The candidate mode gives the model literal capitalized words and adjacent pairs, forces JSON output with `kind: person`, and constrains `quote` to the candidate set. Scoring emulates the app's explicit brand/street-context exemptions; the iPad remains the release gate.

| Local research mode | Person occurrences masked | Protected terms kept | Format failures |
| --- | ---: | ---: | ---: |
| Approximate 0.1.8 baseline | 0/17 | 20/20 | 0 |
| Candidate prompt, first extractor | 13/17 | 15/20 | 0 |
| Candidate prompt, overlapping name pairs | 16/17 | 15/20 | 0 |
| One-occurrence binary question, known targets | 17/17 | 0/20 | 0 |

The candidate constraint removed the long invented `quote` values seen in the iPad failure reproduction, but the model still selected non-person names. Examples include `Кискали` in a sentence without an explicit “препарат” prefix, `Novartis`, `Ilaris`, and `Бакулева` in an institution name. It also selected ordinary capitalized words such as `Меня` and `Обсудим`. In one case it missed the representative's name. A further experiment supplied each already-annotated occurrence to Gemma as a binary person/non-person question. It answered “person” for every target, including all 20 protected terms. This is an oracle upper bound because production would also have to discover target occurrences. These are failures against the user's stated requirement.

## Decision

Do not integrate these Gemma prompts into the app or relax local validation. The user reports that Qwen passes the technical response check on the same iPad meeting but misses many names; it is therefore not a validated de-identification option either. The binary occurrence experiment also failed, so more prompt iteration on this 1B model is not justified by the current evidence. Field evaluations should first count missed personal names and falsely removed brands locally on both target iPads, following `docs/VALIDATION.md`. Then compare a different local NER architecture or a more capable device-suitable model against the same fixture plus independently labeled speech-recognition output. A passing synthetic fixture is necessary but not sufficient for safe export.

Reproduce fixture validation without a model: `python3 scripts/evaluate_gemma.py --validate-only`. To run the local model research, provide an approved GGUF and a matching `llama-completion` executable: `python3 scripts/evaluate_gemma.py --model /private/tmp/gemma.gguf --llama-cli /private/tmp/llama-completion --mode candidates`. The test copies and generated prompts live in temporary storage and should be removed after use.
