# Marketplace submission preparation

Prepared 2026-10-10. Status: **HOLD — not ready to upload**.
Updated 2026-10-17 for the first macOS Apple Silicon distribution; dated audits
remain historical. [Remediation](2026-10-16-release-remediation.md) closed the
internal rule-contract, typed-option and local UI gaps. Final public source,
publisher decisions and submission materials remain independent gates.
This document records proposed submission materials, not acceptance of an
agreement, a published release, or JetBrains approval.

The maintenance repository is [lizy-coding/flutterguard](https://github.com/lizy-coding/flutterguard).
See [RELEASING.md](../RELEASING.md) for source, documentation and release mappings.
This association is prepared locally; the current materials have not been pushed.

## Proposed listing fields

| Field | Prepared value / remaining action |
|---|---|
| Name / ID | BoundaryLens / com.boundarylens; check uniqueness in Marketplace |
| Public contact | zhenyu_li1998@163.com |
| Vendor website / source | https://github.com/lizy-coding/flutterguard |
| Vendor legal identity | Public name forest.li confirmed; verify individual/entity identity against account |
| License | Existing MIT License and docs/eula.md notice; owner verifies Vendor profile at submission |
| Privacy | Publisher confirmed the support policy on 2026-10-17; publish docs/privacy.md and verify its public URL |
| Description / What's New | plugin.xml English primary description / docs/changelog.html |
| Screenshots | Offline legacy images are labeled auxiliary. Do not upload them as current module-entry marketing screenshots; capture the new set manually when available |
| Compatibility | First release: macOS ARM64 only, IDEA261; OS/architecture dependency selectors and native host gate |

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
- Verify packaged EULA, MIT, privacy and notices; record final SHA-256. Use only
  accurate current-workflow media in the listing. Build success is not approval.
- Submit only after these gates and publisher declarations are complete. Record
  upload receipt and eventual approval separately.

## Current implementation scope (2026-10-17)

- Default build and verifier target IDEA2026.1.5, Java21, Kotlin2.3; current
  tested host is IU-261.27258.48 / Dart510.0.0 / macOS ARM64.
- Platform dependencies are preserved for Marketplace delivery filtering.
  Official Verifier `-ignore-os-arch` checks API compatibility independently;
  preflight separately checks the descriptor selectors, matching host, Mach-O
  ARM64, native version and bundled CLI smoke. This flag alone does not prove
  installation filtering or another OS works.
- Root CLI dependencies are locked in pubspec.lock; release commands enforce it.
- No remote push, release tag, account declaration or Marketplace upload is
  authorized by this local preparation. The publisher confirmed the actual
  support policy on 2026-10-17; a local policy file is not a verified public URL.
- New module screenshots improve onboarding but are not treated as a universal
  Marketplace screenshot mandate: the explicit screenshot requirement in the
  checked approval guideline applies to color-scheme/theme plugins. This scanner
  can prepare an accurate English listing without claiming the old images show
  the new default workflow. The offline guide retains labeled historical images.

Platform distribution reference checked 2026-10-17:
[OS/architecture-specific versions](https://plugins.jetbrains.com/docs/marketplace/os-architecture-specific-plugin-versions.html).

## Official references checked 2026-10-10

- [EULA requirements](https://plugins.jetbrains.com/docs/marketplace/eula.html)
- [Legal agreements](https://plugins.jetbrains.com/docs/marketplace/legal-agreements.html)
- [Approval guidelines](https://plugins.jetbrains.com/docs/marketplace/jetbrains-marketplace-approval-guidelines.html)
- [New plugin upload](https://plugins.jetbrains.com/docs/marketplace/uploading-a-new-plugin.html)

The detailed evidence and remaining blockers are in
2026-10-10-marketplace-audit.md. No upload or agreement acceptance has occurred.
