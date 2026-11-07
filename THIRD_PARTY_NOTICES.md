# Dependency and provenance review

Preferred license: Apache-2.0 for original project code. Its permissive terms and patent provisions suit enterprise/open interoperability. Redistributors must retain required license/notices, identify modifications where required and review patent/NOTICE conditions. See the full LICENSE; this is an engineering inventory, not a regulatory or legal certification.

## Runtime

No third-party runtime packages are adopted. Swift standard library/Foundation, SwiftUI, AVFoundation, Speech, CryptoKit and OS services are used under Apple's applicable SDK/platform terms; Apple framework source is not copied or relicensed. Signing/distribution remains subject to platform terms.

## Development only

- Python standard library/project scripts: no bundled third-party source.
- jsonschema 4.26.0: MIT. Its installed transitive dependencies must be captured with their license notices if redistributed; they are not vendored or shipped in this app. Typical dependencies include attrs (MIT), referencing (MIT), rpds-py (MIT), jsonschema-specifications (MIT). CI package resolution can evolve; pin transitive dependencies before distributing a test environment.
- GitHub checkout/setup-python actions: MIT-licensed upstream actions, fetched by CI and not included in application binaries. Review and pin immutable action SHAs before release hardening.

The supplied MeetingTranscriber-iPad archive has no license/provenance statement. It is excluded from Git along with the extracted prototype. Project code is newly authored; the review identified general public Apple API approaches to reuse, not permission to redistribute supplied implementation text.

Before adopting a dependency, record exact version/source/checksum, SPDX license, license/NOTICE texts, transitive obligations, binary/model rights, privacy behavior and security ownership. Copyleft/field-of-use/model-data terms require explicit compatibility review. Do not embed model weights without separately established distribution rights.
