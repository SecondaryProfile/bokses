allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect Gradle intermediates off ExFAT to local APFS — ExFAT lacks the POSIX file
// semantics (atomic rename, fcntl locking) that Gradle's incremental build requires.
val localBuildRoot = "/private/tmp/bokses-gradle"
rootProject.layout.buildDirectory.set(file(localBuildRoot))
subprojects {
    project.layout.buildDirectory.set(file("$localBuildRoot/${project.name}"))
}

// After assembling the :app module, copy the APK back to the Flutter-expected location
// on the ExFAT volume.  A plain file copy (no atomic rename, no locks) works fine on
// ExFAT, so this bridges the gap without needing any manual symlinks.
subprojects {
    afterEvaluate {
        tasks.matching { t ->
            t.name.matches(Regex("assemble(Debug|Release|Profile)"))
        }.configureEach {
            if (project.name == "app") {
                doLast {
                    val srcDir = project.layout.buildDirectory
                        .dir("outputs/flutter-apk").get().asFile
                    if (!srcDir.exists()) return@doLast
                    val dstDir = File(rootDir.parentFile, "build/app/outputs/flutter-apk")
                    dstDir.mkdirs()
                    srcDir.listFiles()?.forEach { f ->
                        f.copyTo(File(dstDir, f.name), overwrite = true)
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
