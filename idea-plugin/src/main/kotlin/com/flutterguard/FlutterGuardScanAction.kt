package com.flutterguard

import com.intellij.codeInsight.daemon.DaemonCodeAnalyzer
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.actionSystem.ActionUpdateThread
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.actionSystem.CommonDataKeys
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.application.ReadAction
import com.intellij.openapi.progress.ProgressIndicator
import com.intellij.openapi.progress.Task
import com.intellij.openapi.project.Project
import com.intellij.openapi.fileEditor.FileEditorManager
import com.intellij.testFramework.LightVirtualFile
import com.intellij.openapi.fileTypes.PlainTextFileType
import java.nio.file.Files
import java.nio.file.Path

open class FlutterGuardScanAction(private val packageScan: Boolean = false) : AnAction() {
    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun update(event: AnActionEvent) {
        val file = event.getData(CommonDataKeys.VIRTUAL_FILE)
        event.presentation.isEnabledAndVisible = event.project != null &&
            file?.extension == "dart" && file.fileSystem.protocol == "file"
    }

    override fun actionPerformed(event: AnActionEvent) {
        val project = event.project ?: return
        val file = event.getData(CommonDataKeys.PSI_FILE) ?: return
        val annotator = FlutterGuardExternalAnnotator()
        val snapshot = ReadAction.compute<FlutterGuardExternalAnnotator.Request?, RuntimeException> {
            annotator.collectInformation(file)
        }
        if (snapshot == null) {
            notify(project, "未扫描：请启用 FlutterGuard 并选择本地 Dart 文件。", NotificationType.WARNING)
            return
        }
        if (!snapshot.trusted) {
            notify(project, "项目未受信任；未执行 CLI，检查尚未完成。请先在 IDEA 中核对并信任项目。", NotificationType.WARNING)
            return
        }
        val packageRoot = if (packageScan) FlutterGuardScanTarget.packageRoot(snapshot.path) else null
        if (packageScan && packageRoot == null) {
            notify(project, "未扫描：当前 Dart 文件没有祖先 pubspec.yaml；无法确定目标包。", NotificationType.WARNING)
            return
        }
        val request = snapshot.copy(target = packageRoot ?: snapshot.path, workDir = packageRoot ?: snapshot.workDir)
        object : Task.Backgroundable(project, "FlutterGuard: ${file.name}", true) {
            override fun run(indicator: ProgressIndicator) {
                val result = annotator.doAnnotate(request)
                ApplicationManager.getApplication().invokeLater {
                    if (project.isDisposed || !file.isValid) return@invokeLater
                    if (file.viewProvider.document?.modificationStamp != request.stamp) {
                        notify(project, "文件已变化，本次结果已丢弃，请重新扫描。", NotificationType.WARNING)
                        return@invokeLater
                    }
                    val problems = listOfNotNull(result.problem) + result.report?.diagnostics.orEmpty()
                    if (problems.isNotEmpty()) {
                        notify(project, "${file.name}：${problems.first().take(300)}", NotificationType.WARNING)
                    } else {
                        val report = result.report
                        val count = if (packageScan) report?.findings?.size else report?.forFile(request.path)?.size
                        notify(project, "${if (packageScan) "包范围" else "当前文件"}：$count findings。${report?.coverageSummary()}",
                            if (report?.moduleCoverage?.status == "complete") NotificationType.INFORMATION else NotificationType.WARNING)
                    }
                    result.report?.let { report ->
                        val display = "目标：${request.target}\n${if (packageScan) "包扫描" else "单文件扫描"}；仅已保存的磁盘内容。\n\n" + report.text()
                        val reportFile = LightVirtualFile("FlutterGuard report.txt", PlainTextFileType.INSTANCE, display)
                        reportFile.isWritable = false
                        FileEditorManager.getInstance(project).openFile(reportFile, true)
                    }
                    DaemonCodeAnalyzer.getInstance(project).restart(file)
                }
            }
        }.queue()
    }

    private fun notify(project: Project, message: String, type: NotificationType) {
        val safe = message.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        NotificationGroupManager.getInstance().getNotificationGroup("FlutterGuard")
            .createNotification("FlutterGuard", safe, type).notify(project)
    }
}

class FlutterGuardScanPackageAction : FlutterGuardScanAction(true)

internal object FlutterGuardScanTarget {
    fun packageRoot(file: String): String? {
        var directory = Path.of(file).toAbsolutePath().normalize().parent
        while (directory != null) {
            if (Files.isRegularFile(directory.resolve("pubspec.yaml"))) return directory.toString()
            directory = directory.parent
        }
        return null
    }
}
