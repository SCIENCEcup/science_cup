import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("environment")

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "dk.sciencecup.app.dev"
            resValue(type = "string", name = "app_name", value = "Science Cup (Dev)")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "dk.sciencecup.app"
            resValue(type = "string", name = "app_name", value = "Science Cup")
        }
    }

    buildFeatures.resValues = true
}