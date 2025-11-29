allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // FIX: Removed 'project.evaluationDependsOn(":app")' to prevent "project already evaluated" errors.
    
    // --- THE FIX FOR VOSK (KOTLIN VERSION) ---
    afterEvaluate {
        // We check if the 'android' extension exists on the project
        val android = extensions.findByName("android")
        // We cast it to the BaseExtension type to access the 'namespace' property
        if (android is com.android.build.gradle.BaseExtension) {
            if (android.namespace == null) {
                // If namespace is missing (like in vosk_flutter), set it to the group name
                android.namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}