import org.jetbrains.intellij.platform.gradle.IntelliJPlatformType
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    java
    id("org.jetbrains.intellij.platform") version "2.2.1"
    id("org.jetbrains.kotlin.jvm") version (System.getenv("BOUNDARYLENS_KOTLIN_VERSION") ?: "2.3.0")
}

group = "com.boundarylens"
version = System.getenv("PLUGIN_VERSION") ?: file("../pubspec.yaml").readLines()
    .first { it.startsWith("version:") }.substringAfter(':').trim()

repositories {
    mavenCentral()
    intellijPlatform {
        defaultRepositories()
    }
}

dependencies {
    intellijPlatform {
        val localIde = providers.gradleProperty("localIdePath").orNull
        if (localIde != null) local(localIde) else intellijIdeaUltimate("2026.1.5")
        pluginVerifier("1.410")
    }
    testImplementation("junit:junit:4.13.2")
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks {
    processResources {
        from("docs") { into("documentation") }
        from("../LICENSE") {
            into("META-INF")
            rename { "LICENSE.txt" }
        }
    }
    test {
        // Protocol tests use the SDK's Gson/Kotlin libraries without starting an IDE.
        classpath += sourceSets.main.get().compileClasspath
        doFirst {
            // These are plain adapter tests, not IntelliJ fixture tests. The IDE
            // bootstrap classloader/filesystem flags are neither needed nor portable.
            jvmArgumentProviders.clear()
            systemProperties.clear()
            setJvmArgs(emptyList<String>())
        }
    }
    withType<KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_21)
    }
    verifyPlugin {
        offline.set(gradle.startParameter.isOffline)
        // Avoid clearing a shared ~/.pluginVerifier extraction directory used
        // by another project or audit. A supplied home can hold offline Dart.
        systemProperty("plugin.verifier.home.dir", providers.gradleProperty("verifierHomePath")
            .getOrElse(layout.buildDirectory.dir("pluginVerifierHome").get().asFile.absolutePath))
    }
}

intellijPlatform {
    buildSearchableOptions = false

    pluginConfiguration {
        version = project.version.toString()
        changeNotes = file("docs/changelog.html").readText()
        ideaVersion {
            sinceBuild = providers.gradleProperty("pluginSinceBuild").getOrElse("261")
        }
    }

    signing {
        certificateChain = providers.environmentVariable("CERTIFICATE_CHAIN")
        privateKey = providers.environmentVariable("PRIVATE_KEY")
        password = providers.environmentVariable("PRIVATE_KEY_PASSWORD")
    }

    publishing {
        token = providers.environmentVariable(
            "ORG_GRADLE_PROJECT_intellijPublishToken",
        )
    }

    pluginVerification {
        // These constraints are delivery selectors, not class-bearing plugins.
        // The release preflight checks descriptor, Mach-O target and host smoke.
        // Official Verifier flag: JetBrains/intellij-plugin-verifier 1.409+.
        freeArgs.add("-ignore-os-arch")
        ides {
            val auditIde = providers.gradleProperty("verifierIdePath").orNull
            if (auditIde != null) local(file(auditIde))
            else ide(IntelliJPlatformType.IntellijIdeaUltimate, "2026.1.5")
        }
    }
}
