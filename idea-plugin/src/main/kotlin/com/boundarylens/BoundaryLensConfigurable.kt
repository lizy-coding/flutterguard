package com.boundarylens

import com.intellij.codeInsight.daemon.DaemonCodeAnalyzer
import com.intellij.openapi.options.Configurable
import com.intellij.openapi.project.Project
import java.awt.BorderLayout
import java.awt.Dimension
import javax.swing.JCheckBox
import javax.swing.JComponent
import javax.swing.JLabel
import javax.swing.JPanel
import javax.swing.JTabbedPane

class BoundaryLensConfigurable(private val project: Project) : Configurable {
    private var enabled: JCheckBox? = null
    override fun getDisplayName(): String = "BoundaryLens"
    override fun createComponent(): JComponent {
        val checkbox = JCheckBox("Enable BoundaryLens inspections for saved Dart files")
        enabled = checkbox
        reset()
        val tabs = JTabbedPane().apply {
            addTab("场景截图与使用说明", BoundaryLensDocumentation.view("guide"))
            addTab("更新记录", BoundaryLensDocumentation.view("changelog"))
        }
        return JPanel(BorderLayout()).apply {
            minimumSize = Dimension(0, 0)
            add(JPanel(BorderLayout()).apply {
                add(checkbox, BorderLayout.NORTH)
                add(JLabel("Uses the bundled CLI and the target package's boundarylens.yaml."), BorderLayout.SOUTH)
            }, BorderLayout.NORTH)
            add(tabs, BorderLayout.CENTER)
        }
    }
    override fun isModified(): Boolean = enabled?.isSelected?.let {
        it != BoundaryLensSettings.getInstance(project).enabled
    } ?: false
    override fun apply() {
        enabled?.let { BoundaryLensSettings.getInstance(project).enabled = it.isSelected }
        DaemonCodeAnalyzer.getInstance(project).restart("BoundaryLens settings changed")
    }
    override fun reset() {
        enabled?.isSelected = BoundaryLensSettings.getInstance(project).enabled
    }
    override fun disposeUIResources() { enabled = null }
}
