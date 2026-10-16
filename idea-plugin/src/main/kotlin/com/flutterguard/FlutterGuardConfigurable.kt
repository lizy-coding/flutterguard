package com.flutterguard

import com.intellij.codeInsight.daemon.DaemonCodeAnalyzer
import com.intellij.openapi.options.Configurable
import com.intellij.openapi.project.Project
import java.awt.BorderLayout
import javax.swing.JCheckBox
import javax.swing.JComponent
import javax.swing.JLabel
import javax.swing.JPanel
import javax.swing.JTabbedPane

class FlutterGuardConfigurable(private val project: Project) : Configurable {
    private var enabled: JCheckBox? = null
    override fun getDisplayName(): String = "FlutterGuard"
    override fun createComponent(): JComponent {
        val checkbox = JCheckBox("Enable FlutterGuard inspections for saved Dart files")
        enabled = checkbox
        reset()
        val tabs = JTabbedPane().apply {
            addTab("场景截图与使用说明", FlutterGuardDocumentation.view("guide"))
            addTab("更新记录", FlutterGuardDocumentation.view("changelog"))
        }
        return JPanel(BorderLayout()).apply {
            add(JPanel(BorderLayout()).apply {
                add(checkbox, BorderLayout.NORTH)
                add(JLabel("Uses the bundled CLI and the target package's flutterguard.yaml."), BorderLayout.SOUTH)
            }, BorderLayout.NORTH)
            add(tabs, BorderLayout.CENTER)
        }
    }
    override fun isModified(): Boolean = enabled?.isSelected?.let {
        it != FlutterGuardSettings.getInstance(project).enabled
    } ?: false
    override fun apply() {
        enabled?.let { FlutterGuardSettings.getInstance(project).enabled = it.isSelected }
        DaemonCodeAnalyzer.getInstance(project).restart()
    }
    override fun reset() {
        enabled?.isSelected = FlutterGuardSettings.getInstance(project).enabled
    }
    override fun disposeUIResources() { enabled = null }
}
