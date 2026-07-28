package com.flutterguard

import com.intellij.openapi.project.Project
import com.intellij.openapi.startup.ProjectActivity

class FlutterGuardStartupActivity : ProjectActivity {
    override suspend fun execute(project: Project) {
        // Services and the external annotator initialize lazily.
    }
}
