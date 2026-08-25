package de.wachowski.divido.core

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpStatusCode
import io.ktor.http.URLBuilder
import io.ktor.http.appendPathSegments
import io.ktor.util.encodeBase64

/**
 * Talks to a Cospend or iHateMoney server.
 *
 * The two backends differ in more than a base path:
 *
 *  - Cospend puts the credentials **in the URL**:
 *    `{server}/index.php/apps/cospend/api/projects/{token}/{password}/{endpoint}`
 *    and sends no Authorization header at all.
 *  - iHateMoney addresses the project by id and authenticates with HTTP Basic,
 *    base64 of `{projectId}:{password}`.
 *
 * Getting this wrong yields a 401 that looks like a wrong password, which is
 * why the shape of each request is pinned down by tests.
 */
class DividoApi(private val client: HttpClient) {

    suspend fun loadBills(project: Project): List<Bill> = request(project, "bills")

    suspend fun loadMembers(project: Project): List<Person> = request(project, "members")

    private suspend inline fun <reified T> request(project: Project, endpoint: String): T {
        val response: HttpResponse = try {
            client.get(urlFor(project, endpoint)) {
                authHeaderFor(project)?.let { (name, value) -> headers.append(name, value) }
            }
        } catch (e: LoadError) {
            throw e
        } catch (e: Exception) {
            throw LoadError.Connection(e.message ?: e::class.simpleName ?: "unknown")
        }

        if (response.status != HttpStatusCode.OK) {
            throw LoadError.forStatus(response.status.value)
        }

        return try {
            response.body()
        } catch (e: Exception) {
            throw LoadError.InvalidResponse(e.message ?: "could not decode the response")
        }
    }

    internal fun urlFor(project: Project, endpoint: String): String =
        URLBuilder(project.url).apply {
            when (project.backend) {
                // Cospend carries token and password as path segments.
                ProjectBackend.COSPEND ->
                    appendPathSegments(
                        project.backend.staticPath.split("/") + listOf(project.token, project.password, endpoint)
                    )
                ProjectBackend.IHATEMONEY ->
                    appendPathSegments(
                        project.backend.staticPath.split("/") + listOf(project.projectId, endpoint)
                    )
            }
        }.buildString()

    internal fun authHeaderFor(project: Project): Pair<String, String>? = when (project.backend) {
        // Credentials already sit in the path; a header would be redundant.
        ProjectBackend.COSPEND -> null
        ProjectBackend.IHATEMONEY -> {
            val credentials = "${project.projectId}:${project.password}".encodeBase64()
            "Authorization" to "Basic $credentials"
        }
    }
}
