package de.wachowski.divido.core

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * The Cospend-only fields were the source of a data-loss bug in the iOS app:
 * they were never decoded, and the defaults were hardcoded back into every
 * update, so editing a bill's amount also wiped its category and any comment.
 * Divido carries them from the start; these tests keep it that way.
 */
class BillTest {

    private val json = Json { ignoreUnknownKeys = true }
    private val alice = Person(id = 1, name = "Alice")

    @Test
    fun `cospend fields are decoded`() {
        val bill = json.decodeFromString<Bill>(
            """{"id":42,"amount":12.5,"what":"Groceries","date":"2026-05-14","payer_id":1,
                "owers":[],"repeat":"n","categoryid":-1,"paymentmode":"c","comment":"deposit separately"}"""
        )
        assertEquals(-1, bill.categoryid)
        assertEquals("c", bill.paymentmode)
        assertEquals("deposit separately", bill.comment)
    }

    @Test
    fun `a payload without those fields still decodes`() {
        val bill = json.decodeFromString<Bill>(
            """{"id":7,"amount":12.5,"what":"Tea","date":"2026-05-04","payer_id":1,"owers":[],"repeat":"n"}"""
        )
        assertNull(bill.categoryid)
        assertNull(bill.paymentmode)
        assertNull(bill.comment)
    }

    @Test
    fun `cospend params round-trip every field`() {
        val bill = Bill(
            id = 9, amount = 5.0, what = "Rent", date = "2026-05-14", payerId = 1,
            owers = listOf(alice), repeat = "n",
            categoryid = -3, paymentmode = "c", comment = "split unevenly",
        )
        val params = bill.paramsFor(ProjectBackend.COSPEND)
        assertEquals("-3", params["categoryid"], "editing must not move a bill to 'uncategorised'")
        assertEquals("c", params["paymentmode"])
        assertEquals("split unevenly", params["comment"])
        assertEquals("1", params["payed_for"])
    }

    @Test
    fun `a bill without them falls back to the documented defaults`() {
        val params = Bill.new().copy(owers = listOf(alice)).paramsFor(ProjectBackend.COSPEND)
        assertEquals("0", params["categoryid"])
        assertEquals("n", params["paymentmode"])
        assertEquals("", params["comment"], "an empty comment must be sent, or it can never be cleared")
    }

    @Test
    fun `iHateMoney carries none of the cospend fields`() {
        val bill = Bill(
            id = 9, amount = 5.0, what = "Rent", date = "2026-05-14", payerId = 1,
            owers = listOf(alice), categoryid = -3, paymentmode = "c", comment = "ignored",
        )
        val params = bill.paramsFor(ProjectBackend.IHATEMONEY)
        assertNull(params["categoryid"])
        assertNull(params["paymentmode"])
        assertNull(params["comment"])
        assertEquals(listOf("1"), params["payed_for"], "iHateMoney wants a list, not a joined string")
    }
}
