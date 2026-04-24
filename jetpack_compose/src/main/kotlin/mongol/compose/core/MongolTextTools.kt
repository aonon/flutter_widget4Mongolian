package mongol.compose.core

import java.text.BreakIterator
import java.util.Locale

/**
 * Utility methods used by vertical Mongolian text layout and caret logic.
 *
 * Mirrors the essential APIs from Flutter's MongolTextTools in:
 * lib/src/base/mongol_text_tools.dart
 */
object MongolTextTools {

    private fun isGraphemeContinuation(codePoint: Int): Boolean {
        if (codePoint in 0x180B..0x180D) return true // Mongolian free variation selectors
        if (codePoint == 0x180F) return true // Mongolian variation selector four
        if (codePoint == 0x180E) return true // Mongolian vowel separator
        if (codePoint == 0x200C || codePoint == 0x200D) return true // ZWNJ / ZWJ

        // Emoji skin tone modifiers (Fitzpatrick)
        if (codePoint in 0x1F3FB..0x1F3FF) return true

        // Variation selectors (Unicode)
        if (codePoint in 0xFE00..0xFE0F) return true
        if (codePoint in 0xE0100..0xE01EF) return true

        return when (Character.getType(codePoint)) {
            Character.NON_SPACING_MARK.toInt(),
            Character.COMBINING_SPACING_MARK.toInt(),
            Character.ENCLOSING_MARK.toInt() -> true

            else -> false
        }
    }

    private fun extendClusterEnd(text: String, start: Int, endExclusive: Int, hardEnd: Int): Int {
        if (start >= hardEnd) return hardEnd
        var end = endExclusive.coerceIn((start + 1).coerceAtMost(hardEnd), hardEnd)
        while (end < hardEnd) {
            val cp = Character.codePointAt(text, end)
            val prevIdx = text.offsetByCodePoints(end, -1)
            val prevCp = Character.codePointAt(text, prevIdx)

            if (prevCp == 0x200D || isGraphemeContinuation(cp)) {
                end += Character.charCount(cp)
            } else {
                break
            }
        }
        return end.coerceAtMost(hardEnd)
    }

    private fun createCharacterBreakIterator(text: String): BreakIterator {
        return BreakIterator.getCharacterInstance(Locale.ROOT).apply {
            setText(text)
        }
    }

    fun forEachGraphemeCluster(
        text: String,
        start: Int = 0,
        end: Int = text.length,
        block: (clusterStart: Int, clusterEnd: Int) -> Unit,
    ) {
        if (text.isEmpty()) return
        val safeStart = start.coerceIn(0, text.length)
        val safeEnd = end.coerceIn(safeStart, text.length)
        if (safeStart >= safeEnd) return

        val iterator = createCharacterBreakIterator(text)
        var cursor = safeStart
        while (cursor < safeEnd) {
            val nextBoundary = iterator.following(cursor)
            val baseEnd = when {
                nextBoundary == BreakIterator.DONE -> safeEnd
                nextBoundary <= cursor -> (cursor + 1).coerceAtMost(safeEnd)
                else -> nextBoundary.coerceAtMost(safeEnd)
            }
            val clusterEnd = extendClusterEnd(
                text = text,
                start = cursor,
                endExclusive = baseEnd,
                hardEnd = safeEnd,
            )
            block(cursor, clusterEnd)
            cursor = clusterEnd
        }
    }

    fun getGraphemeRangeAt(text: String, offset: Int): TextRange {
        if (text.isEmpty()) return TextRange.EMPTY
        val safeOffset = offset.coerceIn(0, (text.length - 1).coerceAtLeast(0))

        var startOfSearch = 0
        for (i in safeOffset downTo 0) {
            if (text[i] == '\n') {
                startOfSearch = i + 1
                break
            }
        }

        var result = TextRange(safeOffset, (safeOffset + 1).coerceAtMost(text.length))
        forEachGraphemeCluster(text, start = startOfSearch) { start, end ->
            if (safeOffset in start until end) {
                result = TextRange(start, end)
                return@forEachGraphemeCluster
            }
            if (start > safeOffset) return@forEachGraphemeCluster
        }
        return result
    }

    fun isUtf16(value: Int): Boolean {
        return value in 0x0000..0xFFFF
    }

    fun isMongolian(codePoint: Int): Boolean {
        return codePoint in 0x1800..0x18AF
    }

    fun isBreakOpportunity(codePoint: Int): Boolean {
        // Space and Newline are always break opportunities
        if (codePoint == ' '.code || codePoint == '\n'.code) return true
        
        // Path separators and common URL/Filename punctuation are break opportunities 
        // for non-Mongolian text.
        return codePoint == '\\'.code || codePoint == '/'.code || 
               codePoint == '.'.code || codePoint == ':'.code || 
               codePoint == '-'.code || codePoint == '_'.code
    }

    fun isHighSurrogate(value: Int): Boolean {
        require(isUtf16(value)) {
            "U+${value.toString(16).uppercase().padStart(4, '0')} is not a valid UTF-16 code unit."
        }
        return value and 0xFC00 == 0xD800
    }

    fun isLowSurrogate(value: Int): Boolean {
        require(isUtf16(value)) {
            "U+${value.toString(16).uppercase().padStart(4, '0')} is not a valid UTF-16 code unit."
        }
        return value and 0xFC00 == 0xDC00
    }

    fun isUnicodeDirectionality(value: Int): Boolean {
        return value == 0x200F || value == 0x200E
    }

    /**
     * Returns the next caret position, treating each grapheme cluster as one unit.
     * Consistent with forEachGraphemeCluster (covers ZWJ sequences, skin tone modifiers, etc.).
     */
    fun getOffsetAfter(offset: Int, text: String): Int? {
        if (offset < 0 || offset >= text.length) return null
        val range = getGraphemeRangeAt(text, offset)
        return if (range.end > offset) range.end else null
    }

    /**
     * Returns the previous caret position, treating each grapheme cluster as one unit.
     * Consistent with forEachGraphemeCluster (covers ZWJ sequences, skin tone modifiers, etc.).
     */
    fun getOffsetBefore(offset: Int, text: String): Int? {
        if (offset <= 0 || offset > text.length) return null
        val range = getGraphemeRangeAt(text, offset - 1)
        return if (range.start < offset) range.start else null
    }

}
