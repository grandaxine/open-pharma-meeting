# Security policy

This is a pre-release project, not certified or approved for regulated production use. Do not submit patient data, credentials, recordings or transcripts in public issues. Use GitHub private vulnerability reporting if enabled; until a confidential channel is published, request one without disclosing exploit details or personal data.

## Boundaries and assumptions

The MVP assumes a non-compromised device with passcode, functioning OS sandbox and enterprise-approved configuration. It does not implement SSO, token storage, tenant enforcement, DLP, retention automation or remote wipe. No credentials are currently collected or stored. Corporate networking is not enabled. Explicit export bypasses app-local controls by design and warns the user.

Data Protection and backup exclusion are applied in code; locked-device behavior requires hardware verification. CompleteUnlessOpen permits an already-open audio file to remain writable after lock; reopening/atomic metadata replacement can fail. Finalized audio retains this class for capture/recovery; a future retention job should strengthen it according to company policy. Protected speech temporary files are best-effort deleted; process termination may leave files. No content logging or analytics is included.

Private is default independently for audio, transcript and reports. A local evaluator is only defense in depth. Production backends MUST enforce authenticated tenant isolation, subject/resource/action authorization, policy revisions and processing approval. A policy change must take effect on future requests and queued processing, and generate a content-free audit event.

Revoking access cannot retract previously downloaded data, screenshots, exports or external backups. Company MDM, managed sharing, retention, device lock, remote wipe and employee procedures are required to govern those copies. The app does not claim it can enforce remote erasure.

## MASVS baseline mapping

Use [OWASP MASVS](https://mas.owasp.org/MASVS/) as the mobile security baseline, not a certification claim.

| Area | MVP implementation/evidence | Remaining verification |
| --- | --- | --- |
| STORAGE | Application Support, protection classes, backup exclusion, atomic writes | Device lock/backup/temp-file checks; retention and lifecycle audit |
| CRYPTO | OS Data Protection; SHA-256 for corruption detection | Independent review; hash is not authenticity |
| AUTH | No remote identity or token collection | OIDC/PKCE, native Keychain/Keystore, server tenant/resource enforcement |
| NETWORK | No production network client or default server | TLS, approved endpoint/discovery trust, redirect restrictions, token audience tests |
| PLATFORM | Native permission prompts and consent acknowledgment | MDM, screen exposure, accessibility and background checks |
| CODE | Host tests, generic iOS build and CI definitions | Hardware/UI tests, dependency pinning review, fuzzing and independent audit |
| RESILIENCE | Decode/hash checks and recovery journal | Compromised devices outside MVP guarantees; enterprise response plan |
| PRIVACY | Local processing, no analytics, explicit export | Consent/legal basis/retention approval by deploying company |

For future identity use [OAuth 2.0 Security BCP, RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html): authorization code + PKCE S256, external browser, verified redirects, issuer/audience validation, scoped short-lived tokens, no client secret embedded in mobile apps. Enterprise SecureStorage adapters must use native Keychain/Keystore protection. Do not log tokens, content, prompts or personal identifiers.

Company backends own model/provider selection, prompts, versions, residency, retention, approval workflows, processing audit and compliance assessment. Safety-related detections are review signals for authorized humans, never autonomous regulatory decisions.
