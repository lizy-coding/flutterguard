# FlutterGuard privacy and data handling

Prepared 2026-10-10 for the current local implementation. Review again against
the frozen release artifact before publishing this statement.

FlutterGuard processes saved local Dart source files and project configuration
through its bundled CLI. Architecture/state checks can read other included Dart
files selected by configuration; includes can also explicitly select paths
outside the package. Scanning one editor file is not necessarily the only source
read. This scope needs to be reviewed before automatic scanning of an untrusted
project. Findings and diagnostics are returned locally through stdout.
IDE scan mode does not write JSON/SARIF report files.

The reviewed plugin/CLI execution paths do not implement source upload,
accounts, cloud analysis, analytics, or telemetry. The offline usage guide reads
only bundled HTML and images. This does not describe the separate behavior of
IntelliJ IDEA, its update service, Dart/Flutter plugins, or other installed plugins.
No network packet-capture assurance is claimed by this source review.

The plugin stores its project-local enabled flag in IntelliJ's project storage
(`flutterguard.xml`). It extracts the bundled executable to the operating
system's temporary directory, reuses it within the IDE process, and schedules
it for deletion on normal JVM exit. A crash can leave a temporary executable.

Source paths, configuration errors, and diagnostic text may appear in the
editor, notifications, or local IDEA logs. Exceptions can contain contextual
text. Review logs before sharing them in support or IDE error reports; no
anonymization guarantee is made. Diagnostic documents and screenshots are not
sent by FlutterGuard automatically.

## Voluntary support requests

The plugin does not send support requests automatically. If you choose to email
the publisher or open a GitHub issue, that service processes what you submit
under its own terms. Share only the minimum information needed; remove secrets,
personal data and proprietary source first. The publisher's support-message
retention and handling process must be settled before this release draft is
used as the final public policy; this document specifies no retention period
for such voluntary submissions.

Publisher supplied public name: forest.li.
Public Vendor and privacy contact: zhenyu_li1998@163.com.
The publisher supplied this public contact on 2026-10-10. The final privacy
statement must be published at a reachable URL before submitting that URL to
Marketplace.
