package mongol.compose.layout

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import mongol.compose.core.MongolTextPainter
import kotlin.math.ceil

/**
 * Shared measured container for Mongol text composables.
 */
@Composable
internal fun MongolTextMeasuredLayout(
    painter: MongolTextPainter,
    modifier: Modifier = Modifier,
    minLines: Int = 1,
    maxLines: Int = Int.MAX_VALUE,
    lineSpan: Int = 0,
    content: @Composable () -> Unit,
) {
    Layout(
        modifier = modifier,
        content = content,
    ) { measurables, constraints ->
        val measurable = measurables.single()
        val isSingleLine = painter.maxLines == 1

        // 1. Layout painter to find natural text size
        val layoutHeightPx = if (isSingleLine) 100_000f else {
            if (constraints.hasBoundedHeight) constraints.maxHeight.toFloat().coerceAtLeast(1f) else 100_000f
        }
        painter.layout(maxHeight = layoutHeightPx)

        val metrics = painter.computeLineMetrics()
        val textHeight = if (painter.longestLine.isFinite()) ceil(painter.longestLine).toInt() else 0
        val textWidth = if (painter.width.isFinite()) ceil(painter.width).toInt() else 0

        // 2. Resolve the component's VISIBLE size
        // Use actual measured width of lines if available, otherwise fallback to estimated span
        val fallbackSpan = if (lineSpan > 0) lineSpan.toFloat() else 40f

        val minWidthPx = if (metrics.size >= minLines) {
            metrics.take(minLines).sumOf { it.width.toDouble() }.toFloat()
        } else {
            val existingWidth = metrics.sumOf { it.width.toDouble() }.toFloat()
            existingWidth + (minLines - metrics.size) * fallbackSpan
        }

        val maxWidthLimit = if (maxLines == Int.MAX_VALUE) {
            constraints.maxWidth.toFloat()
        } else if (metrics.size >= maxLines) {
            metrics.take(maxLines).sumOf { it.width.toDouble() }.toFloat()
        } else {
            val existingWidth = metrics.sumOf { it.width.toDouble() }.toFloat()
            existingWidth + (maxLines - metrics.size) * fallbackSpan
        }

        val resolvedWidthPx = textWidth.toFloat()
            .coerceIn(minWidthPx, maxWidthLimit)
            .coerceIn(constraints.minWidth.toFloat(), constraints.maxWidth.toFloat())
            .toInt()

        val resolvedHeightPx = if (isSingleLine && constraints.hasBoundedHeight) {
            constraints.maxHeight
        } else {
            textHeight.coerceIn(constraints.minHeight, constraints.maxHeight)
        }

        // 3. Measure child with resolved size
        val placeable = measurable.measure(
            Constraints.fixed(resolvedWidthPx, resolvedHeightPx)
        )

        layout(resolvedWidthPx, resolvedHeightPx) {
            placeable.place(0, 0)
        }
    }
}
