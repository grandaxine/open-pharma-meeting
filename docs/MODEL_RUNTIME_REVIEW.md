# Local model and runtime review

Status: **pending**. No model or runtime has been added to the app or public repository. This is a candidate review, not an approval for distribution.

## Candidate model

- Publisher: [Qwen official account](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/tree/main).
- File: `Qwen3-0.6B-Q8_0.gguf`, approximately 639 MB; the publisher lists SHA-256 `9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031` on the [file page](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/blob/main/Qwen3-0.6B-Q8_0.gguf).
- Declared license: Apache-2.0. Preserve the complete model license and required notices in any distribution.
- Full-file hash, Russian physician/patient identifier recall, brand preservation, memory, latency, thermal behavior, and cancellation have **not** yet been measured locally.

## Candidate runtime

- Publisher: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp). Candidate release `b12248`, source commit `3837bf0bc02ea5d08f8ee3585fc8c7784a81bce8`, independently checked with `git ls-remote` and a shallow source checkout outside this repository.
- Declared license: [MIT](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE). The source tree also contains third-party notices under `vendor/`; the exact linked iOS components and transitive obligations still require review.
- The release offers `llama-b12248-xcframework.zip`. Its checksum, binary contents, and linked frameworks have **not** yet been verified.
- The source `build-xcframework.sh` sets `IOS_MIN_OS_VERSION=16.4`, while this app supports iPadOS 16.0. The release workflow configures an iOS build target of 16.0; verify the actual XCFramework minimum deployment target before use. A 16.4-only binary is unacceptable for the current app floor. A source build would need a reviewed 16.0 override; CMake 3.28+ is not installed in this environment.
- The inspected framework script disables the app, common library, examples, tools, tests and server; it enables Metal and static linking. This narrows the expected linked code but does not prove the published binary's contents. Core CMake has an OpenSSL option; exact linked components and symbols still need inspection. The app will not open a local HTTP server or download weights at runtime.

## Decision gate

Proceed with integration only after the full license/provenance/security audit and synthetic offline benchmark pass on both target iPads. Only iPad 10 is presently connected. iPad 9 evidence and all model-quality measurements are pending; no cloud fallback is allowed.
