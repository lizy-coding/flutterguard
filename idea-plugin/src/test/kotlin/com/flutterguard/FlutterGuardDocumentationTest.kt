package com.flutterguard

import org.junit.Assert.*
import org.junit.Test
import java.net.URL
import javax.imageio.ImageIO
import javax.swing.SwingUtilities
import javax.swing.text.html.HTML
import javax.swing.text.html.HTMLDocument

class FlutterGuardDocumentationTest {
    @Test fun `guide renders HTML and resolves images against bundled page URL`() {
        SwingUtilities.invokeAndWait {
            val editor = FlutterGuardDocumentation.editor("guide")
            assertTrue(editor.scrollableTracksViewportWidth)
            assertEquals("text/html", editor.contentType)
            val document = editor.document as HTMLDocument
            assertEquals(FlutterGuardDocumentation.page("guide"), document.base)
            val visibleText = document.getText(0, document.length)
            assertTrue(visibleText.contains("FlutterGuard 使用指南"))
            assertFalse(visibleText.contains("<h1>"))
            val images = document.getIterator(HTML.Tag.IMG)
            var count = 0
            while (images.isValid) { count++; images.next() }
            assertEquals(5, count)
        }
    }
    @Test fun `offline guide resolves all five actual screenshots`() {
        val page = FlutterGuardDocumentation.page("guide")
        val html = page.readText()
        val images = Regex("src=\"([^\"]+)\"").findAll(html).map { it.groupValues[1] }.toList()
        assertEquals(5, images.size)
        for (relative in images) {
            assertFalse(relative.startsWith("http"))
            val image = ImageIO.read(URL(page, relative))
            assertNotNull(relative, image)
            assertTrue("Screenshot too narrow: $relative", image.width >= 640)
            assertTrue("Screenshot too short: $relative", image.height >= 360)
        }
    }

    @Test fun `versioned changes include additions fixes and validation boundaries`() {
        val html = FlutterGuardDocumentation.page("changelog").readText()
        for (text in listOf("0.7.1", "2026-10-10", "新增", "修复", "调整", "未发布", "验证范围")) {
            assertTrue(text, html.contains(text))
        }
    }
}
