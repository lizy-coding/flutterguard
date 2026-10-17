package com.boundarylens

import java.io.File
import java.io.IOException
import java.util.Locale

internal object BoundaryLensNativeCli {
    private var cached: File? = null

    fun resourceName(osName: String, architecture: String): String {
        val os = osName.lowercase(Locale.ROOT)
        val arch = architecture.lowercase(Locale.ROOT)
        val osPart = when {
            os.startsWith("mac") || os.startsWith("darwin") -> "darwin"
            os.startsWith("windows") -> "windows"
            os.startsWith("linux") -> "linux"
            else -> error("Unsupported operating system: $osName")
        }
        val archPart = when (arch) {
            "aarch64", "arm64" -> "arm64"
            "amd64", "x86_64", "x64" -> "x64"
            else -> error("Unsupported architecture: $architecture")
        }
        require(osPart == "darwin" || archPart == "x64") { "No bundled CLI for $osPart-$archPart" }
        return "boundarylens-$osPart-$archPart" + if (osPart == "windows") ".exe" else ""
    }

    @Synchronized
    fun resolve(): File {
        cached?.takeIf { it.isFile && it.canExecute() }?.let { return it }
        val name = resourceName(System.getProperty("os.name"), System.getProperty("os.arch"))
        val input = javaClass.getResourceAsStream("/bin/$name") ?: error("Bundled CLI missing: $name")
        val temporary = File.createTempFile("boundarylens-", if (name.endsWith(".exe")) ".exe" else "")
        try {
            input.use { source -> temporary.outputStream().use(source::copyTo) }
            if (!temporary.setExecutable(true) && !temporary.canExecute()) throw IOException("CLI is not executable")
            temporary.deleteOnExit()
            cached = temporary
            return temporary
        } catch (error: Exception) {
            temporary.delete()
            throw error
        }
    }
}
