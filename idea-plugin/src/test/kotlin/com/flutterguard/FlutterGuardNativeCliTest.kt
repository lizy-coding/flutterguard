package com.flutterguard

import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.nio.file.Files
import java.util.concurrent.TimeUnit

class FlutterGuardNativeCliTest {
    @Test fun `bundled CLI permits public entry and reports complete file scope`() {
        scanFixture("../device/device.dart", 0)
    }
    @Test fun `bundled CLI rejects private entry and exit one retains report`() {
        scanFixture("../device/src/session.dart", 1)
    }

    private fun scanFixture(importPath: String, expectedExit: Int) {
        val resource = FlutterGuardNativeCli.resourceName(System.getProperty("os.name"), System.getProperty("os.arch"))
        assumeTrue(javaClass.getResource("/bin/$resource") != null)
        val binary = FlutterGuardNativeCli.resolve()
        assertEquals(binary, FlutterGuardNativeCli.resolve())
        val project = Files.createTempDirectory("flutterguard-idea-test-")
        var process: Process? = null
        try {
            Files.writeString(project.resolve("pubspec.yaml"), "name: idea_fixture\nenvironment:\n  sdk: ^3.11.0\n")
            Files.writeString(project.resolve("flutterguard.yaml"), """
                architecture:
                  modules:
                    - name: device
                      path: lib/device/**
                      entry_points: [lib/device/device.dart]
                      allowed_deps: []
                    - name: presentation
                      path: lib/presentation/**
                      entry_points: [lib/presentation/page.dart]
                      allowed_deps: [device]
            """.trimIndent())
            val device = Files.createDirectories(project.resolve("lib/device/src"))
            Files.writeString(device.resolve("session.dart"), "class DeviceSession {}\n")
            Files.writeString(device.parent.resolve("device.dart"), "export 'src/session.dart';\n")
            val target = Files.createDirectories(project.resolve("lib/presentation")).resolve("page.dart")
            Files.writeString(target, "import '$importPath';\nDeviceSession? session;\n")
            process = ProcessBuilder(binary.absolutePath, "scan", target.toString(), "--format", "json",
                "--stdout", "--no-color", "--fail-on", "high").directory(project.toFile()).start()
            val output = process.inputStream.bufferedReader().readText()
            assertTrue(process.waitFor(30, TimeUnit.SECONDS))
            assertEquals(process.errorStream.bufferedReader().readText(), expectedExit, process.exitValue())
            val report = FlutterGuardProtocol.parse(output)
            assertEquals("complete", report.moduleCoverage?.status)
            assertEquals("file", report.moduleCoverage?.scope)
            if (expectedExit == 1) {
                assertEquals("module_violation", report.findings.single().ruleId)
                assertEquals("private_entry", report.findings.single().reason)
                assertEquals(1, report.findings.single().line)
            } else assertTrue(report.findings.isEmpty())
            assertFalse(Files.exists(project.resolve(".flutterguard")))
        } finally {
            process?.takeIf { it.isAlive }?.destroyForcibly()
            project.toFile().deleteRecursively()
        }
    }
}
