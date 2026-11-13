# Dependency and provenance review

Preferred license: Apache-2.0 for original project code. Its permissive terms and patent provisions suit enterprise/open interoperability. Redistributors must retain required license/notices, identify modifications where required and review patent/NOTICE conditions. See the full LICENSE; this is an engineering inventory, not a regulatory or legal certification.

## Runtime

- `llama.cpp` `b12248`, source commit `3837bf0bc02ea5d08f8ee3585fc8c7784a81bce8`, MIT. `ThirdParty/llama.framework` is built from that source for iOS 16.0 with app/common/tools/tests/server/multimodal disabled, Metal enabled, OpenSSL disabled, and static components combined into one dynamic framework. The MIT text is in `ThirdParty/llama-LICENSE.txt`. Build provenance, binary hash, and review limits are in `docs/MODEL_RUNTIME_REVIEW.md`.
- Qwen3-0.6B-Q8_0 GGUF is imported by the user through Files and is **not** distributed in the app or repository. Its publisher declares Apache-2.0; the exact file hash is pinned in `App/LocalModelStore.swift`.

Swift standard library/Foundation, SwiftUI, AVFoundation, Speech, CryptoKit and OS services are used under Apple's applicable SDK/platform terms; Apple framework source is not copied or relicensed. Signing/distribution remains subject to platform terms.

## Development only

- Python standard library/project scripts: no bundled third-party source.
- jsonschema 4.26.0: MIT. Its installed transitive dependencies must be captured with their license notices if redistributed; they are not vendored or shipped in this app. Typical dependencies include attrs (MIT), referencing (MIT), rpds-py (MIT), jsonschema-specifications (MIT). CI package resolution can evolve; pin transitive dependencies before distributing a test environment.
- GitHub checkout/setup-python actions: MIT-licensed upstream actions, fetched by CI and not included in application binaries. Review and pin immutable action SHAs before release hardening.

The supplied MeetingTranscriber-iPad archive has no license/provenance statement. It is excluded from Git along with the extracted prototype. Project code is newly authored; the review identified general public Apple API approaches to reuse, not permission to redistribute supplied implementation text.

Before adopting a dependency, record exact version/source/checksum, SPDX license, license/NOTICE texts, transitive obligations, binary/model rights, privacy behavior and security ownership. Copyleft/field-of-use/model-data terms require explicit compatibility review. Do not embed model weights without separately established distribution rights.
