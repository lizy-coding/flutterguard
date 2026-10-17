package com.boundarylens

import org.junit.Assert.*
import org.junit.Test

class BoundaryLensProtocolTest {
    private fun report(issues: String, diagnostics: String = "[]", schema: String = "2.0.0") =
        """{"schemaVersion":"$schema","projectPath":"/project","issues":$issues,"diagnostics":$diagnostics}"""
    private fun issue(path: String, severity: String = "high", line: Int = 3) =
        """{"ruleId":"layer_violation","file":"$path","line":$line,"severity":"$severity","message":"invalid import"}"""

    @Test fun `complete report is retained and editor projection filters target`() {
        val parsed = BoundaryLensProtocol.parse(report("[${issue("/project/lib/a.dart")},${issue("/project/lib/b.dart")}]"))
        assertEquals(2, parsed.findings.size)
        assertEquals("layer_violation", parsed.forFile("/project/lib/a.dart").single().ruleId)
    }
    @Test fun `relative and normalized paths match target`() {
        val parsed = BoundaryLensProtocol.parse(report("[${issue("lib/x/../a.dart")}]"))
        assertEquals(1, parsed.forFile("/project/lib/a.dart").size)
    }
    @Test fun `empty findings with diagnostics remain visible`() {
        val parsed = BoundaryLensProtocol.parse(report("[]", """[{"stage":"parse","severity":"error","message":"failed"}]"""))
        assertTrue(parsed.findings.isEmpty())
        assertEquals(listOf("parse: failed"), parsed.diagnostics)
    }
    @Test fun `invalid reports are rejected instead of becoming a clean scan`() {
        for (output in listOf("", "{}", report("[]", schema = "1.0.0"), report("{}"), report("[${issue("/project/lib/a.dart", severity = "unknown")}]"))) {
            try { BoundaryLensProtocol.parse(output); fail("Accepted: $output") }
            catch (_: Exception) { }
        }
    }
    @Test fun `old CLI coverage is unknown instead of module pass`() {
        assertNull(BoundaryLensProtocol.parse(report("[]")).moduleCoverage)
        assertTrue(BoundaryLensProtocol.parse(report("[]")).coverageSummary().contains("无法判断"))
    }
    @Test fun `coverage states and scope remain explicit`() {
        for (status in listOf("not_configured", "disabled", "complete", "partial")) {
            val output = report("[]").dropLast(1) + ",\"coverage\":{\"moduleBoundary\":{\"status\":\"$status\",\"scope\":\"file\",\"checkedFiles\":1,\"totalFiles\":1}}}"
            val parsed = BoundaryLensProtocol.parse(output)
            assertEquals(status, parsed.moduleCoverage?.status)
            assertTrue(parsed.coverageSummary().contains("scope=file"))
            assertTrue(parsed.coverageSummary().contains("不代表全项目通过"))
        }
    }
    @Test fun `project findings without source lines remain in text report`() {
        val parsed = BoundaryLensProtocol.parse(report("[${issue("lib/a.dart", line = 0)},${issue("lib/b.dart")}]"))
        assertEquals(2, parsed.findings.size)
        assertTrue(parsed.text().contains("/project/lib/a.dart:0"))
        assertTrue(parsed.text().contains("/project/lib/b.dart:3"))
    }
    @Test fun `invalid coverage cannot masquerade as clean module check`() {
        val output = report("[]").dropLast(1) + ",\"coverage\":{\"moduleBoundary\":{\"status\":\"complete\",\"scope\":\"file\",\"checkedFiles\":2,\"totalFiles\":1}}}"
        try { BoundaryLensProtocol.parse(output); fail("Invalid coverage accepted") }
        catch (_: IllegalArgumentException) { }
    }
    @Test fun `supported resources include Windows executable suffix`() {
        assertEquals("boundarylens-windows-x64.exe", BoundaryLensNativeCli.resourceName("Windows 11", "amd64"))
        assertEquals("boundarylens-darwin-arm64", BoundaryLensNativeCli.resourceName("Mac OS X", "aarch64"))
        assertEquals("boundarylens-darwin-x64", BoundaryLensNativeCli.resourceName("Darwin", "x86_64"))
        assertEquals("boundarylens-linux-x64", BoundaryLensNativeCli.resourceName("Linux", "amd64"))
    }
    @Test fun `unsupported hosts are not guessed as Linux or x64`() {
        for ((os, arch) in listOf("FreeBSD" to "amd64", "Linux" to "aarch64", "Windows 11" to "arm64", "Mac OS X" to "riscv64")) {
            try { BoundaryLensNativeCli.resourceName(os, arch); fail("Accepted $os/$arch") }
            catch (_: IllegalStateException) { }
            catch (_: IllegalArgumentException) { }
        }
    }
    @Test fun `rule execution evidence survives report rendering`() {
        val json = """{"schemaVersion":"2.0.0","projectPath":"/project","issues":[],"coverage":{"rules":{"future_builtin":{"status":"partial","scope":"file","checkedFiles":1,"reasons":["source_input_unavailable"]}}}}"""
        val parsed = BoundaryLensProtocol.parse(json)
        assertEquals("partial", parsed.ruleCoverage["future_builtin"]?.status)
        assertTrue(parsed.text().contains("source_input_unavailable"))
        assertTrue(parsed.text().contains("future_builtin"))
    }
    @Test(expected = IllegalArgumentException::class) fun `invalid rule status is not displayed as success`() {
        BoundaryLensProtocol.parse("""{"schemaVersion":"2.0.0","projectPath":"/project","issues":[],"coverage":{"rules":{"x":{"status":"guessed","scope":"file","checkedFiles":1}}}}""")
    }

}
