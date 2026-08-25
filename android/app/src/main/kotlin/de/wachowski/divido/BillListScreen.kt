package de.wachowski.divido

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import de.wachowski.divido.core.Bill
import de.wachowski.divido.core.Person

/**
 * The bill list.
 *
 * Amounts are formatted through the platform's locale rather than a hardcoded
 * pattern — the iOS app shipped "5.00" to German users for a long time because
 * it built strings by hand, and that is upstream issue #72's neighbourhood.
 */
@Composable
fun BillListScreen(bills: List<Bill>, modifier: Modifier = Modifier) {
    if (bills.isEmpty()) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                text = "Noch keine Rechnungen",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        return
    }

    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp),
    ) {
        items(bills, key = { it.id }) { bill -> BillRow(bill) }
    }
}

@Composable
private fun BillRow(bill: Bill) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(bill.what, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(
                    text = bill.date,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                bill.comment?.takeIf { it.isNotBlank() }?.let { note ->
                    Text(note, style = MaterialTheme.typography.bodySmall,
                         color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Text(
                text = MoneyFormatter.format(bill.amount),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun BillListPreview() {
    BillListScreen(
        listOf(
            Bill(id = 1, amount = 24.0, what = "Taxi", date = "2026-08-25", payerId = 1,
                 owers = listOf(Person(1, "Alice"), Person(2, "Bob")),
                 comment = "Flughafen"),
            Bill(id = 2, amount = 8.5, what = "Kaffee", date = "2026-08-24", payerId = 2,
                 owers = listOf(Person(1, "Alice"))),
        )
    )
}
