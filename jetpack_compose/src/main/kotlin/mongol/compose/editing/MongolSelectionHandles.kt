package mongol.compose.editing

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import mongol.compose.core.MongolTextPainter
import mongol.compose.core.TextPosition
import kotlin.math.roundToInt
import mongol.compose.core.Offset as CoreOffset

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
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val r = w / 2f

        when (type) {
            MongolSelectionHandleType.START -> {
                val path = Path().apply {
                    moveTo(w, h)
                    lineTo(r, h)
                    arcTo(Rect(0f, 0f, w, h), 90f, 270f, false)
                    lineTo(w, r)
                    close()
                }
                drawPath(path, color, style = Fill)
            }

            MongolSelectionHandleType.END -> {
                val path = Path().apply {
                    moveTo(0f, 0f)
                    lineTo(w - r, 0f)
                    arcTo(Rect(0f, 0f, w, h), 270f, 270f, false)
                    lineTo(0f, h - r)
                    close()
                }
                drawPath(path, color, style = Fill)
            }

            MongolSelectionHandleType.CARET -> {
                // For CARET in vertical text, the handle is a teardrop pointing left.
                // The tip of the teardrop should be at the horizontal caret line.
                // We use (w/2, 0) as the tip/anchor point relative to the icon box.
                val path = Path().apply {
                    moveTo(0f, 0f)
                    lineTo(w - r, 0f)
                    arcTo(Rect(0f, 0f, w, h), 270f, 270f, false)
                    lineTo(0f, h - r)
                    close()
                }
                // Rotate to point left (90 degrees clockwise from the 'END' orientation which points down-right)
                rotate(degrees = -45f, pivot = Offset(r, r)) {
                    drawPath(path, color, style = Fill)
                }
            }
        }
    }
}

private fun handleAnchorInIcon(
    type: MongolSelectionHandleType,
    visualSizePx: Float,
): Offset {
    return when (type) {
        MongolSelectionHandleType.START -> Offset(visualSizePx, visualSizePx)
        MongolSelectionHandleType.END -> Offset(0f, 0f)
        MongolSelectionHandleType.CARET -> Offset(0f, visualSizePx / 2f)
    }
}

@Composable
fun MongolSelectionHandles(
    state: MongolSelectionHandlesState,
    onHandleDrag: (MongolSelectionHandleType, Offset) -> Unit,
    onHandleDragStart: (MongolSelectionHandleType) -> Unit = {},
    onHandleDragEnd: (MongolSelectionHandleType) -> Unit = {},
    onTap: (Offset) -> Unit = {},
    onDoubleTap: (Offset) -> Unit = {},
    onLongPress: (Offset) -> Unit = {},
    color: Color = Color(0xFF2196F3),
) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    val haptic = LocalHapticFeedback.current
    val visualSizeDp = 22.dp
    val visualSizePx = with(density) { visualSizeDp.toPx() }
    val touchSizeDp = 40.dp
    val touchSizePx = with(density) { touchSizeDp.toPx() }

    val latestOnDrag by rememberUpdatedState(onHandleDrag)
    val latestOnDragStart by rememberUpdatedState(onHandleDragStart)
    val latestOnDragEnd by rememberUpdatedState(onHandleDragEnd)
    val latestOnTap by rememberUpdatedState(onTap)
    val latestOnDoubleTap by rememberUpdatedState(onDoubleTap)
    val latestOnLongPress by rememberUpdatedState(onLongPress)

    state.handles.forEach { handle ->
        key(handle.type) {
            val currentOffset by rememberUpdatedState(handle.offset)
            var dragOffset by remember { mutableStateOf<Offset?>(null) }
            val displayOffset = dragOffset ?: Offset(currentOffset.x, currentOffset.y)

            LaunchedEffect(currentOffset) {
                if (dragOffset != null) {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
            }

            val anchorInTouchArea = Offset(touchSizePx / 2f, touchSizePx / 2f)

            Popup(
                offset = IntOffset(
                    (displayOffset.x - anchorInTouchArea.x).roundToInt(),
                    (displayOffset.y - anchorInTouchArea.y).roundToInt(),
                ),
                properties = PopupProperties(
                    focusable = false,
                    dismissOnBackPress = false,
                    dismissOnClickOutside = false,
                    excludeFromSystemGesture = true,
                )
            ) {
                Box(
                    modifier = Modifier
                        .size(touchSizeDp)
                        .pointerInput(handle.type) {
                            detectTapGestures(
                                onTap = { localOffset ->
                                    val globalX =
                                        currentOffset.x + (localOffset.x - anchorInTouchArea.x)
                                    val globalY =
                                        currentOffset.y + (localOffset.y - anchorInTouchArea.y)
                                    latestOnTap(Offset(globalX, globalY))
                                },
                                onDoubleTap = { localOffset ->
                                    val globalX =
                                        currentOffset.x + (localOffset.x - anchorInTouchArea.x)
                                    val globalY =
                                        currentOffset.y + (localOffset.y - anchorInTouchArea.y)
                                    latestOnDoubleTap(Offset(globalX, globalY))
                                },
                                onLongPress = { localOffset ->
                                    val globalX =
                                        currentOffset.x + (localOffset.x - anchorInTouchArea.x)
                                    val globalY =
                                        currentOffset.y + (localOffset.y - anchorInTouchArea.y)
                                    latestOnLongPress(Offset(globalX, globalY))
                                }
                            )
                        }
                        .pointerInput(handle.type) {
                            detectDragGestures(
                                onDragStart = { offset ->
                                    dragOffset = Offset(currentOffset.x, currentOffset.y)
                                    latestOnDragStart(handle.type)
                                },
                                onDragEnd = {
                                    dragOffset = null
                                    latestOnDragEnd(handle.type)
                                },
                                onDragCancel = {
                                    dragOffset = null
                                    latestOnDragEnd(handle.type)
                                },
                            ) { change, dragAmount ->
                                change.consume()
                                val current =
                                    dragOffset ?: Offset(currentOffset.x, currentOffset.y)
                                val next = current + dragAmount
                                dragOffset = next
                                latestOnDrag(handle.type, next)
                            }
                        }
                ) {
                    val iconAnchor = handleAnchorInIcon(handle.type, visualSizePx)
                    MongolSelectionHandleIcon(
                        type = handle.type,
                        color = color,
                        modifier = Modifier
                            .size(visualSizeDp)
                            .offset {
                                IntOffset(
                                    (anchorInTouchArea.x - iconAnchor.x).roundToInt(),
                                    (anchorInTouchArea.y - iconAnchor.y).roundToInt()
                                )
                            }
                    )
                }
            }
        }
    }
}

object MongolSelectionHandlesCalculator {
    fun calculate(
        painter: MongolTextPainter,
        selection: MongolSelection,
        density: Float,
        activeHandle: MongolSelectionHandleType? = null,
        showCaretHandle: Boolean = false,
    ): MongolSelectionHandlesState {
        val normalized = selection.normalized()

        if (normalized.isCollapsed) {
            if (activeHandle == MongolSelectionHandleType.CARET || showCaretHandle) {
                val raw = painter.getOffsetForCaret(TextPosition(normalized.start))

                // For CARET handle in vertical Mongolian text, we want the handle icon
                // to appear to the RIGHT of the caret line, with the tip pointing LEFT
                // to anchor at the RIGHT edge of the caret line.

                // 1. Find the width of the glyph at the caret to determine the right boundary.
                val glyphBox = if (normalized.start in painter.text.indices) {
                    painter.getBoxesForRange(normalized.start, normalized.start + 1).firstOrNull()
                } else if (normalized.start > 0) {
                    painter.getBoxesForRange(normalized.start - 1, normalized.start).firstOrNull()
                } else null

                val caretRight = glyphBox?.right ?: (raw.x + 18f) // fallback to typical width

                val caretHandle = MongolSelectionHandle(
                    type = MongolSelectionHandleType.CARET,
                    offset = mongol.compose.core.Offset(caretRight, raw.y)
                )
                return MongolSelectionHandlesState(
                    handles = listOf(caretHandle),
                    activeHandle = activeHandle
                )
            }
            return MongolSelectionHandlesState(handles = emptyList(), activeHandle = activeHandle)
        }

        val startBox = painter.getBoxesForRange(
            normalized.start,
            (normalized.start + 1).coerceAtMost(painter.text.length)
        )
            .firstOrNull()
        val endBox = if (normalized.end > normalized.start) {
            painter.getBoxesForRange(normalized.end - 1, normalized.end).firstOrNull()
        } else null

        val startHandleOffset = if (startBox != null) {
            CoreOffset(x = startBox.left, y = startBox.top)
        } else {
            val raw = painter.getOffsetForCaret(TextPosition(normalized.start))
            CoreOffset(x = raw.x, y = raw.y)
        }

        val endHandleOffset = if (endBox != null) {
            CoreOffset(x = endBox.right, y = endBox.bottom)
        } else {
            val raw = painter.getOffsetForCaret(TextPosition(normalized.end))
            CoreOffset(x = raw.x, y = raw.y)
        }

        return MongolSelectionHandlesState(
            handles = listOf(
                MongolSelectionHandle(
                    type = MongolSelectionHandleType.START,
                    offset = startHandleOffset
                ),
                MongolSelectionHandle(
                    type = MongolSelectionHandleType.END,
                    offset = endHandleOffset
                ),
            ),
            activeHandle = activeHandle,
        )
    }
}
