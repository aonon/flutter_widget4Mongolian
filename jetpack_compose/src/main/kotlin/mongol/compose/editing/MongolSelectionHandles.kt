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
    Canvas(modifier = modifier.size(30.dp)) {
        // R = 40% of canvas size. Mathematically: |tip - center| = R*√2 ensures
        // the two axis-aligned triangle legs are exactly tangent to the circle.
        val R = size.width * 0.4f
        val W = size.width

        when (type) {
            MongolSelectionHandleType.START -> {
                // Circle upper-left: center=(R,R), pointer tip lower-right at (2R,2R)
                drawCircle(color = color, radius = R, center = Offset(R, R))
                val path = Path().apply {
                    moveTo(2 * R, 2 * R)  // 90° tip
                    lineTo(R, 2 * R)      // horizontal leg (tangent point)
                    lineTo(2 * R, R)      // vertical leg (tangent point)
                    close()
                }
                drawPath(path, color)
            }

            MongolSelectionHandleType.END -> {
                // Circle lower-right: center=(W-R,W-R), pointer tip upper-left at (W-2R,W-2R)
                drawCircle(color = color, radius = R, center = Offset(W - R, W - R))
                val path = Path().apply {
                    moveTo(W - 2 * R, W - 2 * R)  // 90° tip
                    lineTo(W - R, W - 2 * R)       // horizontal leg (tangent point)
                    lineTo(W - 2 * R, W - R)       // vertical leg (tangent point)
                    close()
                }
                drawPath(path, color)
            }

            MongolSelectionHandleType.CARET -> {
                drawCircle(
                    color = color,
                    radius = W * 0.3f,
                    center = center,
                )
            }
        }
    }
}

private fun handleAnchorInIcon(
    type: MongolSelectionHandleType,
    handleSizePx: Float,
): Offset {
    // Tip is at 2R = 2*(0.4*W) = 0.8*W for START, and (W-2R) = 0.2*W for END.
    return when (type) {
        MongolSelectionHandleType.START -> Offset(handleSizePx * 0.8f, handleSizePx * 0.8f)
        MongolSelectionHandleType.END -> Offset(handleSizePx * 0.2f, handleSizePx * 0.2f)
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
    // Must match Canvas size in MongolSelectionHandleIcon so anchor fractions are correct.
    val handleSizePx = with(density) { 30.dp.toPx() }

    // Hoist callbacks into State so they can be read inside pointerInput without
    // needing them as restart keys (which would cancel in-progress gestures).
    val latestOnDrag by rememberUpdatedState(onHandleDrag)
    val latestOnDragStart by rememberUpdatedState(onHandleDragStart)
    val latestOnDragEnd by rememberUpdatedState(onHandleDragEnd)

    state.handles.forEach { handle ->
        key(handle.type) {
            val anchorInIcon = handleAnchorInIcon(handle.type, handleSizePx)
            // Track the latest offset without it being a pointerInput restart key.
            val currentOffset by rememberUpdatedState(handle.offset)

            Box(
                modifier = Modifier
                    .offset {
                        val off = currentOffset
                        IntOffset(
                            (off.x - anchorInIcon.x).roundToInt(),
                            (off.y - anchorInIcon.y).roundToInt(),
                        )
                    }
                    // Only handle.type as key — offset changes during drag must NOT
                    // restart the gesture (that would interrupt the drag mid-way).
                    .pointerInput(handle.type) {
                        var dragAnchor = Offset.Zero
                        detectDragGestures(
                            onDragStart = {
                                val off = currentOffset
                                dragAnchor = Offset(off.x, off.y)
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
    fun calculate(
        painter: MongolTextPainter,
        selection: MongolSelection,
        activeHandle: MongolSelectionHandleType? = null,
    ): MongolSelectionHandlesState {
        val normalized = selection.normalized()
        if (normalized.isCollapsed) {
            return MongolSelectionHandlesState(
                handles = emptyList(),
                activeHandle = activeHandle,
            )
        }

        val start = painter.getOffsetForCaret(TextPosition(normalized.start))
        val end = painter.getOffsetForCaret(TextPosition(normalized.end))
        val selectionBoxes = painter.getBoxesForRange(normalized.start, normalized.end)
        val startHandleOffset = if (selectionBoxes.isNotEmpty()) {
            CoreOffset(
                x = selectionBoxes.minOf { it.left },
                y = selectionBoxes.minOf { it.top },
            )
        } else {
            start
        }
        val endHandleOffset = if (selectionBoxes.isNotEmpty()) {
            CoreOffset(
                x = selectionBoxes.maxOf { it.right },
                y = selectionBoxes.maxOf { it.bottom },
            )
        } else {
            end
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
