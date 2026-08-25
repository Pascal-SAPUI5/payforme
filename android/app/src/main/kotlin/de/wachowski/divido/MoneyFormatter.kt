package de.wachowski.divido

import java.text.NumberFormat
import java.util.Locale

/**
 * Formats amounts through the platform's locale.
 *
 * Building the string by hand is how the iOS app ended up showing "5.00" to
 * German users; the separator, the grouping and the position of the currency
 * symbol all differ per locale, and none of that is worth reimplementing.
 */
object MoneyFormatter {
    fun format(amount: Double, locale: Locale = Locale.getDefault()): String =
        NumberFormat.getNumberInstance(locale).apply {
            minimumFractionDigits = 2
            maximumFractionDigits = 2
        }.format(amount)
}
