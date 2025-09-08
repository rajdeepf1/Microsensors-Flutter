// android/build.gradle.kts

import org.gradle.api.tasks.Delete

// NOTE: Use literal versions in buildscript classpath for reliability with Kotlin DSL.
// AGP 8.1.0 works fine with Gradle 8.10.2.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10")
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Preserve your custom build dir location
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure :app is evaluated before others if your project expects it
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task using resolved build dir
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
