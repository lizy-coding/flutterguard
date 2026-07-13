# Release v0.3.0 — Execution Prompt

## Summary
Version bump 0.2.0 → 0.3.0. Update docs, package metadata, CHANGELOG, compile, tag, push.

---

## Step 1: Version Bump

### 1a. `packages/flutterguard_cli/pubspec.yaml`
`version: 0.2.0` → `version: 0.3.0`

### 1b. `packages/flutterguard_cli/bin/flutterguard.dart`
`const _version = '0.2.0';` → `const _version = '0.3.0';`

---

## Step 2: Update `docs/FLUTTERGUARD_SPEC.md`

### 2a. Header line 6
`Version: M2 (Milestone 2) — Architecture Overhaul | Last Updated: 2026-05-17`
→ `Version: M3 (Milestone 3) — Incremental Scan + Rule Introspection | Last Updated: 2026-06-28`

### 2b. §1 Architecture Overview lines 44-63

Replace the entire flow diagram block with:

```
User runs: flutterguard scan [<path>] [--changed-only] [--base main]
  │
  ├── 1. ArgParser parses CLI flags
  ├── 2. ScanConfig.fromFile() loads YAML config
  ├── 3. FileCollector.collect() globs .dart files
  │       └── if --changed-only: FileCollector.getChangedFiles() filters by git diff
  ├── 4. Per-file scan: 11 rule classes analyze each file (13 rule IDs)
  │       ├── LargeUnitsRule              (file size, class size, build method size)
  │       ├── LifecycleResourceRule       (undisposed controllers/streams)
  │       ├── LayerViolationRule          (cross-layer import violations)
  │       ├── ModuleViolationRule         (cross-module import violations)
  │       ├── CircularDependencyRule      (file-level cycle detection)
  │       ├── MissingConstConstructorRule (widgets missing const constructor)
  │       ├── DeviceLifecycleRule         (init/teardown pairing)
  │       ├── MqttConnectionRule          (MQTT connect/disconnect, hardcoded URLs)
  │       ├── BleScanningRule             (BLE scan lifecycle, timeout)
  │       ├── IotSecurityRule             (hardcoded secrets, cleartext, insecure BLE)
  │       └── PubspecSecurityRule         (unbounded deps, deprecated packages)
  │       └── (changed-only: circular_dependency skipped)
  ├── 5. Issues sorted by risk level (high → medium → low)
  ├── 6. ReportGenerator generates output
  │       ├── Table → terminal stdout
  │       └── JSON → .flutterguard/report.json
  └── 7. CI gate check (exit 1 if fail threshold exceeded)
```

Also update line 71: `Rule class interface` table row.

### 2c. §4 CLI Contract — Add flags

After `--min-score` in the scan command block, add:

```
  --changed-only   Only scan .dart files changed since --base (default: false)
  --base           Git base ref for changed-only (default: main)
```

After the scan block, add:

```
flutterguard rules [options]
  --format (-f)   Output format: table | json (default: table)

flutterguard explain <rule-id>
```

In Exit Codes table, update Code 2 description:
```
| 2 | Scan/explain error (bad path, config parse error, unknown rule ID) |
```

### 2d. §6.1 JSON Report Schema — Add scanMode

After `"generatedAt"` line, insert:
```json
  "scanMode": "full|changed",
```

### 2e. §7 Static Rules Detail — Append IoT rules

After §7.8 (missing_const_constructor), append 5 new sections:

```
### 7.9 device_lifecycle (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**: For each class, check that device lifecycle methods have balanced init/teardown pairs:
- `initState` ↔ `dispose`
- `connect()` ↔ `disconnect()`
- `start()` ↔ `stop()`
- `listen()` / `subscribe()` ↔ `cancel()` / `unsubscribe()`

**Implementation**: Parse with `package:analyzer`, check method name presence for balanced pairs.

### 7.10 mqtt_connection (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**:
1. Find MQTT client field declarations (types matching `*MqttClient`, `*MQTT*`)
2. Check for `connect()` calls — verify `disconnect()` exists in dispose-like methods
3. Check for `subscribe()` calls — verify corresponding `unsubscribe()` calls exist
4. Check for hardcoded broker URLs (string literals containing `tcp://` or `mqtt://`)

### 7.11 ble_scanning (RiskLevel: medium, Domain: architecture, Priority: p1)

**Detection**:
1. Find BLE-related field declarations (types matching `*Ble*`, `*Bluetooth*`)
2. Check for `startScan()` calls — verify `stopScan()` exists in dispose-like methods
3. Check for `connect()` calls to BLE devices — verify `disconnect()` exists
4. Check that scan timeout is configured (look for timeout parameter in `startScan()`)

**Config**: `maxScanDurationMs: int (default: 10000)`

### 7.12 iot_security (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**:
| Check | Pattern | Severity |
|-------|---------|----------|
| Hardcoded password/token | String literal matching `password`/`token`/`secret` assignment | high |
| Cleartext MQTT | `tcp://` host or port `1883` in MQTT config | high |
| Cleartext HTTP | `http://` in IoT context packages | medium |
| Insecure BLE | BLE without `bond`/`pair` references | medium |

**Config**: `requireTls: bool (default: true)`

### 7.13 pubspec_security (RiskLevel: medium, Domain: standards, Priority: p2)

**Detection**: Analyzes the project's `pubspec.yaml` rather than individual `.dart` files.
| Check | Pattern | Severity |
|-------|---------|----------|
| Unbounded dependency | `^any` or no version constraint | medium |
| Outdated mqtt_client | `mqtt_client` version < 10.x.x | high |
| Outdated flutter_blue | `flutter_blue` (deprecated, use `flutter_blue_plus`) | high |
| Outdated http | `http` package < 1.x.x with cleartext patterns | medium |
```

### 2f. §8 Test Contracts — Full replace

Replace header: `### 8.1 CLI Tests (13 tests)` → `### 8.1 CLI Tests (37 tests)`

Append to the test table:

```
| changed_only_filters_files | temp git repo, 2 files, change 1 | scanMode=changed, only changed-file issues |
| changed_only_full_scan_when_no_git | non-git dir with changedOnly | scanMode=full |
| changed_only_skips_circular_dependency | cycle fixture with changedOnly | 0 circular_dependency issues |
| registry_contains_all_13_rules | RuleRegistry.all() | length == 13 |
| registry_find_returns_correct_meta | find('large_file') | non-null, correct id/domain |
| registry_find_unknown_returns_null | find('nonexistent') | null |
```

### 2g. §9 Evolution Roadmap — Mark M3 complete

Add after M2 entry:

```
### M3 (Completed v0.3.0) — Incremental Scan + Rule Introspection

Key deliverables:
- `--changed-only` incremental scan via git diff (skips cyclic dep in changed mode)
- `flutterguard rules` / `flutterguard explain` subcommands with RuleMeta registry
- 37 tests (26 base + 6 new + 5 existing)
- RuleMeta class + RuleRegistry for rule introspection
```

### 2h. §10 Known Limitations — Update

- Remove entries 5 and 6 (IoT MQTT/BLE and pubspec_security — now implemented)
- Add entry:
```
9. **Incremental scan**: `--changed-only` skips circular_dependency entirely
   in changed mode. Layer/module violations only detected if the changed file
   is the source of the illegal import. Pubspec security is not re-checked
   unless the changed file set includes pubspec.yaml.
```

### 2i. §12 IoT Domain Rules (Planned) — Delete entire section

The 5 IoT rules (12.1–12.5) are now documented in §7.9–§7.13. Delete the entire §12 section.

### 2j. Append §13 Rule Registry + §14 Incremental Scan

After the final line of the document (end of existing content), append:

```
---
## 13. Rule Registry & Explain Commands

### 13.1 RuleMeta
Data class in `lib/src/rule_meta.dart`:
- `id` — rule identifier
- `name` — Chinese display name
- `domain` — architecture / performance / standards
- `riskLevel` — high / medium / low
- `priority` — p0 / p1 / p2
- `purpose` — detection purpose
- `riskReason` — why this matters
- `badExample` — anti-pattern
- `fixSuggestion` — recommended fix
- `configKeys` — YAML config keys
- `cicdSafe` — whether suitable for CI gating

### 13.2 RuleRegistry
Singleton in `lib/src/rules/registry.dart`:
- `all()` → `List<RuleMeta>` (13 entries)
- `find(String id)` → `RuleMeta?`

### 13.3 CLI Commands
- `flutterguard rules` — table of all rules
- `flutterguard rules --format json` — JSON payload
- `flutterguard explain <rule-id>` — full detail; exit 2 on unknown ID

---
## 14. Incremental Scan (--changed-only)

### Flow
1. Check `.git/` exists in project path
2. `git diff --name-only <base> --diff-filter=ACMR`
3. `git ls-files --others --exclude-standard` (untracked files)
4. Union both sets, filter to .dart files
5. Feed filtered files to all rules
6. CircularDependencyRule force-disabled in changed-only mode

### Behavior Matrix
| Condition | Behavior | scanMode |
|-----------|----------|----------|
| Non-git dir | Fallback to full scan | full |
| --changed-only, 0 changes | "No Dart files found" exit | full |
| --changed-only, changes > 0 | Only scan changed .dart files | changed |
| --base not specified | Defaults to 'main' | — |
```

---

## Step 3: Update `AGENTS.md`

| Line | Change |
|------|--------|
| **Key Commands** | `(26 tests)` → `(37 tests)` |
| **Key Commands row 3** | After json row, add: `\| \`flutterguard scan --changed-only\` \| Incremental scan of git-changed files \|` |
| **Key Commands row 4** | After above: `\| \`flutterguard rules\` / \`flutterguard explain <id>\` \| List/describe rules \|` |
| **CLI Entry Point** | After last sentence, append: `Supports --changed-only incremental scan and rule introspection (rules/explain).` |
| **Source Layout rules/** | Before `pubspec_security.dart` line, add 2 lines: `rule_meta.dart` and `rules/registry.dart` |

---

## Step 4: Update `packages/flutterguard_cli/CHANGELOG.md`

Insert at top (before `## 0.1.1`):

```markdown
## 0.3.0 (2026-06-28)

### Incremental Scan (--changed-only)

- **cli:** New `--changed-only` flag — only scans `.dart` files changed since `--base` (default: `main`)
- **cli:** Integrated `git diff --name-only` + `git ls-files --others` for change detection
- **cli:** Non-git fallback: gracefully degrades to full scan
- **cli:** `circular_dependency` auto-disabled in changed-only mode
- **cli:** JSON report now includes `scanMode: full|changed` field

### Rule Introspection (rules / explain)

- **cli:** New `flutterguard rules` subcommand — list all 13 rules with ID, domain, name
- **cli:** New `flutterguard explain <rule-id>` subcommand — detailed purpose, risk, example, fix, config
- **cli:** New `RuleMeta` class in `lib/src/rule_meta.dart` — structured rule metadata
- **cli:** New `RuleRegistry` singleton in `lib/src/rules/registry.dart` — registry with `all()` and `find()`
- **cli:** Output supports both `table` (default) and `--format json`

### Tests

- **test:** 37 total tests (26 base + 6 new + 5 existing)
- **test:** 3 `changed-only` tests: git repo filter, non-git fallback, skip cycle
- **test:** 3 registry tests: all 13 rules, find by ID, unknown returns null

### Infrastructure

- **meta:** Version bumped to 0.3.0
- **meta:** `AGENTS.md` and `FLUTTERGUARD_SPEC.md` updated for new features
```

---

## Step 5: Delete ITERATION_1.md

Remove the plan file (no longer needed after release):

```bash
rm /Users/forest/code/flutterguard/ITERATION_1.md
```

---

## Step 6: Compile + Verify

```bash
dart run melos run analyze
dart run melos run test:cli
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
./flutterguard --version   # expect "flutterguard 0.3.0"
./flutterguard rules       # expect 13 rules
./flutterguard explain large_file  # expect full detail
```

---

## Step 7: git commit + tag + push

```bash
git add -A
git commit -m "cli: v0.3.0 — --changed-only + rules/explain"
git tag v0.3.0
git push origin develop
git push origin v0.3.0
```
