allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// flutter_pcm_sound (pemutar intercom) masih dikompilasi terhadap API 33,
// sementara AndroidX yang ditariknya menuntut minimal 34 dan build gagal di
// :flutter_pcm_sound:checkDebugAarMetadata. Yang dinaikkan hanya API tempat
// ia dikompilasi — minSdk dan perilakunya tidak berubah. Hapus begitu
// pluginnya sendiri sudah memakai 34 ke atas.
subprojects {
    if (name == "flutter_pcm_sound") {
        // afterEvaluate: kalau lebih awal, blok android{} milik plugin itu
        // sendiri menimpanya kembali ke 33.
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
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
