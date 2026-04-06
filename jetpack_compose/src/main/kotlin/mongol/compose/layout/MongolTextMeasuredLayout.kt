package mongol.compose.layout

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import mongol.compose.core.MongolTextPainter
import kotlin.math.ceil

/**
 * Shared measured container for Mongol text composables.
 *
 * This keeps modifier behavior consistent by exposing a stable measured size
 * from MongolTextPainter before any drawing content is placed.
 */
@Composable
internal fun MongolTextMeasuredLayout(
    painter: MongolTextPainter,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Layout(
        modifier = modifier,
        content = content,
    ) { measurables, constraints ->
        val measurable = measurables.single()
        val probeHeightPx = if (constraints.hasBoundedHeight) {
            constraints.maxHeight.coerceAtLeast(1)
        } else {
            100_000
        }

        painter.layout(maxHeight = probeHeightPx.toFloat())

        val desiredHeightPx = if (constraints.hasBoundedHeight) {
            constraints.maxHeight
        } else {
            ceil(painter.longestLine.toDouble()).toInt().coerceAtLeast(1)
        }
        val resolvedHeightPx = desiredHeightPx
            .coerceAtLeast(1)
            .coerceIn(constraints.minHeight, constraints.maxHeight)

        if (resolvedHeightPx != probeHeightPx) {
            painter.layout(maxHeight = resolvedHeightPx.toFloat())
        }

        val desiredWidthPx = ceil(painter.width.toDouble()).toInt().coerceAtLeast(1)
        val resolvedWidthPx = desiredWidthPx
            .coerceIn(constraints.minWidth, constraints.maxWidth)

        val placeable = measurable.measure(
            Constraints.fixed(resolvedWidthPx, resolvedHeightPx),
        )

        layout(resolvedWidthPx, resolvedHeightPx) {
            placeable.place(0, 0)
        }
    }
}