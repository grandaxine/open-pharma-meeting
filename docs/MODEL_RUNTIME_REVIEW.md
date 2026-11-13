# Local model and runtime review

Status: **TestFlight trial only**. Provenance and binary checks below support an experimental on-device build. Identification quality and device performance remain unvalidated; this is not approval for unsupervised use or a legal anonymity claim.

## Candidate model

- Publisher: [Qwen official account](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/tree/main).
- File: `Qwen3-0.6B-Q8_0.gguf`, approximately 639 MB; the publisher lists SHA-256 `9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031` on the [file page](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/blob/main/Qwen3-0.6B-Q8_0.gguf).
- Declared license: Apache-2.0. Preserve the complete model license and required notices in any distribution.

## Optional Gemma comparison model (2026-11-14)

- Publisher/converter: [ggml-org Gemma 3 1B IT GGUF](https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF), derived from Google's Gemma 3 1B instruction-tuned weights. The approved `gemma-3-1b-it-Q4_K_M.gguf` file page publishes SHA-256 `8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135` and an approximately 806 MB file.
- [Google's Gemma terms](https://ai.google.dev/gemma/terms) apply; this is not Apache-2.0. The app links to the source and accepts a user-imported file. We do not redistribute Gemma weights or claim permission to do so without a separate terms review.
- The selected llama.cpp runtime must be verified on iPad 9/10 with this exact Gemma GGUF and its chat template. Compilation and host tests alone do not establish memory use, speed or identity recall.
- The official 609 MiB file was downloaded outside Git and its full SHA-256 matched the published value. Russian physician/patient identifier recall, brand preservation, iPad memory, latency, thermal behavior, and cancellation have **not** yet been established.

## Candidate runtime

- Publisher: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp). Candidate release `b12248`, source commit `3837bf0bc02ea5d08f8ee3585fc8c7784a81bce8`, independently checked with `git ls-remote` and a shallow source checkout outside this repository.
- Declared license: [MIT](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE). The source tree also contains third-party notices under `vendor/`; the exact linked iOS components and transitive obligations still require review.
- The official release zip SHA-256 was `fe38916b41f2a144115db39df860cb2f6f98a476589d5072b0cc3f51dbaf8c10`. Its iOS binary has a 16.4 deployment target, so it was not integrated.
- A temporary copy of the pinned source build script set `IOS_MIN_OS_VERSION=16.0` and disabled `LLAMA_BUILD_MTMD`. The official script's remaining iOS-device flags were used with CMake 4.1.2 and Xcode 26.5. Only the resulting iOS `llama.framework` is vendored. Its Mach-O and plist both declare iOS 16.0; SHA-256 of its binary is `ac2e5d826592cae6e6e8f41a31126399444c274725767a8a88ceca010a197a83`.
- The build disables app, common library, examples, tools, tests, server and multimodal code; OpenSSL is off. `otool -L` lists only Foundation, Metal, Accelerate, libc++, libSystem, CoreFoundation and libobjc; a global symbol search found no curl/socket/CFNetwork imports. This is a limited static review, not a security guarantee. The app does not open an HTTP server or download weights at runtime.
- A synthetic macOS prompt using the same 0.6B model produced an overbroad doctor span and an invented quote. The app rejects long personal-name quotes, unmatched source strings and malformed JSON, so those outputs cannot create an export. This indicates likely false negatives and failed drafts in the TestFlight trial. Human review and final local recheck are mandatory; model quality needs device testing before real sensitive conversations.

## Decision gate

The user explicitly requested a TestFlight build before multi-iPad testing. Integration is limited to an experimental, fail-closed, text-only review flow. Both-device synthetic offline benchmark, model-quality measurements and broader binary audit remain release gates for production use. No cloud fallback is allowed.
