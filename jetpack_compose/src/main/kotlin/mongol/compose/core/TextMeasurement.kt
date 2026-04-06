package mongol.compose.core

/**
 * Per-glyph measurement used by MongolParagraph layout.
 */
data class GlyphMetrics(
    val advance: Float,
    val crossAxis: Float,
    val ascent: Float,
    val descent: Float,
)

data class RunMetrics(
    val advance: Float,
    val crossAxis: Float,
    val ascent: Float,
    val descent: Float,
    val clusterAdvances: List<Float> = emptyList(),
)

/**
 * Injectable run measurer so core can use real text metrics without hard
 * dependency on Compose runtime classes.
 */
interface TextRunMeasurer {
    fun measureRun(text: String, isRotated: Boolean): RunMetrics

    fun measureRunRange(
        fullText: String,
        start: Int,
        end: Int,
        isRotated: Boolean,
    ): RunMetrics {
        if (start >= end || start < 0 || end > fullText.length) {
            return measureRun("", isRotated)
        }
        return measureRun(fullText.substring(start, end), isRotated)
    }

    fun measureGlyph(char: Char, isRotated: Boolean): GlyphMetrics {
        val metrics = measureRun(char.toString(), isRotated)
        return GlyphMetrics(
            advance = metrics.advance,
            crossAxis = metrics.crossAxis,
            ascent = metrics.ascent,
            descent = metrics.descent,
        )
    }
}
