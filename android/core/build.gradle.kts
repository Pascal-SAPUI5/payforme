// Plain Kotlin/JVM on purpose, not an Android module: model, API contract and
// HTTP client need no Android SDK, so they build and test on any machine with a
// JDK. Ktor's MockEngine plays the same role here that MockURLProtocol plays in
// the iOS tests — a full request/response round trip without a server.
plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("io.ktor:ktor-client-core:2.3.12")
    implementation("io.ktor:ktor-client-content-negotiation:2.3.12")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.12")
    implementation("io.ktor:ktor-client-auth:2.3.12")

    testImplementation(kotlin("test"))
    testImplementation("io.ktor:ktor-client-mock:2.3.12")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}

// Java 17, nicht 21. Das app-Modul bindet dieses hier ein, und Androids D8
// erwartet Bytecode auf Java-17-Niveau. Zwei verschiedene Toolchains im selben
// Abhaengigkeitsbaum bauen zwar durch, koennen zur Laufzeit aber brechen.
kotlin { jvmToolchain(17) }
tasks.test { useJUnitPlatform() }
