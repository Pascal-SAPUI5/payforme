package de.wachowski.divido.core

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.HttpRequestData
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The request shape is the contract with two servers that authenticate in
 * completely different ways. Getting it wrong produces a 401 indistinguishable
 * from a wrong password, so both paths are pinned down here rather than
 * discovered on a real server.
 */
class DividoApiTest {

    private val cospend = Project(
        name = "Studienfahrt", projectId = "studienfahrt", password = "geheim",
        token = "9da50e41", url = "https://cloud.example.de", backend = ProjectBackend.COSPEND,
    )
    private val ihatemoney = Project(
        name = "Spongebob house", projectId = "spongebob-house", password = "squarepants",
        token = "spongebob-house", url = "https://ihatemoney.org", backend = ProjectBackend.IHATEMONEY,
    )

    private var lastRequest: HttpRequestData? = null

    private fun client(handler: MockEngine.Companion.() -> Unit = {}, respond: (HttpRequestData) -> Any = { "[]" }) =
        HttpClient(MockEngine { request ->
            lastRequest = request
            when (val r = respond(request)) {
                is String -> respond(r, HttpStatusCode.OK,
                    headersOf("Content-Type", ContentType.Application.Json.toString()))
                is HttpStatusCode -> respondError(r)
                else -> error("unsupported")
            }
        }) {
            install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
        }

    // MARK: URL shape

    @Test
    fun `cospend puts token and password in the path`() = runTest {
        DividoApi(client()).loadBills(cospend)
        assertEquals(
            "https://cloud.example.de/index.php/apps/cospend/api/projects/9da50e41/geheim/bills",
            lastRequest?.url.toString(),
        )
    }

    @Test
    fun `iHateMoney addresses the project by id`() = runTest {
        DividoApi(client()).loadBills(ihatemoney)
        assertEquals("https://ihatemoney.org/api/projects/spongebob-house/bills",
                     lastRequest?.url.toString())
    }

    // MARK: Authentication

    @Test
    fun `iHateMoney authenticates with basic auth over the project id`() = runTest {
        DividoApi(client()).loadMembers(ihatemoney)
        val header = lastRequest?.headers?.get("Authorization")
        // base64("spongebob-house:squarepants")
        assertEquals("Basic c3BvbmdlYm9iLWhvdXNlOnNxdWFyZXBhbnRz", header)
    }

    @Test
    fun `cospend sends no authorization header`() = runTest {
        DividoApi(client()).loadMembers(cospend)
        assertNull(lastRequest?.headers?.get("Authorization"),
                   "the credentials are already in the path; a header would be redundant")
    }

    // MARK: Failures reach the caller

    @Test
    fun `a rejected password surfaces as Unauthorized`() = runTest {
        val api = DividoApi(client(respond = { HttpStatusCode.Unauthorized }))
        assertEquals(LoadError.Unauthorized, assertFailsWith<LoadError> { api.loadBills(cospend) })
    }

    @Test
    fun `a missing project surfaces as NotFound`() = runTest {
        val api = DividoApi(client(respond = { HttpStatusCode.NotFound }))
        assertEquals(LoadError.NotFound, assertFailsWith<LoadError> { api.loadBills(cospend) })
    }

    @Test
    fun `any other status is passed through verbatim`() = runTest {
        val api = DividoApi(client(respond = { HttpStatusCode.InternalServerError }))
        assertEquals(LoadError.Http(500), assertFailsWith<LoadError> { api.loadBills(cospend) })
    }

    @Test
    fun `a body that is not json is an invalid response`() = runTest {
        val api = DividoApi(client(respond = { "<html>not a server we know</html>" }))
        assertTrue(assertFailsWith<LoadError> { api.loadBills(cospend) } is LoadError.InvalidResponse)
    }

    // MARK: Decoding

    @Test
    fun `bills decode with the cospend-only fields intact`() = runTest {
        val api = DividoApi(client(respond = {
            """[{"id":42,"amount":12.5,"what":"Groceries","date":"2026-05-14","payer_id":1,
                 "owers":[],"repeat":"n","categoryid":-1,"paymentmode":"c","comment":"split later"}]"""
        }))
        val bills = api.loadBills(cospend)
        assertEquals(1, bills.size)
        assertEquals(-1, bills[0].categoryid)
        assertEquals("c", bills[0].paymentmode)
        assertEquals("split later", bills[0].comment)
    }
}
