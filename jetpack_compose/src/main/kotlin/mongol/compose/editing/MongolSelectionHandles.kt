package mongol.compose.editing

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import mongol.compose.core.MongolTextPainter
import kotlin.math.roundToInt
import mongol.compose.core.Offset as CoreOffset
import mongol.compose.core.TextPosition

enum class MongolSelectionHandleType {
    CARET,
    START,
    END,
}

data class MongolSelectionHandle(
    val type: MongolSelectionHandleType,
    val offset: CoreOffset,
)

data class MongolSelectionHandlesState(
    val handles: List<MongolSelectionHandle>,
    val activeHandle: MongolSelectionHandleType? = null,
) {
    val isVisible: Boolean
        get() = handles.isNotEmpty()
}

@Composable
fun MongolSelectionHandleIcon(
    type: MongolSelectionHandleType,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier.size(12.dp)) {
        val radius = size.width
        val W = size.width * 2.6f

        when (type) {
            MongolSelectionHandleType.START -> {
                // Circle at top-left, tip at bottom-right (2R, 2R)
                drawCircle(color = color, radius = radius, center = Offset(radius, radius))
                val path = Path().apply {
                    moveTo(2 * radius, 2 * radius)
                    lineTo(radius, 2 * radius)
                    lineTo(2 * radius, radius)
                    close()
                }
                drawPath(path, color)
            }

            MongolSelectionHandleType.END -> {
                // Circle at bottom-right, tip at top-left (W-2R, W-2R)
                drawCircle(color = color, radius = radius, center = Offset(W - radius, W - radius))
                val path = Path().apply {
                    moveTo(W - 2 * radius, W - 2 * radius)
                    lineTo(W - radius, W - 2 * radius)
                    lineTo(W - 2 * radius, W - radius)
                    close()
                }
                drawPath(path, color)
            }

            MongolSelectionHandleType.CARET -> {
                drawCircle(color = color, radius = radius * 0.5f, center = center)
            }
        }
    }
}

private fun handleAnchorInIcon(
    type: MongolSelectionHandleType,
    handleSizePx: Float,
): Offset {
    // START tip is at 2*radius = 2*0.35*W = 0.7*W
    // END tip is at W - 2*radius = W - 0.7*W = 0.3*W
    return when (type) {
        MongolSelectionHandleType.START -> Offset(handleSizePx * 0.7f, handleSizePx * 0.7f)
        MongolSelectionHandleType.END -> Offset(handleSizePx * 0.3f, handleSizePx * 0.3f)
        MongolSelectionHandleType.CARET -> Offset(handleSizePx * 0.5f, handleSizePx * 0.5f)
    }
}

@Composable
fun MongolSelectionHandles(
    state: MongolSelectionHandlesState,
    onHandleDrag: (MongolSelectionHandleType, Offset) -> Unit,
    onHandleDragStart: (MongolSelectionHandleType) -> Unit = {},
    onHandleDragEnd: (MongolSelectionHandleType) -> Unit = {},
    color: Color = Color(0xFF2196F3),
) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    val handleSizePx = with(density) { 30.dp.toPx() }

    val latestOnDrag by rememberUpdatedState(onHandleDrag)
    val latestOnDragStart by rememberUpdatedState(onHandleDragStart)
    val latestOnDragEnd by rememberUpdatedState(onHandleDragEnd)

    state.handles.forEach { handle ->
        key(handle.type) {
            val anchorInIcon = handleAnchorInIcon(handle.type, handleSizePx)
            val currentOffset by rememberUpdatedState(handle.offset)

            Box(
                modifier = Modifier
                    .offset {
                        IntOffset(
                            (currentOffset.x - anchorInIcon.x).roundToInt(),
                            (currentOffset.y - anchorInIcon.y).roundToInt(),
                        )
                    }
                    .pointerInput(handle.type) {
                        var dragAnchor = Offset.Zero
                        detectDragGestures(
                            onDragStart = {
                                dragAnchor = Offset(currentOffset.x, currentOffset.y)
                                latestOnDragStart(handle.type)
                            },
                            onDragEnd = { latestOnDragEnd(handle.type) },
                            onDragCancel = { latestOnDragEnd(handle.type) },
                        ) { change, dragAmount ->
                            change.consume()
                            dragAnchor += dragAmount
                            latestOnDrag(handle.type, dragAnchor)
                        }
                    }
            ) {
                MongolSelectionHandleIcon(type = handle.type, color = color)
            }
        }
    }
}

object MongolSelectionHandlesCalculator {
    private const val HANDLE_SIZE_DP = 30f
    private const val HANDLE_RADIUS_RATIO = 0.4f

    fun calculate(
        painter: MongolTextPainter,
        selection: MongolSelection,
        density: Float, // Pass density to calculate accurate pixel offset
        activeHandle: MongolSelectionHandleType? = null,
    ): MongolSelectionHandlesState {
        val normalized = selection.normalized()
        if (normalized.isCollapsed) {
            return MongolSelectionHandlesState(
                handles = emptyList(),
                activeHandle = activeHandle,
            )
        }

        val handleRadiusPx = HANDLE_SIZE_DP * density * HANDLE_RADIUS_RATIO
        val selectionBoxes = painter.getBoxesForRange(normalized.start, normalized.end)

        val startHandleOffset = if (selectionBoxes.isNotEmpty()) {
            val first = selectionBoxes.first()
            CoreOffset(x = first.left - 2f * density, y = first.top - 2f * density)
        } else {
            val raw = painter.getOffsetForCaret(TextPosition(normalized.start))
            CoreOffset(x = raw.x - 2f * density, y = raw.y - 2f * density)
        }

        val endHandleOffset = if (selectionBoxes.isNotEmpty()) {
            val last = selectionBoxes.last()
            CoreOffset(x = last.right, y = last.bottom + 1f * density)
        } else {
            val raw = painter.getOffsetForCaret(TextPosition(normalized.end))
            CoreOffset(x = raw.x, y = raw.y + 1f * density)
        }

        return MongolSelectionHandlesState(
            handles = listOf(
                MongolSelectionHandle(
                    type = MongolSelectionHandleType.START,
                    offset = startHandleOffset,
                ),
                MongolSelectionHandle(
                    type = MongolSelectionHandleType.END,
                    offset = endHandleOffset,
                ),
            ),
            activeHandle = activeHandle,
        )
    }
}
