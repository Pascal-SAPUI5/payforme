package de.wachowski.divido.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * One expense.
 *
 * `categoryid`, `paymentmode` and `comment` are Cospend-only and nullable
 * because iHateMoney never sends them and older Cospend versions may not
 * either. They are carried through deliberately: the iOS app used to drop them
 * on decode and hardcode defaults back into every update, which silently moved
 * every edited bill to "uncategorised" and wiped any note written in the web UI.
 */
@Serializable
data class Bill(
    val id: Int,
    val amount: Double,
    val what: String,
    /** `yyyy-MM-dd`, the format both backends use. */
    val date: String,
    @SerialName("payer_id") val payerId: Int,
    val owers: List<Person> = emptyList(),
    val repeat: String? = null,
    val lastchanged: Long? = null,
    val categoryid: Int? = null,
    val paymentmode: String? = null,
    val comment: String? = null,
) {
    /**
     * The request parameters for a create or update call.
     *
     * Every Cospend-only field is round-tripped rather than reset, and sent even
     * when empty — omitting a key leaves the server's old value in place, which
     * would make clearing a comment impossible.
     */
    fun paramsFor(backend: ProjectBackend): Map<String, Any> {
        val params = mutableMapOf<String, Any>(
            "date" to date,
            "what" to what,
            "payer" to payerId.toString(),
            "amount" to amount.toString(),
        )

        when (backend) {
            ProjectBackend.COSPEND -> {
                params["payed_for"] = owers.joinToString(",") { it.id.toString() }
                params["paymentmode"] = paymentmode ?: "n"
                params["categoryid"] = (categoryid ?: 0).toString()
                params["comment"] = comment ?: ""
                params["repeat"] = repeat ?: "n"
            }
            ProjectBackend.IHATEMONEY -> {
                params["payed_for"] = owers.map { it.id.toString() }
            }
        }

        return params
    }

    companion object {
        fun new() = Bill(id = -1, amount = 0.0, what = "", date = "", payerId = -1)
    }
}
