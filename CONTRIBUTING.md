# Contributing

Discuss material API/security changes in an issue before implementation. Use synthetic fixtures only; never upload company meetings, patient data, credentials or restricted source. Contributions must be yours to license under Apache-2.0. No CLA is currently required; contributors retain copyright.

Keep changes focused, add behavior tests, run the README checks and document hardware-only gaps. Protocol changes need schema fixtures, Swift/Kotlin interoperability analysis and a compatibility decision. Mobile capture/speech changes need physical-device evidence before production claims. Introduce no runtime dependency without license/provenance/security review and updating THIRD_PARTY_NOTICES.md.

Pull requests receive maintainer review. Security-sensitive changes require an independent reviewer before release. Report vulnerabilities according to SECURITY.md. Do not claim certification or autonomous regulatory accuracy.

# TestFlight builds

Before creating a new TestFlight archive, increase both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `scripts/generate_project.py`, then run `python3 scripts/generate_project.py`. Check the version and build number in the archive before uploading; do not reuse an uploaded pair.
