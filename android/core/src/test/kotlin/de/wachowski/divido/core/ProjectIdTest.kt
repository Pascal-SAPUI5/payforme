package de.wachowski.divido.core

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * iHateMoney addresses a project by an id derived from its name, and never
 * shows that id — so people type the name and get an empty project with no
 * explanation. The cases below are the ones users actually reported.
 */
class ProjectIdTest {

    @Test fun `a space becomes a hyphen`() =
        assertEquals("spongebob-house", "Spongebob house".iHateMoneyProjectId)

    @Test fun `punctuation is dropped and the gap collapses`() =
        assertEquals("something-somethingelse", "something + somethingelse".iHateMoneyProjectId)

    @Test fun `an id that is already correct is unchanged`() =
        assertEquals("spongebob-house", "spongebob-house".iHateMoneyProjectId)

    @Test fun `accents are folded`() =
        assertEquals("cafe-ausflug", "Café Ausflug".iHateMoneyProjectId)

    @Test fun `runs of separators collapse`() {
        assertEquals("trip-2024", "Trip   2024".iHateMoneyProjectId)
        assertEquals("a-b", "a --  b".iHateMoneyProjectId)
    }

    @Test fun `surrounding whitespace is trimmed`() =
        assertEquals("urlaub", "  Urlaub  ".iHateMoneyProjectId)

    @Test fun `underscores survive`() =
        assertEquals("wohnung_wg", "Wohnung_WG".iHateMoneyProjectId)

    @Test fun `a string with nothing usable becomes empty`() {
        assertEquals("", "!?!".iHateMoneyProjectId)
        assertEquals("", "".iHateMoneyProjectId)
    }

    @Test fun `cospend tokens are left alone`() {
        val token = "9dA50e410157DC1ca63e594af022f3a2"
        assertEquals(token, ProjectBackend.COSPEND.projectIdentifier(token))
        assertEquals("spongebob-house", ProjectBackend.IHATEMONEY.projectIdentifier("Spongebob house"))
    }
}
