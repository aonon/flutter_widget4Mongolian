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
        
        // 探测高度：如果有约束则用最大高度，否则给一个足够大的值用于布局计算
        val probeHeightPx = if (constraints.hasBoundedHeight) {
            constraints.maxHeight.coerceAtLeast(1)
        } else {
            100_000
        }

        painter.layout(maxHeight = probeHeightPx.toFloat())

        // 核心修改：优先使用文字本身的长度 (longestLine)
        val intrinsicHeight = ceil(painter.longestLine.toDouble()).toInt().coerceAtLeast(1)
        
        // 如果高度不是强行固定的（minHeight != maxHeight），则包裹内容
        val resolvedHeightPx = intrinsicHeight.coerceIn(constraints.minHeight, constraints.maxHeight)

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