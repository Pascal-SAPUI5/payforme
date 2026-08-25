package de.wachowski.divido.core

/**
 * Why a request failed.
 *
 * The iOS app used to declare its load publishers as unable to fail, which
 * meant every failure had to be turned into a value before it could leave the
 * network layer: an HTTP 401 was dropped, a connection error became an empty
 * list. An empty list is exactly what a project with no bills looks like, so
 * nothing upstream could tell "the server rejected us" from "there is nothing
 * here" — and a changed password showed empty screens with no explanation.
 *
 * Divido starts with the distinction built in.
 */
sealed class LoadError : Exception() {
    /** Credentials rejected — usually the project password changed. */
    data object Unauthorized : LoadError()

    /** The server does not know this project. */
    data object NotFound : LoadError()

    /** Any other status the server returned. */
    data class Http(val status: Int) : LoadError()

    /** No usable connection. */
    data class Connection(val reason: String) : LoadError()

    /** The server answered, but not with something we could read. */
    data class InvalidResponse(val reason: String) : LoadError()

    companion object {
        fun forStatus(status: Int): LoadError = when (status) {
            401, 403 -> Unauthorized
            404 -> NotFound
            else -> Http(status)
        }
    }
}
