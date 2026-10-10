# FlutterGuard Context

FlutterGuard is an independent static-analysis tool and IDE integration for
Dart/Flutter projects. Consumer projects own their business contracts and gates.

## Language

**FlutterGuard**:
The independently maintained static-analysis product whose findings describe
rule-defined risks in a Dart/Flutter project.
_Avoid_: FlutterGuard Flow, runtime tracing SDK, observability SDK

**Scan**:
A static-analysis assessment of a project's Dart sources under an effective
configuration and selected scan scope.
_Avoid_: Runtime trace, telemetry session

**Scan scope**:
The set of Dart files selected for finding evaluation, such as project files,
Git-changed files, or one explicitly selected file.
_Avoid_: Entire repository by default, report filter

**Finding**:
A rule-owned observation identified by `ruleId`, `severity`, and `domain`, with
a source location and explanation.
_Avoid_: Confidence score, priority score

**Rule**:
A named detector contract with an identifier, metadata, default configuration,
and finding ownership.
_Avoid_: Independent metadata catalog, generic style lint

**Rule configuration**:
The effective enablement, severity, and rule-specific options assigned to a
rule for a scan.
_Avoid_: Framework mode, global state-manager switch

**Severity**:
The finding's canonical risk level: `high`, `medium`, or `low`.
_Avoid_: Priority, score, confidence

**Domain**:
The finding's canonical concern classification, such as architecture,
lifecycle, IoT security, or state management.
_Avoid_: Severity, framework selection

**Architecture boundary**:
An allowed dependency relationship between configured layers or modules.
_Avoid_: Formatting convention, directory size limit

**Suppression**:
An explicit source annotation that excludes a matching finding from the visible
results of a scan.
_Avoid_: Baseline, disabled rule

**Baseline**:
A recorded set of existing findings excluded from later visible results by
matching finding identity.
_Avoid_: Suppression comment, disabled detector

**Severity gate**:
The acceptance threshold that determines whether visible findings fail a scan.
_Avoid_: Scanner crash, invalid report

**IDE inspection**:
An editor annotation derived from a FlutterGuard finding for a selected source
file.
_Avoid_: Separate rule engine, public Dart scanner API
