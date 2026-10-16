# Marketplace submission preparation

Prepared 2026-10-10. Status: **HOLD — not ready to upload**.
This document records proposed submission materials, not acceptance of an
agreement, a published release, or JetBrains approval.

The maintenance repository is [lizy-coding/flutterguard](https://github.com/lizy-coding/flutterguard).
See [RELEASING.md](../RELEASING.md) for source, documentation and release mappings.
This association is prepared locally; the current materials have not been pushed.

## Proposed listing fields

| Field | Prepared value / remaining action |
|---|---|
| Name / ID | FlutterGuard / com.flutterguard; check uniqueness in Marketplace |
| Public contact | zhenyu_li1998@163.com |
| Vendor website / source | https://github.com/lizy-coding/flutterguard |
| Vendor legal identity | Public name forest.li confirmed; verify individual/entity identity against account |
| License | Existing MIT License; accompanying docs/eula.md is a release draft |
| Privacy | docs/privacy.md; publish the frozen statement and verify its public URL |
| Description / What's New | plugin.xml English primary description / docs/changelog.html |
| Screenshots | Five manually captured images in docs/screenshots/; check final media presentation |
| Compatibility | Do not infer support from default Gradle settings; freeze IDE/OS/architecture range |

The source, EULA, privacy and notices URLs must point to the publicly accessible
release revision. Local files and proposed repository paths are not verified
public links. Do not mark the local 0.7.1 iteration as already released.

## Agreements and responsible actions

1. Developer EULA: publish the actual licensor identity and the existing MIT
   terms with the accompanying notice. Do not substitute JetBrains' unmodified
   Standard EULA or introduce proprietary restrictions inconsistent with MIT.
2. Marketplace Developer Agreement: the account owner must review and accept
   the current agreement on JetBrains' website before uploading. Preparing this
   repository does not accept that agreement.
3. Vendor/trader declarations: the publisher supplies truthful account and
   trader/non-trader information based on their actual circumstances. An email
   address, free price, or open-source license does not determine this status.
4. Privacy statement: verify it against the final CLI/plugin, including scope,
   local logs and optional support submissions. A future telemetry/upload
   feature requires a fresh privacy/consent review before being enabled.
5. Third-party rights: verify final native SDK/VM and dependency notices, plus
   ownership of names, icons and media. The current dependency inventory alone
   does not close the native distribution review.

## Technical gates before upload

- Freeze and publicly expose a reviewable source revision/version.
- Build the declared native targets from that revision; do not copy old dist
  over the repaired local binary solely because version strings match.
- Resolve IDE project-trust / configured outside-package read behavior.
- Use consistent IDE compatibility targets and obtain a final Plugin Verifier
  verdict for the exact submitted ZIP; complete host smoke tests and preflight.
- Verify packaged EULA, MIT, privacy, notices and all five replacement screenshots;
  record final SHA-256. Build success is not approval.
- Submit only after these gates and publisher declarations are complete. Record
  upload receipt and eventual approval separately.

## Official references checked 2026-10-10

- [EULA requirements](https://plugins.jetbrains.com/docs/marketplace/eula.html)
- [Legal agreements](https://plugins.jetbrains.com/docs/marketplace/legal-agreements.html)
- [Approval guidelines](https://plugins.jetbrains.com/docs/marketplace/jetbrains-marketplace-approval-guidelines.html)
- [New plugin upload](https://plugins.jetbrains.com/docs/marketplace/uploading-a-new-plugin.html)

The detailed evidence and remaining blockers are in
2026-10-10-marketplace-audit.md. No upload or agreement acceptance has occurred.
