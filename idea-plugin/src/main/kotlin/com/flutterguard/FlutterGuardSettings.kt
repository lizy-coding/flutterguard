package com.flutterguard

import com.intellij.openapi.components.PersistentStateComponent
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.State
import com.intellij.openapi.components.Storage
import com.intellij.openapi.project.Project
import com.intellij.util.xmlb.XmlSerializerUtil

@State(name = "FlutterGuardSettings", storages = [Storage("flutterguard.xml")])
@Service(Service.Level.PROJECT)
class FlutterGuardSettings : PersistentStateComponent<FlutterGuardSettings> {
    var enabled: Boolean = true
    var scanOnSave: Boolean = true
    var failOnSeverity: String = "low"
    var customArgs: String = ""

    override fun getState(): FlutterGuardSettings = this

    override fun loadState(state: FlutterGuardSettings) =
        XmlSerializerUtil.copyBean(state, this)

    companion object {
        fun getInstance(project: Project): FlutterGuardSettings =
            project.getService(FlutterGuardSettings::class.java)
    }
}
