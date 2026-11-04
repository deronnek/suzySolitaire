// Converts SVGs to Android VectorDrawables with the converter Android Studio uses (see scripts/import-cards.py).  Run
// with the Android app's Gradle wrapper: android/gradlew -p scripts/svg2vector run --args="<svg folder> <out folder>"
plugins {
    kotlin("jvm") version "2.4.21"
    application
}

repositories {
    google()
    mavenCentral()
}

dependencies {
    // Matches the Android Gradle plugin in android/gradle/libs.versions.toml (9.4.1)
    implementation("com.android.tools:sdk-common:32.4.1")
}

kotlin {
    jvmToolchain(21)
}

application {
    mainClass.set("MainKt")
}
