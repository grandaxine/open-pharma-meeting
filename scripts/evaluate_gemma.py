#!/usr/bin/env python3
"""Offline research harness for the pinned Gemma GGUF; never sends text anywhere."""

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

EXPECTED_SHA256 = "8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135"
CAPITALIZED_WORD = re.compile(r"(?<![\w])[A-ZА-ЯЁ][a-zа-яё]+")
PROTECTED_CONTEXT = re.compile(
    r"(?i)(?:препарат[а-яё]*|бренд[а-яё]*|лекарств[а-яё]*|компан[а-яё]*|"
    r"улиц[а-яё]*|ул\.|проспект[а-яё]*|drug|brand|company|street)\s+$"
)
BASELINE_GRAMMAR = r'''root ::= "{" "\"entities\"" ":" "[" (entity ("," entity)*)? "]" "}"
entity ::= "{" "\"quote\"" ":" string "," "\"kind\"" ":" kind "}"
kind ::= "\"doctor\"" | "\"patient\"" | "\"person\"" | "\"address\"" | "\"organization\"" | "\"contact\"" | "\"document\"" | "\"other\""
string ::= "\"" ([^"\\\x7F\x00-\x1F] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4}))* "\""
'''


def occurrences(text, quote):
    start = 0
    while True:
        found = text.find(quote, start)
        if found < 0:
            return
        yield found, found + len(quote)
        start = found + len(quote)


def annotated_range(case, annotation):
    spans = list(occurrences(case["text"], annotation["quote"]))
    return spans[annotation["occurrence"]]


def validate_fixture(fixture):
    assert fixture["schemaVersion"] == "1"
    seen_ids = set()
    for case in fixture["cases"]:
        assert case["id"] not in seen_ids
        seen_ids.add(case["id"])
        assert case["text"] and isinstance(case["text"], str)
        marked = []
        for category in ("mask", "preserve"):
            for annotation in case[category]:
                assert annotation["quote"]
                assert annotation["occurrence"] >= 0
                marked.append((category, annotated_range(case, annotation)))
        for index, (category, span) in enumerate(marked):
            for other_category, other_span in marked[index + 1:]:
                assert category == other_category or not overlaps(span, other_span), case["id"]


def overlaps(left, right):
    return left[0] < right[1] and right[0] < left[1]


def candidates(text):
    values = []
    seen = set()
    words = list(CAPITALIZED_WORD.finditer(text))
    # Include overlapping bigrams: "Doctor John Smith" must offer "John Smith".
    phrases = [text[left.start():right.end()] for left, right in zip(words, words[1:])
               if text[left.end():right.start()].isspace()]
    for value in phrases + [match.group() for match in words]:
        if value.casefold() not in seen:
            values.append(value)
            seen.add(value.casefold())
    return values[:32]


def grammar_literal(value):
    return json.dumps(json.dumps(value, ensure_ascii=False), ensure_ascii=False)


def candidate_grammar(values):
    alternatives = " | ".join(grammar_literal(value) for value in values)
    return (
        'root ::= (entity ("," entity)*)? "]" "}"\n'
        'entity ::= "{" "\\\"quote\\\"" ":" quote "," "\\\"kind\\\"" ":" "\\\"person\\\"" "}"\n'
        f"quote ::= {alternatives}\n"
    )


def candidate_prompt(text, values):
    safe_text = text.replace("<start_of_turn>", "< start_of_turn >").replace(
        "<end_of_turn>", "< end_of_turn >"
    )
    return (
        "<start_of_turn>user\n"
        "Найди имена, фамилии и отчества любых людей в разговоре. "
        "Для quote используй только точную строку из списка кандидатов; "
        "kind всегда person. Не выбирай препараты, бренды, компании, "
        "медицинские термины, названия улиц и учреждений. "
        "Если людей нет, оставь entities пустым. Ответь только JSON.\n"
        f"Кандидаты: {', '.join(values)}.\n"
        f"Текст: {safe_text}\n"
        '<end_of_turn>\n<start_of_turn>model\n{"entities":['
    )


def baseline_prompt(text):
    # Snapshot of the 0.1.8 Gemma instruction; hints are omitted in this research baseline.
    return (
        "<start_of_turn>user\n"
        "Найди в разговоре только фрагменты, позволяющие узнать врача или пациента: "
        "имя, отчество, фамилию, контакт или полный личный адрес. Для quote копируй "
        "точную короткую подстроку исходного текста, не предложение. "
        "Не отмечай препараты, бренды, компании, конкурентов, медицинские термины "
        "или отдельные названия улиц. Если личных сведений нет, верни "
        '{"entities":[]}. Ответь только одним JSON-объектом.\n'
        f"<conversation>\n{text}\n</conversation><end_of_turn>\n<start_of_turn>model\n"
    )


def run_model(cli, model, prompt, grammar, workdir, mode):
    prompt_path = workdir / f"{mode}.prompt"
    grammar_path = workdir / f"{mode}.gbnf"
    prompt_path.write_text(prompt)
    grammar_path.write_text(grammar)
    result = subprocess.run(
        [str(cli), "--model", str(model), "--file", str(prompt_path),
         "--grammar-file", str(grammar_path), "--ctx-size", "2048",
         "--batch-size", "512", "--threads", "4", "--gpu-layers", "0",
         "--predict", "384", "--temp", "0", "--no-conversation",
         "--no-display-prompt", "--simple-io", "--no-warmup"],
        capture_output=True, text=True, timeout=90, check=False,
    )
    if result.returncode:
        return None, "runtime"
    output = result.stdout.split(" [end of text]")[0].strip()
    if mode == "candidates":
        output = '{"entities":[' + output
    try:
        root = json.loads(output)
        assert set(root) == {"entities"} and isinstance(root["entities"], list)
        entities = root["entities"]
        assert all(set(item) == {"quote", "kind"} for item in entities)
        return entities, None
    except (ValueError, AssertionError, TypeError):
        return None, "format"


def classify_known_occurrence(case, annotation, cli, model, workdir):
    """Oracle upper bound: annotation supplies the target, not production extraction."""
    start, end = annotated_range(case, annotation)
    source = case["text"]
    marked = source[:start] + "<target>" + source[start:end] + "</target>" + source[end:]
    prompt = (
        "<start_of_turn>user\n"
        "Является ли выделенный фрагмент именем, фамилией или отчеством "
        "конкретного человека? Ответь 1, если да. Ответь 0 для бренда, "
        "препарата, компании, учреждения, улицы или обычного слова. "
        "Учитывай контекст этого вхождения, а не только написание.\n"
        f"Текст: {marked}\n"
        "<end_of_turn>\n<start_of_turn>model\n"
    )
    prompt_path = workdir / "binary.prompt"
    grammar_path = workdir / "binary.gbnf"
    prompt_path.write_text(prompt)
    grammar_path.write_text('root ::= "0" | "1"\n')
    result = subprocess.run(
        [str(cli), "--model", str(model), "--file", str(prompt_path),
         "--grammar-file", str(grammar_path), "--ctx-size", "2048",
         "--batch-size", "512", "--threads", "4", "--gpu-layers", "0",
         "--predict", "4", "--temp", "0", "--no-conversation",
         "--no-display-prompt", "--simple-io", "--no-warmup"],
        capture_output=True, text=True, timeout=90, check=False,
    )
    if result.returncode:
        return None
    answer = result.stdout.split(" [end of text]")[0].strip()
    return answer if answer in {"0", "1"} else None


def evaluate_oracle_binary(case, cli, model, workdir):
    mask_answers = [classify_known_occurrence(case, item, cli, model, workdir)
                    for item in case["mask"]]
    preserve_answers = [classify_known_occurrence(case, item, cli, model, workdir)
                        for item in case["preserve"]]
    return {"id": case["id"], "mode": "oracle-binary",
            "error": "runtime" if None in mask_answers + preserve_answers else None,
            "recall": mask_answers.count("1"), "target": len(mask_answers),
            "protected": preserve_answers.count("0"),
            "protectedTarget": len(preserve_answers), "quotes": []}


def predicted_ranges(text, entities, allowed):
    spans = []
    for entity in entities:
        quote = entity["quote"]
        if not isinstance(quote, str) or not quote or len(quote.split()) > 4:
            return None, "overlong"
        if allowed is not None and quote not in allowed:
            return None, "noncandidate"
        found = list(occurrences(text, quote))
        if not found:
            return None, "unmatched"
        for span in found:
            if PROTECTED_CONTEXT.search(text[max(0, span[0] - 40):span[0]]):
                continue
            spans.append(span)
    return spans, None


def evaluate_case(case, mode, cli, model, workdir):
    text = case["text"]
    values = candidates(text) if mode == "candidates" else None
    entities = []
    if mode == "candidates" and not values:
        spans, error = [], None
    else:
        prompt = candidate_prompt(text, values) if values is not None else baseline_prompt(text)
        grammar = candidate_grammar(values) if values is not None else BASELINE_GRAMMAR
        entities, error = run_model(cli, model, prompt, grammar, workdir, mode)
        spans = None
        if error is None:
            spans, error = predicted_ranges(text, entities, values)
    masks = [annotated_range(case, item) for item in case["mask"]]
    preserves = [annotated_range(case, item) for item in case["preserve"]]
    if error:
        return {"id": case["id"], "mode": mode, "error": error,
                "recall": 0, "target": len(masks), "protected": 0,
                "protectedTarget": len(preserves), "quotes": []}
    recall = sum(any(start <= mask[0] and end >= mask[1] for start, end in spans) for mask in masks)
    protected = sum(not any(overlaps(item, span) for span in spans) for item in preserves)
    return {"id": case["id"], "mode": mode, "error": None,
            "recall": recall, "target": len(masks), "protected": protected,
            "protectedTarget": len(preserves),
            "quotes": [item["quote"] for item in entities] if values is not None else []}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--llama-cli", type=Path)
    parser.add_argument("--fixture", type=Path,
                        default=Path(__file__).resolve().parents[1] / "Tests/Fixtures/deidentification_eval.json")
    parser.add_argument("--mode", choices=["baseline", "candidates", "oracle-binary", "both"], default="both")
    parser.add_argument("--show-quotes", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    fixture = json.loads(args.fixture.read_text())
    validate_fixture(fixture)
    if args.validate_only:
        print(len(fixture["cases"]), "synthetic cases validated")
        return
    if not args.model or not args.llama_cli:
        parser.error("--model and --llama-cli are required unless --validate-only is used")
    hasher = hashlib.sha256()
    with args.model.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    if digest != EXPECTED_SHA256:
        parser.error("Gemma GGUF SHA-256 differs from the approved model")
    modes = ("baseline", "candidates") if args.mode == "both" else (args.mode,)
    for mode in modes:
        results = []
        with tempfile.TemporaryDirectory(prefix="opms-gemma-eval-") as directory:
            workdir = Path(directory)
            for case in fixture["cases"]:
                outcome = (evaluate_oracle_binary(case, args.llama_cli, args.model, workdir)
                           if mode == "oracle-binary" else
                           evaluate_case(case, mode, args.llama_cli, args.model, workdir))
                results.append(outcome)
                print(mode, outcome["id"],
                      outcome["error"] or f'{outcome["recall"]}/{outcome["target"]} names; '
                      f'{outcome["protected"]}/{outcome["protectedTarget"]} protected',
                      outcome["quotes"] if args.show_quotes else "")
        print(mode, "total", sum(x["recall"] for x in results), "/",
              sum(x["target"] for x in results), "names;",
              sum(x["protected"] for x in results), "/",
              sum(x["protectedTarget"] for x in results), "protected;",
              sum(x["error"] is not None for x in results), "failures")


if __name__ == "__main__":
    main()
