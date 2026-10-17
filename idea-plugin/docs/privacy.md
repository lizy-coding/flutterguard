# BoundaryLens privacy and data handling

BoundaryLens 0.7.1. Updated 2026-10-17. Publisher support policy confirmed on
2026-10-17. This statement describes the implementation distributed with this version.

BoundaryLens processes saved local Dart source files and project configuration
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
(`boundarylens.xml`). It extracts the bundled executable to the operating
system's temporary directory, reuses it within the IDE process, and schedules
it for deletion on normal JVM exit. A crash can leave a temporary executable.

Source paths, configuration errors, and diagnostic text may appear in the
editor, notifications, or local IDEA logs. Exceptions can contain contextual
text. Review logs before sharing them in support or IDE error reports; no
anonymization guarantee is made. Diagnostic documents and screenshots are not
sent by BoundaryLens automatically.

## Voluntary support requests

The plugin does not send support requests automatically. If you choose to email
the publisher or open a GitHub issue, that service processes what you submit
under its own terms. Share only the minimum information needed; remove secrets,
personal data and proprietary source first. Publisher-side access to non-public
support emails and attachments is limited to forest.li.
No uniform fixed retention period is promised. Such materials are kept only
while needed for the support purpose; copies under the publisher's control are
deleted when that purpose ends, except where retention is required by law.
The sender can request deletion through the public contact below. Public GitHub
issues can be read by others; service-provider processing and copies outside
the publisher's control remain subject to those providers' terms.

Publisher supplied public name: forest.li.
Public Vendor and privacy contact: zhenyu_li1998@163.com.
The publisher supplied this public contact on 2026-10-10.
