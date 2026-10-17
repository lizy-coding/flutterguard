package com.boundarylens

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class BoundaryLensScanTargetTest {
    @Test fun `untrusted project and unsaved file are blocked before CLI execution`() {
        assertTrue(BoundaryLensScanPolicy.blockedReason(false, false)!!.contains("未执行 CLI"))
        assertTrue(BoundaryLensScanPolicy.blockedReason(false, true)!!.contains("未执行 CLI"))
        assertTrue(BoundaryLensScanPolicy.blockedReason(true, true)!!.contains("尚未验证"))
        assertNull(BoundaryLensScanPolicy.blockedReason(true, false))
    }
    @Test fun `nested package uses nearest pubspec instead of IDE root`() {
        val root = Files.createTempDirectory("boundarylens-target-")
        try {
            Files.writeString(root.resolve("pubspec.yaml"), "name: outer")
            val nested = Files.createDirectories(root.resolve("packages/device/lib"))
            Files.writeString(nested.parent.resolve("pubspec.yaml"), "name: device")
            val file = Files.writeString(nested.resolve("api.dart"), "")
            assertEquals(nested.parent.toString(), BoundaryLensScanTarget.packageRoot(file.toString()))
        } finally { root.toFile().deleteRecursively() }
    }
    @Test fun `missing package root is not guessed`() {
        val root = Files.createTempDirectory("boundarylens-no-package-")
        try {
            assertNull(BoundaryLensScanTarget.packageRoot(root.resolve("a.dart").toString()))
        } finally { root.toFile().deleteRecursively() }
    }
}
