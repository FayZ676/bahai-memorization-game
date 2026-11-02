plugins {
    id("org.jetbrains.kotlin.jvm")
    id("org.jetbrains.kotlin.plugin.serialization")
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    testImplementation(kotlin("test"))
    testImplementation("com.microsoft.onnxruntime:onnxruntime:1.22.0")
}

tasks.test {
    useJUnitPlatform()
    systemProperty("repo", rootDir.parentFile.absolutePath)
    System.getProperty("tokenizerOut")?.let { systemProperty("tokenizerOut", it) }
}

tasks.register<JavaExec>("bench") {
    group = "verification"
    description = "Replays every recitation bench take through the Kotlin session and the ONNX model."
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("com.faizififita.verses.logic.BenchKt")
    workingDir = rootDir.parentFile
    jvmArgs("-Xmx3g")
    args((project.findProperty("benchArgs") as String? ?: "").split(" ").filter { it.isNotEmpty() })
}
