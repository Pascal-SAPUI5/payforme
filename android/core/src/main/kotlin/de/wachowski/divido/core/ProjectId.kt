package de.wachowski.divido.core

import java.text.Normalizer

/**
 * The project id iHateMoney derives from a project's name.
 *
 * Mirrors `slugify()` in ihatemoney/utils.py:
 *
 *     value = unicodedata.normalize("NFKD", value)
 *     value = str(re.sub(r"[^\w\s-]", "", value).strip().lower())
 *     return re.sub(r"[-\s]+", "-", value)
 *
 * NFKD splits accents off their letters so the next step can drop them; runs of
 * hyphens and whitespace collapse into a single hyphen, which is why
 * "something + somethingelse" becomes "something-somethingelse" and not
 * "something-+-somethingelse".
 */
val String.iHateMoneyProjectId: String
    get() {
        val decomposed = Normalizer.normalize(this, Normalizer.Form.NFKD)
        val kept = buildString {
            for (ch in decomposed) {
                val type = Character.getType(ch).toByte()
                val isMark = type == Character.NON_SPACING_MARK ||
                    type == Character.COMBINING_SPACING_MARK ||
                    type == Character.ENCLOSING_MARK
                when {
                    isMark -> Unit
                    ch.isLetterOrDigit() || ch == '_' || ch == '-' || ch.isWhitespace() -> append(ch)
                }
            }
        }
        val normalised = kept.trim().lowercase()

        return buildString {
            var lastWasSeparator = false
            for (ch in normalised) {
                if (ch == '-' || ch.isWhitespace()) {
                    if (!lastWasSeparator) append('-')
                    lastWasSeparator = true
                } else {
                    append(ch)
                    lastWasSeparator = false
                }
            }
        }
    }
