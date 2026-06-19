allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build output off ExFAT to local APFS — Gradle requires POSIX file semantics
val localBuildRoot = "/private/tmp/bokses-gradle"
rootProject.layout.buildDirectory.set(file(localBuildRoot))
subprojects {
    project.layout.buildDirectory.set(file("$localBuildRoot/${project.name}"))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
