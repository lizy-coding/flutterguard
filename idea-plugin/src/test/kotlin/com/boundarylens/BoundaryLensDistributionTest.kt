package com.boundarylens

import org.junit.Assert.*
import org.junit.Test
import javax.xml.parsers.DocumentBuilderFactory
import com.google.gson.JsonParser
import java.security.MessageDigest

class BoundaryLensDistributionTest {
    @Test fun `native runtime license originals match the pinned inventory`() {
        val inventory = requireNotNull(javaClass.getResource("/documentation/license-inventory.json"))
        val components = JsonParser.parseString(inventory.readText()).asJsonObject
            .getAsJsonArray("nativeRuntimeComponents")
        assertTrue("Native runtime inventory must not be empty", components.size() > 0)
        for (value in components) {
            val item = value.asJsonObject
            val resource = requireNotNull(javaClass.getResource("/documentation/${item.get("licenseResource").asString}"))
            val hash = MessageDigest.getInstance("SHA-256").digest(resource.readBytes())
                .joinToString("") { "%02x".format(it.toInt() and 0xff) }
            assertEquals(item.get("name").asString, item.get("sha256").asString, hash)
        }
    }
    @Test fun `first release declares macOS ARM64 delivery dependencies`() {
        val input = requireNotNull(javaClass.getResourceAsStream("/META-INF/plugin.xml"))
        val document = input.use { DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(it) }
        val nodes = document.getElementsByTagName("depends")
        val platform = (0 until nodes.length).map { nodes.item(it).textContent.trim() }
            .filter { it.startsWith("com.intellij.modules.os.") || it.startsWith("com.intellij.modules.arch.") }
        assertEquals(setOf("com.intellij.modules.os.mac", "com.intellij.modules.arch.arm64"), platform.toSet())
        assertEquals(2, platform.size)
    }

    @Test fun `first release contains only its declared native payload`() {
        assertNotNull(javaClass.getResource("/bin/boundarylens-darwin-arm64"))
        for (name in listOf("boundarylens-darwin-x64", "boundarylens-linux-x64", "boundarylens-windows-x64.exe")) {
            assertNull("Undeclared payload $name", javaClass.getResource("/bin/$name"))
        }
    }
}
