package com.boundarylens

import com.intellij.openapi.components.PersistentStateComponent
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.State
import com.intellij.openapi.components.Storage
import com.intellij.openapi.project.Project
import com.intellij.util.xmlb.XmlSerializerUtil

@State(name = "BoundaryLensSettings", storages = [Storage("boundarylens.xml")])
@Service(Service.Level.PROJECT)
class BoundaryLensSettings : PersistentStateComponent<BoundaryLensSettings> {
    var enabled: Boolean = true

    override fun getState(): BoundaryLensSettings = this

    override fun loadState(state: BoundaryLensSettings) =
        XmlSerializerUtil.copyBean(state, this)

    companion object {
        fun getInstance(project: Project): BoundaryLensSettings =
            project.getService(BoundaryLensSettings::class.java)
    }
}
