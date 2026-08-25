package de.wachowski.divido.core

import kotlinx.serialization.Serializable

@Serializable
data class Person(
    val id: Int,
    val name: String,
    val weight: Double = 1.0,
    val activated: Boolean = true,
)
