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
            val clusterEnd = when {
                nextBoundary == BreakIterator.DONE -> safeEnd
                nextBoundary <= cursor -> (cursor + 1).coerceAtMost(safeEnd)
                else -> nextBoundary.coerceAtMost(safeEnd)
            }
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

    fun shiftLineMetrics(metrics: MongolLineMetrics, offset: Offset): MongolLineMetrics {
        require(offset.x.isFinite()) { "Offset.x must be finite, got ${offset.x}" }
        require(offset.y.isFinite()) { "Offset.y must be finite, got ${offset.y}" }
        return metrics.copy(
            top = metrics.top + offset.y,
            baseline = metrics.baseline + offset.x,
        )
    }

    fun shiftTextBox(box: Rect, offset: Offset): Rect {
        require(offset.x.isFinite()) { "Offset.x must be finite, got ${offset.x}" }
        require(offset.y.isFinite()) { "Offset.y must be finite, got ${offset.y}" }
        return Rect(
            left = box.left + offset.x,
            top = box.top + offset.y,
            right = box.right + offset.x,
            bottom = box.bottom + offset.y,
        )
    }

    /**
     * Returns the next caret position, respecting surrogate pairs.
     */
    fun getOffsetAfter(offset: Int, text: String): Int? {
        if (offset < 0 || offset >= text.length) return null
        val iterator = createCharacterBreakIterator(text)
        val next = iterator.following(offset)
        return if (next == BreakIterator.DONE) null else next
    }

    /**
     * Returns the previous caret position, respecting surrogate pairs.
     */
    fun getOffsetBefore(offset: Int, text: String): Int? {
        if (offset <= 0 || offset > text.length) return null
        val iterator = createCharacterBreakIterator(text)
        val prev = iterator.preceding(offset)
        return if (prev == BreakIterator.DONE) null else prev
    }

    fun codePointFromSurrogates(highSurrogate: Int, lowSurrogate: Int): Int {
        require(isHighSurrogate(highSurrogate)) {
            "U+${highSurrogate.toString(16).uppercase().padStart(4, '0')} is not a high surrogate."
        }
        require(isLowSurrogate(lowSurrogate)) {
            "U+${lowSurrogate.toString(16).uppercase().padStart(4, '0')} is not a low surrogate."
        }
        val base = 0x010000 - (0xD800 shl 10) - 0xDC00
        return (highSurrogate shl 10) + lowSurrogate + base
    }
}
