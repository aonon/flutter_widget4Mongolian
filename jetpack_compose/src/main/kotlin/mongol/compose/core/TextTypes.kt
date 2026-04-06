package mongol.compose.core

/**
 * Caret affinity equivalent to Flutter TextAffinity.
 */
enum class TextAffinity {
    UPSTREAM,
    DOWNSTREAM,
}

/**
 * Caret position equivalent to Flutter TextPosition.
 */
data class TextPosition(
    val offset: Int,
    val affinity: TextAffinity = TextAffinity.DOWNSTREAM,
)

/**
 * Text range equivalent to Flutter TextRange.
 */
data class TextRange(
    val start: Int,
    val end: Int,
) {
    companion object {
        val EMPTY = TextRange(0, 0)
    }
}

/**
 * Minimal contract needed by CaretMetricsCalculator.
 *
 * MongolParagraph can implement this when migrated.
 */
interface ParagraphBoxProvider {
    fun getBoxesForRange(start: Int, end: Int): List<Rect>
}
