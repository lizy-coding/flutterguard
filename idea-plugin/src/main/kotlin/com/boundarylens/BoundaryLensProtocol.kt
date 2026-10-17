package com.boundarylens

import com.google.gson.JsonParser
import java.nio.file.Path

internal data class Finding(
    val ruleId: String,
    val title: String,
    val file: String,
    val line: Int,
    val severity: String,
    val message: String,
    val suggestion: String,
    val detail: String = "",
    val reason: String? = null,
)

internal data class ModuleCoverage(val status: String, val scope: String, val checkedFiles: Int, val totalFiles: Int)
internal data class RuleCoverage(val status: String, val scope: String, val reasons: List<String>, val checkedFiles: Int)
internal data class ScanReport(
    val findings: List<Finding>, val diagnostics: List<String>,
    val projectPath: String, val moduleCoverage: ModuleCoverage? = null,
    val ruleCoverage: Map<String, RuleCoverage> = emptyMap(),
) {
    fun forFile(target: String) = findings.filter { BoundaryLensProtocol.sameFile(it.file, target) }
    fun coverageSummary(): String = moduleCoverage?.let {
        val status = when (it.status) {
            "not_configured" -> "未配置模块约束"
            "disabled" -> "模块检查已禁用"
            "complete" -> "已检查本次范围"
            else -> "检查不完整，请核对模块入口配置及诊断"
        }
        "$status；scope=${it.scope}，${it.checkedFiles}/${it.totalFiles} 文件（仅本次范围，不代表全项目通过）"
    } ?: "CLI 未提供模块覆盖信息，无法判断模块检查是否完成"
    fun text(): String = buildString {
        appendLine("BoundaryLens — $projectPath")
        appendLine(coverageSummary())
        appendLine("${findings.size} findings；${diagnostics.size} diagnostics。无发现不等于整体架构通过。")
        for ((id, check) in ruleCoverage) {
            if (check.status != "disabled") appendLine("CHECK: $id ${check.status}; scope=${check.scope}; reasons=${check.reasons.joinToString()}")
        }
        for (diagnostic in diagnostics) appendLine("DIAGNOSTIC: $diagnostic")
        for (finding in findings) {
            appendLine("${finding.file}:${finding.line} [${finding.severity}] ${finding.ruleId}: ${finding.message}")
            finding.reason?.let { appendLine("  reason=$it") }
            if (finding.detail.isNotBlank()) appendLine("  ${finding.detail}")
            appendLine("  ${finding.suggestion}")
        }
    }
}

internal object BoundaryLensProtocol {
    fun parse(output: String): ScanReport {
        val root = JsonParser.parseString(output).asJsonObject
        require(root.get("schemaVersion")?.asString == "2.0.0") { "Unsupported report schema" }
        val projectPath = root.get("projectPath")?.asString ?: error("Missing projectPath")
        val issues = root.get("issues") ?: error("Missing issues")
        require(issues.isJsonArray) { "issues must be an array" }
        val findings = issues.asJsonArray.map { value ->
            val issue = value.asJsonObject
            val file = issue.get("file")?.asString ?: issue.get("fileRelative")?.asString
                ?: error("Missing finding path")
            val candidate = Path.of(file).let { if (it.isAbsolute) it else Path.of(projectPath).resolve(it) }
            val ruleId = issue.get("ruleId")?.asString ?: error("Missing ruleId")
            val line = issue.get("line")?.takeUnless { it.isJsonNull }?.asInt ?: 0
            val severity = issue.get("severity")?.asString ?: error("Missing severity")
            require(ruleId.isNotBlank() && severity in setOf("high", "medium", "low")) { "Invalid finding" }
            Finding(ruleId, issue.get("title")?.asString.orEmpty(), candidate.toString(), line,
                severity, issue.get("message")?.asString.orEmpty(), issue.get("suggestion")?.asString.orEmpty(),
                issue.get("detail")?.takeUnless { it.isJsonNull }?.asString.orEmpty(),
                issue.getAsJsonObject("metadata")?.get("reason")?.takeUnless { it.isJsonNull }?.asString)
        }
        val diagnostics = root.getAsJsonArray("diagnostics")?.map { value ->
            val item = value.asJsonObject
            "${item.get("stage")?.asString.orEmpty()}: ${item.get("message")?.asString.orEmpty()}"
        }.orEmpty()
        val coverage = root.getAsJsonObject("coverage")?.getAsJsonObject("moduleBoundary")?.let {
            val status = it.get("status")?.asString ?: error("Missing coverage status")
            val scope = it.get("scope")?.asString ?: error("Missing coverage scope")
            val checked = it.get("checkedFiles")?.asInt ?: error("Missing coverage checkedFiles")
            val total = it.get("totalFiles")?.asInt ?: error("Missing coverage totalFiles")
            require(status in setOf("not_configured", "disabled", "complete", "partial") &&
                scope in setOf("project", "file", "changed") && checked >= 0 && total >= checked) { "Invalid coverage" }
            ModuleCoverage(status, scope, checked, total)
        }
        val ruleCoverage = root.getAsJsonObject("coverage")?.getAsJsonObject("rules")?.entrySet()?.associate { entry ->
            val check = entry.value.asJsonObject
            val status = check.get("status")?.asString ?: error("Missing rule status")
            val scope = check.get("scope")?.asString ?: error("Missing rule scope")
            val checked = check.get("checkedFiles")?.asInt ?: error("Missing rule count")
            require(entry.key.isNotBlank() && status in setOf("disabled", "not_configured", "unsupported_scope", "not_applicable", "complete", "partial") &&
                scope in setOf("project", "file", "changed") && checked >= 0) { "Invalid rule coverage" }
            entry.key to RuleCoverage(status, scope, check.getAsJsonArray("reasons")?.map { it.asString }.orEmpty(), checked)
        }.orEmpty()
        return ScanReport(findings, diagnostics, projectPath, coverage, ruleCoverage)
    }

    fun sameFile(first: String, second: String) = canonical(Path.of(first)) == canonical(Path.of(second))

    private fun canonical(path: Path): Path =
        if (path.toFile().exists()) path.toRealPath() else path.toAbsolutePath().normalize()
}
