package com.boundarylens

import com.intellij.ide.trustedProjects.TrustedProjects
import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.CapturingProcessHandler
import com.intellij.lang.annotation.AnnotationHolder
import com.intellij.lang.annotation.ExternalAnnotator
import com.intellij.lang.annotation.HighlightSeverity
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.fileEditor.FileDocumentManager
import com.intellij.openapi.progress.ProcessCanceledException
import com.intellij.openapi.progress.ProgressManager
import com.intellij.openapi.util.TextRange
import com.intellij.psi.PsiFile

class BoundaryLensExternalAnnotator :
    ExternalAnnotator<BoundaryLensExternalAnnotator.Request, BoundaryLensExternalAnnotator.Result>() {

    data class Request(val path: String, val workDir: String, val stamp: Long, val unsaved: Boolean, val target: String = path, val trusted: Boolean = false)
    class Result internal constructor(val request: Request, internal val report: ScanReport? = null, val problem: String? = null)

    private val logger = Logger.getInstance(BoundaryLensExternalAnnotator::class.java)

    override fun collectInformation(file: PsiFile): Request? {
        if (!BoundaryLensSettings.getInstance(file.project).enabled) return null
        val virtualFile = file.virtualFile ?: return null
        if (virtualFile.fileSystem.protocol != "file" || virtualFile.extension != "dart") return null
        val document = file.viewProvider.document ?: return null
        return Request(virtualFile.path, file.project.basePath ?: return null, document.modificationStamp,
            FileDocumentManager.getInstance().isDocumentUnsaved(document), trusted = TrustedProjects.isProjectTrusted(file.project))
    }

    override fun doAnnotate(request: Request): Result {
        BoundaryLensScanPolicy.blockedReason(request.trusted, request.unsaved)?.let {
            return Result(request, problem = it)
        }
        return try {
            ProgressManager.checkCanceled()
            val command = GeneralCommandLine(BoundaryLensNativeCli.resolve().absolutePath,
                "scan", request.target, "--format", "json", "--stdout", "--no-color", "--fail-on", "none")
                .withWorkDirectory(request.workDir).withCharset(Charsets.UTF_8)
            val handler = CapturingProcessHandler(command)
            val indicator = ProgressManager.getInstance().progressIndicator
            val output = if (indicator == null) handler.runProcess(30_000, true)
                else handler.runProcessWithProgressIndicator(indicator, 30_000, true)
            if (output.isCancelled) throw ProcessCanceledException()
            if (output.isTimeout) return Result(request, problem = "扫描超时（30 秒）；当前文件尚未验证。")
            if (output.exitCode !in 0..1) return Result(request,
                problem = "扫描失败（exit ${output.exitCode}）：${output.stderr.trim().take(300)}")
            Result(request, report = BoundaryLensProtocol.parse(output.stdout))
        } catch (cancelled: ProcessCanceledException) {
            throw cancelled
        } catch (error: Exception) {
            logger.warn("BoundaryLens scan failed", error)
            Result(request, problem = "扫描失败：${error.message.orEmpty().take(300)}")
        }
    }

    override fun apply(file: PsiFile, result: Result, holder: AnnotationHolder) {
        if (!BoundaryLensSettings.getInstance(file.project).enabled) return
        val document = file.viewProvider.document ?: return
        if (file.virtualFile?.path != result.request.path || document.modificationStamp != result.request.stamp) return
        if (!result.request.unsaved && FileDocumentManager.getInstance().isDocumentUnsaved(document)) return
        val coverageWarning = result.report?.takeIf { it.moduleCoverage?.status != "complete" }?.coverageSummary()
        val problems = listOfNotNull(result.problem, coverageWarning) + result.report?.diagnostics.orEmpty()
        if (problems.isNotEmpty()) {
            holder.newAnnotation(HighlightSeverity.WARNING, "[BoundaryLens] ${problems.first()}")
                .range(TextRange(0, document.getLineEndOffset(0)))
                .tooltip(escape(problems.joinToString("\n"))).create()
        }
        for (finding in result.report?.forFile(result.request.path).orEmpty()) {
            // Project-level findings without a line have no reliable editor anchor.
            if (finding.line !in 1..document.lineCount) continue
            val index = finding.line - 1
            val severity = when (finding.severity) {
                "high" -> HighlightSeverity.ERROR
                "medium" -> HighlightSeverity.WARNING
                else -> HighlightSeverity.WEAK_WARNING
            }
            holder.newAnnotation(severity, "[${finding.ruleId}] ${finding.message}")
                .range(TextRange(document.getLineStartOffset(index), document.getLineEndOffset(index)))
                .tooltip(escape("${finding.title}\n\n${finding.suggestion}")).create()
        }
    }

    private fun escape(text: String): String = text.replace("&", "&amp;").replace("<", "&lt;")
        .replace(">", "&gt;").replace("\n", "<br>")
}

internal object BoundaryLensScanPolicy {
    fun blockedReason(trusted: Boolean, unsaved: Boolean): String? = when {
        !trusted -> "项目未受信任；未执行 CLI，检查尚未完成。请先在 IDEA 中核对并信任项目。"
        unsaved -> "保存文件后扫描；当前编辑内容尚未验证。"
        else -> null
    }
}
