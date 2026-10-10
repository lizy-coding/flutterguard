package com.flutterguard

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.intellij.lang.annotation.AnnotationHolder
import com.intellij.lang.annotation.ExternalAnnotator
import com.intellij.lang.annotation.HighlightSeverity
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.util.TextRange
import com.intellij.psi.PsiFile
import java.io.File
import java.util.concurrent.TimeUnit

class FlutterGuardExternalAnnotator :
    ExternalAnnotator<PsiFile, List<FlutterGuardExternalAnnotator.Finding>>() {

    data class Finding(
        val ruleId: String = "",
        val title: String = "",
        val file: String = "",
        @SerializedName("fileRelative") val fileRelative: String = "",
        val line: Int = 0,
        val severity: String = "medium",
        val domain: String = "",
        val message: String = "",
        val suggestion: String = "",
    )

    data class Report(
        val issues: List<Finding> = emptyList(),
    )

    private val logger = Logger.getInstance(FlutterGuardExternalAnnotator::class.java)

    override fun collectInformation(file: PsiFile): PsiFile = file

    override fun doAnnotate(collectedInfo: PsiFile): List<Finding> {
        val project = collectedInfo.project
        val settings = FlutterGuardSettings.getInstance(project)
        if (!settings.enabled) return emptyList()

        val basePath = project.basePath ?: return emptyList()
        val binary = resolveBinary() ?: run {
            logger.warn("flutterguard binary not found for ${currentPlatform()}")
            return emptyList()
        }
        val filePath = collectedInfo.virtualFile.path

        return try {
            val process = ProcessBuilder(
                binary.absolutePath,
                "scan",
                filePath,
                "--format",
                "json",
                "--stdout",
                "--no-color",
                "--fail-on",
                "none",
            ).directory(File(basePath)).start()

            if (!process.waitFor(30, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                logger.warn("FlutterGuard scan timed out for $filePath")
                return emptyList()
            }

            val output = process.inputStream.bufferedReader().readText()
            val errorOutput = process.errorStream.bufferedReader().readText()
            if (process.exitValue() > 1) {
                logger.warn(
                    "FlutterGuard scan failed with exit ${process.exitValue()}: $errorOutput",
                )
                return emptyList()
            }
            if (output.isBlank()) return emptyList()

            Gson().fromJson(output, Report::class.java).issues
        } catch (error: Exception) {
            logger.warn("FlutterGuard scan failed", error)
            emptyList()
        }
    }

    override fun apply(
        file: PsiFile,
        findings: List<Finding>,
        holder: AnnotationHolder,
    ) {
        val document = file.viewProvider.document ?: return
        for (finding in findings) {
            val lineIndex = (finding.line - 1).coerceIn(0, document.lineCount - 1)
            val start = document.getLineStartOffset(lineIndex)
            val end = document.getLineEndOffset(lineIndex)
            val severity = when (finding.severity) {
                "high" -> HighlightSeverity.ERROR
                "medium" -> HighlightSeverity.WARNING
                else -> HighlightSeverity.WEAK_WARNING
            }
            holder.newAnnotation(
                severity,
                "[${finding.ruleId}] ${finding.message}",
            )
                .range(TextRange(start, end))
                .tooltip("${finding.title}\n\n${finding.suggestion}")
                .create()
        }
    }

    private fun resolveBinary(): File? {
        val platform = currentPlatform()
        val resourcePath = "/bin/flutterguard-$platform"
        val input = javaClass.getResourceAsStream(resourcePath) ?: return null
        return try {
            val suffix = if (platform.startsWith("windows-")) ".exe" else ""
            val temporary = File.createTempFile("flutterguard-", suffix)
            temporary.deleteOnExit()
            input.use { source ->
                temporary.outputStream().use(source::copyTo)
            }
            temporary.setExecutable(true)
            temporary
        } catch (error: Exception) {
            logger.warn("Failed to extract native binary", error)
            null
        }
    }

    private fun currentPlatform(): String {
        val os = System.getProperty("os.name").lowercase()
        val arch = System.getProperty("os.arch").lowercase()
        val osPart = when {
            os.contains("mac") || os.contains("darwin") -> "darwin"
            os.contains("win") -> "windows"
            else -> "linux"
        }
        val archPart = when {
            arch.contains("aarch64") || arch.contains("arm64") -> "arm64"
            else -> "x64"
        }
        return "$osPart-$archPart"
    }
}
