package com.flutterguard

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class FlutterGuardScanTargetTest {
    @Test fun `untrusted project and unsaved file are blocked before CLI execution`() {
        assertTrue(FlutterGuardScanPolicy.blockedReason(false, false)!!.contains("未执行 CLI"))
        assertTrue(FlutterGuardScanPolicy.blockedReason(false, true)!!.contains("未执行 CLI"))
        assertTrue(FlutterGuardScanPolicy.blockedReason(true, true)!!.contains("尚未验证"))
        assertNull(FlutterGuardScanPolicy.blockedReason(true, false))
    }
    @Test fun `nested package uses nearest pubspec instead of IDE root`() {
        val root = Files.createTempDirectory("flutterguard-target-")
        try {
            Files.writeString(root.resolve("pubspec.yaml"), "name: outer")
            val nested = Files.createDirectories(root.resolve("packages/device/lib"))
            Files.writeString(nested.parent.resolve("pubspec.yaml"), "name: device")
            val file = Files.writeString(nested.resolve("api.dart"), "")
            assertEquals(nested.parent.toString(), FlutterGuardScanTarget.packageRoot(file.toString()))
        } finally { root.toFile().deleteRecursively() }
    }
    @Test fun `missing package root is not guessed`() {
        val root = Files.createTempDirectory("flutterguard-no-package-")
        try {
            assertNull(FlutterGuardScanTarget.packageRoot(root.resolve("a.dart").toString()))
        } finally { root.toFile().deleteRecursively() }
    }
}
