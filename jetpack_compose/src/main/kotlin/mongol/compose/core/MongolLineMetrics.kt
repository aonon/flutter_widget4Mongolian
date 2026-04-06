package mongol.compose.core

/**
 * Metrics for a single visual line (column segment) in Mongolian vertical text.
 *
 * Mirrors Flutter's MongolLineMetrics in:
 * lib/src/base/mongol_paragraph.dart
 */
data class MongolLineMetrics(
    val hardBreak: Boolean,
    val ascent: Float,
    val descent: Float,
    val unscaledAscent: Float,
    val height: Float,
    val width: Float,
    val top: Float,
    val baseline: Float,
    val lineNumber: Int,
)
