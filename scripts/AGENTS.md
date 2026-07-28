# Release scripts

| file | platform | role |
|---|---|---|
| `package_release.sh` | macOS + Linux | `dart compile exe` → `dist/flutterguard-{os}-{arch}` |
| `package_release.ps1` | Windows | same, PowerShell native |
| `release_preflight.sh` | any | pre-release checks (analyze, test, scan, publish dry-run) |
| `idea_plugin_preflight.sh` | macOS/Linux | validate plugin project, sync native bins, gradle check, verifier |
| `idea_plugin_publish.sh` | macOS/Linux | preflight gate + gradle `publishPlugin` to JetBrains Marketplace |

No Dart deps. Read version from root pubspec.yaml. Output to dist/.

See root AGENTS.md §Per-layer constraints for MUST NOT list.
