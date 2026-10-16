package com.flutterguard

import org.junit.Assert.*
import org.junit.Test

class FlutterGuardProtocolTest {
    private fun report(issues: String, diagnostics: String = "[]", schema: String = "2.0.0") =
        """{"schemaVersion":"$schema","projectPath":"/project","issues":$issues,"diagnostics":$diagnostics}"""
    private fun issue(path: String, severity: String = "high", line: Int = 3) =
        """{"ruleId":"layer_violation","file":"$path","line":$line,"severity":"$severity","message":"invalid import"}"""

    @Test fun `complete report is retained and editor projection filters target`() {
        val parsed = FlutterGuardProtocol.parse(report("[${issue("/project/lib/a.dart")},${issue("/project/lib/b.dart")}]"))
        assertEquals(2, parsed.findings.size)
        assertEquals("layer_violation", parsed.forFile("/project/lib/a.dart").single().ruleId)
    }
    @Test fun `relative and normalized paths match target`() {
        val parsed = FlutterGuardProtocol.parse(report("[${issue("lib/x/../a.dart")}]"))
        assertEquals(1, parsed.forFile("/project/lib/a.dart").size)
    }
    @Test fun `empty findings with diagnostics remain visible`() {
        val parsed = FlutterGuardProtocol.parse(report("[]", """[{"stage":"parse","severity":"error","message":"failed"}]"""))
        assertTrue(parsed.findings.isEmpty())
        assertEquals(listOf("parse: failed"), parsed.diagnostics)
    }
    @Test fun `invalid reports are rejected instead of becoming a clean scan`() {
        for (output in listOf("", "{}", report("[]", schema = "1.0.0"), report("{}"), report("[${issue("/project/lib/a.dart", severity = "unknown")}]"))) {
            try { FlutterGuardProtocol.parse(output); fail("Accepted: $output") }
            catch (_: Exception) { }
        }
    }
    @Test fun `old CLI coverage is unknown instead of module pass`() {
        assertNull(FlutterGuardProtocol.parse(report("[]")).moduleCoverage)
        assertTrue(FlutterGuardProtocol.parse(report("[]")).coverageSummary().contains("无法判断"))
    }
    @Test fun `coverage states and scope remain explicit`() {
        for (status in listOf("not_configured", "disabled", "complete", "partial")) {
            val output = report("[]").dropLast(1) + ",\"coverage\":{\"moduleBoundary\":{\"status\":\"$status\",\"scope\":\"file\",\"checkedFiles\":1,\"totalFiles\":1}}}"
            val parsed = FlutterGuardProtocol.parse(output)
            assertEquals(status, parsed.moduleCoverage?.status)
            assertTrue(parsed.coverageSummary().contains("scope=file"))
            assertTrue(parsed.coverageSummary().contains("不代表全项目通过"))
        }
    }
    @Test fun `project findings without source lines remain in text report`() {
        val parsed = FlutterGuardProtocol.parse(report("[${issue("lib/a.dart", line = 0)},${issue("lib/b.dart")}]"))
        assertEquals(2, parsed.findings.size)
        assertTrue(parsed.text().contains("/project/lib/a.dart:0"))
        assertTrue(parsed.text().contains("/project/lib/b.dart:3"))
    }
    @Test fun `invalid coverage cannot masquerade as clean module check`() {
        val output = report("[]").dropLast(1) + ",\"coverage\":{\"moduleBoundary\":{\"status\":\"complete\",\"scope\":\"file\",\"checkedFiles\":2,\"totalFiles\":1}}}"
        try { FlutterGuardProtocol.parse(output); fail("Invalid coverage accepted") }
        catch (_: IllegalArgumentException) { }
    }
    @Test fun `supported resources include Windows executable suffix`() {
        assertEquals("flutterguard-windows-x64.exe", FlutterGuardNativeCli.resourceName("Windows 11", "amd64"))
        assertEquals("flutterguard-darwin-arm64", FlutterGuardNativeCli.resourceName("Mac OS X", "aarch64"))
        assertEquals("flutterguard-darwin-x64", FlutterGuardNativeCli.resourceName("Darwin", "x86_64"))
        assertEquals("flutterguard-linux-x64", FlutterGuardNativeCli.resourceName("Linux", "amd64"))
    }
    @Test fun `unsupported hosts are not guessed as Linux or x64`() {
        for ((os, arch) in listOf("FreeBSD" to "amd64", "Linux" to "aarch64", "Windows 11" to "arm64", "Mac OS X" to "riscv64")) {
            try { FlutterGuardNativeCli.resourceName(os, arch); fail("Accepted $os/$arch") }
            catch (_: IllegalStateException) { }
            catch (_: IllegalArgumentException) { }
        }
    }
}
