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

        // Use a large but finite probe for unbounded constraints to avoid Int.MAX sizes.
        val probeHeightPx = if (constraints.hasBoundedHeight) {
            constraints.maxHeight.coerceAtLeast(1)
        } else {
            100_000
        }

        painter.layout(maxHeight = probeHeightPx.toFloat())

        val intrinsicHeight = if (painter.longestLine.isFinite()) {
            ceil(painter.longestLine.toDouble()).toInt().coerceAtLeast(1)
        } else {
            probeHeightPx
        }

        val boundedMaxHeight = if (constraints.hasBoundedHeight) {
            constraints.maxHeight
        } else {
            probeHeightPx
        }
        val resolvedHeightPx = intrinsicHeight.coerceIn(constraints.minHeight, boundedMaxHeight)

        if (resolvedHeightPx != probeHeightPx) {
            painter.layout(maxHeight = resolvedHeightPx.toFloat())
        }

        val desiredWidthPx = if (painter.width.isFinite()) {
            ceil(painter.width.toDouble()).toInt().coerceAtLeast(1)
        } else {
            constraints.minWidth.coerceAtLeast(1)
        }
        val boundedMaxWidth = if (constraints.hasBoundedWidth) {
            constraints.maxWidth
        } else {
            100_000
        }
        val resolvedWidthPx = desiredWidthPx
            .coerceIn(constraints.minWidth, boundedMaxWidth)

        val placeable = measurable.measure(
            Constraints.fixed(resolvedWidthPx, resolvedHeightPx),
        )

        layout(resolvedWidthPx, resolvedHeightPx) {
            placeable.place(0, 0)
        }
    }
}