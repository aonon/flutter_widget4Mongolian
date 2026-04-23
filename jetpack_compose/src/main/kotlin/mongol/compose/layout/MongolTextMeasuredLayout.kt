package mongol.compose.layout

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.layout.IntrinsicMeasurable
import androidx.compose.ui.layout.IntrinsicMeasureScope
import androidx.compose.ui.unit.Constraints
import mongol.compose.core.MongolTextPainter
import kotlin.math.ceil

/**
 * Shared measured container for Mongol text composables.
 *
 * This keeps modifier behavior consistent by exposing a stable measured size
 * from MongolTextPainter before any drawing content is placed.
 *
 * Efficiency note: This layout minimizes redundant layout passes by probing
 * constraints and implementing intrinsic measurement hooks.
 */
@Composable
internal fun MongolTextMeasuredLayout(
    painter: MongolTextPainter,
    modifier: Modifier = Modifier,
    minWidth: Int = 0,
    content: @Composable () -> Unit,
) {
    Layout(
        modifier = modifier,
        content = content,
        measurePolicy = object : MeasurePolicy {
            override fun MeasureScope.measure(
                measurables: List<Measurable>,
                constraints: Constraints
            ): MeasureResult {
                // 1. Initial height selection.
                // If we have a bounded height, use it as the probe to avoid double layout.
                val probeHeight = if (constraints.hasBoundedHeight) {
                    // Avoid 0-height probes during startup which cause width explosion.
                    // 1500px (~450dp) is a safe middle ground for measurement.
                    constraints.maxHeight.toFloat().coerceAtLeast(1500f)
                } else {
                    100_000f
                }

                painter.layout(maxHeight = probeHeight)

                // 2. Resolve final dimensions.
                val intrinsicHeight = if (painter.longestLine.isFinite()) {
                    ceil(painter.longestLine.toDouble()).toInt().coerceAtLeast(1)
                } else {
                    probeHeight.toInt()
                }

                val resolvedHeight = intrinsicHeight.coerceIn(constraints.minHeight, constraints.maxHeight)

                // Ensure painter layout matches the final resolved height.
                // If resolvedHeight is too small (startup noise), stick to probeHeight for measurement.
                val measurementHeight = if (resolvedHeight < 50 && constraints.hasBoundedHeight) {
                    probeHeight
                } else {
                    resolvedHeight.toFloat()
                }
                painter.layout(maxHeight = measurementHeight)

                val intrinsicWidthVal = if (painter.width.isFinite() && painter.width > 0) {
                    ceil(painter.width.toDouble()).toInt().coerceAtLeast(1)
                } else {
                    minWidth.coerceAtLeast(1)
                }
                val resolvedWidth = intrinsicWidthVal.coerceIn(constraints.minWidth, constraints.maxWidth)

                // 3. Measure and place children.
                val childConstraints = Constraints.fixed(resolvedWidth, resolvedHeight)
                val placeables = measurables.map { it.measure(childConstraints) }

                return layout(resolvedWidth, resolvedHeight) {
                    placeables.forEach { it.place(0, 0) }
                }
            }

            override fun IntrinsicMeasureScope.minIntrinsicHeight(
                measurables: List<IntrinsicMeasurable>,
                width: Int
            ): Int = ceil(painter.minIntrinsicLineExtent.toDouble()).toInt().coerceAtLeast(1)

            override fun IntrinsicMeasureScope.maxIntrinsicHeight(
                measurables: List<IntrinsicMeasurable>,
                width: Int
            ): Int = ceil(painter.maxIntrinsicLineExtent.toDouble()).toInt().coerceAtLeast(1)

            override fun IntrinsicMeasureScope.minIntrinsicWidth(
                measurables: List<IntrinsicMeasurable>,
                height: Int
            ): Int {
                // If height is 0 or very small (startup noise), use a reasonable fallback
                // to prevent column explosion.
                val layoutHeight = if (height < 100) 2000f else height.toFloat()
                painter.layout(maxHeight = layoutHeight)
                val w = ceil(painter.width.toDouble()).toInt()
                return if (w > 0) w else minWidth.coerceAtLeast(1)
            }

            override fun IntrinsicMeasureScope.maxIntrinsicWidth(
                measurables: List<IntrinsicMeasurable>,
                height: Int
            ): Int = minIntrinsicWidth(measurables, height)
        }
    )
}
