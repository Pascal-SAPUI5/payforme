package de.wachowski.divido.core

/**
 * The two backends Divido speaks to. They differ in more than a base URL:
 * authentication, how owers are encoded, and which fields exist at all.
 */
enum class ProjectBackend {
    COSPEND,
    IHATEMONEY;

    val staticPath: String
        get() = when (this) {
            COSPEND -> "index.php/apps/cospend/api/projects"
            IHATEMONEY -> "api/projects"
        }

    /**
     * Turns what a user typed into the add-project form into the value the API
     * expects.
     *
     * iHateMoney addresses projects by an id it derives from the name, and that
     * id is never shown in its web UI — so people type the name and the request
     * 404s. Cospend uses the share token exactly as entered and must not be
     * touched: normalising a case-sensitive token would break every project.
     */
    fun projectIdentifier(fromUserInput: String): String = when (this) {
        IHATEMONEY -> fromUserInput.iHateMoneyProjectId
        COSPEND -> fromUserInput
    }
}

data class Project(
    val name: String,
    val projectId: String,
    val password: String,
    val token: String,
    val url: String,
    val backend: ProjectBackend,
    val members: Map<Int, Person> = emptyMap(),
    val bills: List<Bill> = emptyList(),
    val me: Int? = null,
)
