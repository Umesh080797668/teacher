import com.android.build.gradle.BaseExtension

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
subprojects {
    project.evaluationDependsOn(":app")

    if (project.name == "install_plugin") {
        fun configureNamespace() {
            val android = project.extensions.findByName("android") as? BaseExtension
            if (android != null && android.namespace == null) {
                android.namespace = "com.zaihui.installplugin"
            }
        }

        if (project.state.executed) {
            configureNamespace()
        } else {
            project.afterEvaluate {
                configureNamespace()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
