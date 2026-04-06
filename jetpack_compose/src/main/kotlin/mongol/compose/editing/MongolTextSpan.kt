package mongol.compose.editing

import androidx.compose.ui.text.SpanStyle

/**
 * A style span covering [start]..[end) within the editable text.
 *
 * Spans are half-open: a character at index `i` is covered when `start <= i < end`.
 * Multiple spans can overlap; they are merged with [SpanStyle.merge] in order of
 * insertion when building the effective style for rendering.
 */
data class MongolTextSpan(
    val start: Int,
    val end: Int,
    val style: SpanStyle,
) {
    init {
        require(start >= 0) { "MongolTextSpan.start must be >= 0" }
        require(end >= start) { "MongolTextSpan.end must be >= start" }
    }

    /** True if the span covers zero characters — can be cleaned up. */
    val isEmpty: Boolean get() = start == end

    /** Clamp the span to [0, textLength). Returns null if the result is empty. */
    fun clampedTo(textLength: Int): MongolTextSpan? {
        val s = start.coerceIn(0, textLength)
        val e = end.coerceIn(0, textLength)
        return if (e <= s) null else copy(start = s, end = e)
    }
}

/**
 * Adjust a list of spans after an **insertion** of [insertedLength] characters
 * at position [insertPos] in the text.
 *
 * Insertion rules (mirrors Android SpannableStringBuilder):
 * - Spans with end <= insertPos → unchanged
 * - Spans with start >= insertPos → both endpoints shift right by insertedLength
 * - Spans that straddle insertPos (start < insertPos < end) → end shifts right
 *   (the span "expands" to include the new text)
 */
internal fun List<MongolTextSpan>.adjustForInsert(
    insertPos: Int,
    insertedLength: Int,
): List<MongolTextSpan> {
    if (insertedLength <= 0) return this
    return map { span ->
        val newStart = if (span.start >= insertPos) span.start + insertedLength else span.start
        val newEnd = if (span.end > insertPos) span.end + insertedLength else span.end
        span.copy(start = newStart, end = newEnd)
    }
}

/**
 * Adjust a list of spans after a **deletion** of text in the range
 * [deleteStart, deleteEnd) (exclusive end).
 *
 * Deletion rules:
 * - Spans fully before the deletion (end <= deleteStart) → unchanged
 * - Spans fully after the deletion (start >= deleteEnd) → shift left by deleted length
 * - Spans fully inside the deletion → removed (collapsed to zero width)
 * - Spans straddling the deletion → trimmed / collapsed appropriately
 */
internal fun List<MongolTextSpan>.adjustForDelete(
    deleteStart: Int,
    deleteEnd: Int,
): List<MongolTextSpan> {
    if (deleteStart >= deleteEnd) return this
    val deletedLen = deleteEnd - deleteStart
    return mapNotNull { span ->
        val newStart = when {
            span.start <= deleteStart -> span.start
            span.start < deleteEnd -> deleteStart
            else -> span.start - deletedLen
        }
        val newEnd = when {
            span.end <= deleteStart -> span.end
            span.end < deleteEnd -> deleteStart
            else -> span.end - deletedLen
        }
        if (newEnd <= newStart) null else span.copy(start = newStart, end = newEnd)
    }
}

/**
 * Build a character-index → merged [SpanStyle] lookup for the given [text].
 *
 * Characters not covered by any span map to [baseStyle] (or [SpanStyle.Default]
 * if no base is supplied).  Overlapping spans are merged in list order.
 */
fun List<MongolTextSpan>.buildStyleMap(
    textLength: Int,
    baseStyle: SpanStyle = SpanStyle(),
): Array<SpanStyle> {
    val result = Array(textLength) { baseStyle }
    for (span in this) {
        val s = span.start.coerceIn(0, textLength)
        val e = span.end.coerceIn(0, textLength)
        for (i in s until e) {
            result[i] = result[i].merge(span.style)
        }
    }
    return result
}
