# FlutterGuard plugin release maintenance

Canonical repository: https://github.com/lizy-coding/flutterguard.
This repository maintains the IDEA plugin and the CLI it bundles together.
Public publisher name: forest.li; contact: zhenyu_li1998@163.com.

## Repository mapping

| Responsibility | Authoritative local source |
|---|---|
| Detection and rule definitions | `../lib/src/rules/` and its sole registry |
| IntelliJ integration / metadata | `src/main/kotlin/com/flutterguard/`, `src/main/resources/META-INF/plugin.xml` |
| Installation and scenarios | `README.md`, `examples/inspection_scenarios/` |
| Offline guide / real screenshots | `docs/guide.html`, `docs/screenshots/` |
| What's New and bundled history | `docs/changelog.html` |
| License and privacy | `../LICENSE`, `docs/eula.md`, `docs/privacy.md` |
| Third-party license evidence | `docs/third-party-notices.txt`, `docs/license-inventory.json` |
| Native packaging / plugin gates | `../scripts/idea_plugin_preflight.sh` |
| Marketplace upload helper | `../scripts/idea_plugin_publish.sh` |
| Submission preparation and dated evidence | `release-review/` |

The plugin owns IDE I/O and presentation. The CLI owns detectors and defaults;
consumer projects own business contracts and acceptance. Keep this public tool
independent of any consumer repository.

## Public entry points

- Project website and source: https://github.com/lizy-coding/flutterguard
- Support and bug reports: https://github.com/lizy-coding/flutterguard/issues
- Published artifacts and release records: https://github.com/lizy-coding/flutterguard/releases
- CI evidence after a remote run: https://github.com/lizy-coding/flutterguard/actions

These URLs identify the maintenance destinations; they do not prove that the
current local implementation, agreements or screenshots have been pushed.
Marketplace source/license/privacy links must refer to files at the actual
public release revision and be checked for anonymous access before submission.
Do not invent a Marketplace listing URL before a listing is created.

## Release sequence

1. Review the local diff and resolve the open submission gates in
   [marketplace-submission.md](release-review/marketplace-submission.md).
   Freeze the source revision, version, IDE range and native platform matrix.
2. Build native executables from that same revision and SDK. Run the applicable
   CLI gates and the plugin preflight; validate the exact final ZIP with Plugin
   Verifier and host smoke tests. Record artifact hash and supported targets.
3. Review the canonical changelog, screenshots, EULA, privacy and third-party
   notices. Preserve dated audits as evidence snapshots, not current acceptance.
4. After explicit authorization to publish repository changes, commit/push the
   reviewed scope and confirm public source and agreement links. Inspect tag and
   release workflow effects before creating/pushing a release tag.
5. After all gates pass, the account owner completes Marketplace declarations
   and accepts the current Developer Agreement. Obtain authorization for the
   actual Marketplace upload; upload success and approval are separate events.
6. Record the public Marketplace URL, approved version, compatibility range and
   GitHub Release artifact/source mapping once those events actually occur.

Local preparation does not authorize push, tag creation, GitHub Releases,
Marketplace upload or agreement acceptance. The current repository association
uses the existing `origin` at `git@github.com:lizy-coding/flutterguard.git`.
