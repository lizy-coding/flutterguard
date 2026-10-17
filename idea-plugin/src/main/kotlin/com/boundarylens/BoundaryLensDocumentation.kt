package com.boundarylens

import com.intellij.ui.components.JBScrollPane
import java.awt.Dimension
import java.net.URL
import javax.swing.JComponent
import javax.swing.JEditorPane
import javax.swing.text.html.HTMLDocument
import javax.swing.text.html.HTMLEditorKit

internal object BoundaryLensDocumentation {
    fun page(name: String): URL {
        require(name in setOf("guide", "changelog"))
        return requireNotNull(javaClass.getResource("/documentation/$name.html")) {
            "Bundled BoundaryLens documentation missing: $name"
        }
    }

    fun editor(name: String): JEditorPane {
        val url = page(name)
        return object : JEditorPane() {
            override fun getScrollableTracksViewportWidth(): Boolean = true
        }.apply {
            isEditable = false
            putClientProperty(JEditorPane.HONOR_DISPLAY_PROPERTIES, true)
            editorKit = HTMLEditorKit()
            (document as HTMLDocument).base = url
            text = url.readText(Charsets.UTF_8)
            caretPosition = 0
        }
    }

    fun view(name: String): JComponent {
        return JBScrollPane(editor(name)).apply {
            preferredSize = Dimension(640, 500)
            minimumSize = Dimension(0, 0)
        }
    }
}
