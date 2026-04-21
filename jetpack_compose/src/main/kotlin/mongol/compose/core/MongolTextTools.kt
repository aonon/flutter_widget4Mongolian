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

    private const val REGIONAL_INDICATOR_START = 0x1F1E6
    private const val REGIONAL_INDICATOR_END = 0x1F1FF

    private fun isMongolianContinuationCodePoint(codePoint: Int): Boolean {
        if (codePoint in 0x180B..0x180D) return true // Mongolian free variation selectors
        if (codePoint == 0x180F) return true // Mongolian variation selector four
        if (codePoint == 0x200C || codePoint == 0x200D) return true // ZWNJ / ZWJ
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
            if (!isMongolianContinuationCodePoint(cp)) break
            end += Character.charCount(cp)
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
        val safeOffset = offset.coerceIn(0, text.length - 1)
        val iterator = createCharacterBreakIterator(text)

        val end = iterator.following(safeOffset).let {
            if (it == BreakIterator.DONE) text.length else it
        }
        val start = iterator.preceding(end).let {
            if (it == BreakIterator.DONE) safeOffset else it
        }

        return TextRange(start = start, end = end)
    }

    fun isUtf16(value: Int): Boolean {
        return value in 0x0000..0xFFFF
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
     * Returns the next caret position, respecting surrogate pairs.
     */
    fun getOffsetAfter(offset: Int, text: String): Int? {
        if (offset < 0 || offset >= text.length) return null
        val iterator = createCharacterBreakIterator(text)
        val next = iterator.following(offset)
        if (next == BreakIterator.DONE) return null

        // Treat flag emoji (RI pairs) as one unit: advance by exactly one flag.
        val cp = Character.codePointAt(text, offset)
        if (isRegionalIndicator(cp)) {
            val runEnd = findRegionalIndicatorRunEnd(text, offset)
            val runCount = codePointDistance(text, offset, runEnd)
            val advance = if (runCount >= 2) 2 else 1
            return text.offsetByCodePoints(offset, advance).coerceAtMost(text.length)
        }

        return next
    }

    /**
     * Returns the previous caret position, respecting surrogate pairs.
     */
    fun getOffsetBefore(offset: Int, text: String): Int? {
        if (offset <= 0 || offset > text.length) return null
        val iterator = createCharacterBreakIterator(text)
        val prev = iterator.preceding(offset)
        if (prev == BreakIterator.DONE) return null

        // Treat flag emoji (RI pairs) as one unit: retreat by exactly one flag.
        val cpStart = text.offsetByCodePoints(offset, -1)
        val cp = Character.codePointAt(text, cpStart)
        if (isRegionalIndicator(cp)) {
            val runStart = findRegionalIndicatorRunStart(text, cpStart)
            val runCount = codePointDistance(text, runStart, offset)
            val retreat = if (runCount >= 2) 2 else 1
            return text.offsetByCodePoints(offset, -retreat).coerceAtLeast(0)
        }

        return prev
    }

    private fun isRegionalIndicator(codePoint: Int): Boolean {
        return codePoint in REGIONAL_INDICATOR_START..REGIONAL_INDICATOR_END
    }

    private fun findRegionalIndicatorRunStart(text: String, index: Int): Int {
        var cursor = index
        while (cursor > 0) {
            val prev = text.offsetByCodePoints(cursor, -1)
            val cp = Character.codePointAt(text, prev)
            if (!isRegionalIndicator(cp)) break
            cursor = prev
        }
        return cursor
    }

    private fun findRegionalIndicatorRunEnd(text: String, index: Int): Int {
        var cursor = index
        while (cursor < text.length) {
            val cp = Character.codePointAt(text, cursor)
            if (!isRegionalIndicator(cp)) break
            cursor += Character.charCount(cp)
        }
        return cursor
    }

    private fun codePointDistance(text: String, start: Int, end: Int): Int {
        if (start >= end) return 0
        return Character.codePointCount(text, start, end)
    }
}
