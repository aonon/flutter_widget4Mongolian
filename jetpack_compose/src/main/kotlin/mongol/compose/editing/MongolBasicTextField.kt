package mongol.compose.editing

import android.text.InputType
import android.util.Log
import android.view.inputmethod.EditorInfo
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.key.utf16CodePoint
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import mongol.compose.R
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.MongolTextPainter
import mongol.compose.core.MongolTextTools
import mongol.compose.core.RunMetrics
import mongol.compose.core.TextRun
import mongol.compose.core.TextRunMeasurer
import mongol.compose.core.VerticalGlyphPlacementPolicy
import mongol.compose.layout.MongolTextMeasuredLayout
import mongol.compose.text.MongolText
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Editable-stage text canvas backed by MongolTextPainter APIs.
 *
 * Supports caret placement on tap, word selection on long press,
 * selection and caret rendering, and keyboard/IME input.
 */
@Composable
fun MongolBasicTextField(
    state: MongolEditableState,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color(0xFF1B5E20),
    selectionColor: Color = Color(0x552196F3),
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    singleLine: Boolean = false,
    normalizeTextChange: (String, String) -> String = { _, proposed -> proposed },
    onTextChange: (String) -> Unit = {},
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    onFocusChanged: (Boolean) -> Unit = {},
) {
    val focusRequester = remember { FocusRequester() }
    val bringIntoViewRequester = remember { BringIntoViewRequester() }

    @Suppress("DEPRECATION") val clipboardManager = LocalClipboardManager.current
    val density = LocalDensity.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val textMeasurer = rememberTextMeasurer()

    val caretAlpha by rememberInfiniteTransition(label = "mongolCaretBlink").animateFloat(
        initialValue = 1f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 533, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "mongolCaretAlpha",
    )
    val runMeasurer = remember(textMeasurer, style) {
        object : TextRunMeasurer {
            override fun measureRun(text: String, isRotated: Boolean): RunMetrics {
                val result = textMeasurer.measure(text = text, style = style)
                val runHeight = result.size.height.toFloat().coerceAtLeast(1f)
                val runWidth = result.size.width.toFloat().coerceAtLeast(1f)
                val rawAdvances = mutableListOf<Float>()
                MongolTextTools.forEachGraphemeCluster(text) { clusterStart, clusterEnd ->
                    rawAdvances += textMeasurer.measure(
                        text = text.substring(clusterStart, clusterEnd),
                        style = style,
                    ).size.width.toFloat().coerceAtLeast(1f)
                }
                if (rawAdvances.isEmpty()) {
                    rawAdvances += runWidth
                }
                val scale = if (rawAdvances.sum() > 0f) runWidth / rawAdvances.sum() else 1f
                return RunMetrics(
                    advance = runWidth,
                    crossAxis = runHeight,
                    ascent = runHeight * 0.8f,
                    descent = runHeight * 0.2f,
                    clusterAdvances = rawAdvances.map { it * scale },
                )
            }
        }
    }

    val painter = remember(state.text, textAlign, textRuns, rotateCjk, runMeasurer) {
        MongolTextPainter(
            text = state.text,
            textRuns = textRuns,
            textAlign = textAlign,
            rotateCjk = rotateCjk,
            runMeasurer = runMeasurer,
        )
    }
    val runLayouts = remember(state.text, style, painter.textRuns) {
        painter.textRuns.associateWith { run ->
            textMeasurer.measure(
                text = state.text.substring(run.start, run.end),
                style = style,
            )
        }
    }

    var canvasWidthPx by remember { mutableIntStateOf(1) }
    var canvasHeightPx by remember { mutableIntStateOf(1) }
    var hasFocus by remember { mutableStateOf(false) }
    var imeBridgeHasFocus by remember { mutableStateOf(false) }
    var showContextMenu by remember { mutableStateOf(false) }
    var fieldSize by remember { mutableStateOf(IntSize(1, 1)) }
    var contextMenuSize by remember { mutableStateOf(IntSize(1, 1)) }

    var selectionGestureInProgress by remember { mutableStateOf(false) }
    var dragSelectionAnchor by remember { mutableIntStateOf(-1) }
    var handleDragAnchor by remember { mutableIntStateOf(-1) }
    var activeHandleType by remember { mutableStateOf<MongolSelectionHandleType?>(null) }
    var showCaretHandle by remember { mutableStateOf(false) }

    val inputSession = remember(state, onTextChange, normalizeTextChange, readOnly) {
        DefaultMongolInputSession(
            state = state,
            onTextChange = onTextChange,
            normalizeTextChange = normalizeTextChange,
            readOnly = readOnly,
            onSessionAction = {
                showCaretHandle = false
            })
    }
    var imeBridgeView by remember { mutableStateOf<MongolImeBridgeView?>(null) }

    val imeBottomPadding = WindowInsets.ime.asPaddingValues().calculateBottomPadding()
    val bringIntoViewBottomMarginPx = with(density) { 24.dp.toPx() }
    with(density) { 24.dp.toPx() }
    val selectionDragEdgeSlopPx = with(density) { 18.dp.toPx() }
    val contextMenuMarginPx = with(density) { 8.dp.toPx().roundToInt() }
    val contextMenuMinWidthPx = with(density) { 40.dp.roundToPx() }
    val contextMenuMinHeightPx = with(density) { 120.dp.roundToPx() }

    data class ContextMenuAnchor(val left: Float, val right: Float, val centerY: Float)

    fun resolveCaretPositionForOffset(tapOffset: Offset): mongol.compose.core.TextPosition {
        if (state.text.isEmpty()) {
            return mongol.compose.core.TextPosition(0)
        }

        // Clip to the canvas bounds to ensure edge taps resolve correctly.
        val x = tapOffset.x.coerceIn(0f, canvasWidthPx.toFloat().coerceAtLeast(1f))
        val y = tapOffset.y.coerceIn(0f, canvasHeightPx.toFloat().coerceAtLeast(1f))
        val coreOffset = mongol.compose.core.Offset(x, y)

        // Delegate to painter. getPositionForOffset now handles midpoint logic internally.
        return painter.getPositionForOffset(coreOffset)
    }

    fun distanceToPoint(from: Offset, to: Offset): Float {
        val dx = from.x - to.x
        val dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }

    fun resolveSelectionDragHandle(tapOffset: Offset): MongolSelectionHandleType? {
        val normalized = state.selection.normalized()
        if (normalized.isCollapsed) return null

        val boxes = painter.getBoxesForRange(normalized.start, normalized.end)
        if (boxes.isEmpty()) return null

        val left = boxes.minOf { it.left }
        val top = boxes.minOf { it.top }
        val right = boxes.maxOf { it.right }
        val bottom = boxes.maxOf { it.bottom }

        val startCorner = Offset(left, top)
        val endCorner = Offset(right, bottom)

        val startEdgeVertical =
            if (tapOffset.y in top..bottom) abs(tapOffset.x - left) else Float.POSITIVE_INFINITY
        val startEdgeHorizontal =
            if (tapOffset.x in left..right) abs(tapOffset.y - top) else Float.POSITIVE_INFINITY
        val endEdgeVertical =
            if (tapOffset.y in top..bottom) abs(tapOffset.x - right) else Float.POSITIVE_INFINITY
        val endEdgeHorizontal =
            if (tapOffset.x in left..right) abs(tapOffset.y - bottom) else Float.POSITIVE_INFINITY

        val startScore = minOf(
            distanceToPoint(tapOffset, startCorner),
            startEdgeVertical,
            startEdgeHorizontal,
        )
        val endScore = minOf(
            distanceToPoint(tapOffset, endCorner),
            endEdgeVertical,
            endEdgeHorizontal,
        )

        val bestScore = minOf(startScore, endScore)
        if (bestScore > selectionDragEdgeSlopPx) return null

        return if (startScore <= endScore) {
            MongolSelectionHandleType.START
        } else {
            MongolSelectionHandleType.END
        }
    }

    // ========== Helper: Context Menu Positioning ==========
    fun resolveContextMenuAnchor(): ContextMenuAnchor {
        val normalized = state.selection.normalized()
        if (!normalized.isCollapsed) {
            val boxes = painter.getBoxesForRange(normalized.start, normalized.end)
            if (boxes.isNotEmpty()) {
                val left = boxes.minOf { it.left }
                val top = boxes.minOf { it.top }
                val right = boxes.maxOf { it.right }
                val bottom = boxes.maxOf { it.bottom }
                return ContextMenuAnchor(
                    left = left,
                    right = right,
                    centerY = (top + bottom) / 2f,
                )
            }
        }

        val caretOffset = painter.getOffsetForCaret(state.caret)
        return ContextMenuAnchor(
            left = caretOffset.x,
            right = caretOffset.x,
            centerY = caretOffset.y,
        )
    }

    fun resolveContextMenuWindowOffset(anchor: ContextMenuAnchor): IntOffset {
        val menuWidth = contextMenuSize.width.coerceAtLeast(contextMenuMinWidthPx)
        val menuHeight = contextMenuSize.height.coerceAtLeast(contextMenuMinHeightPx)

        // Prefer right side, fall back to left if there's not enough space
        val leftSpace = anchor.left - contextMenuMarginPx
        val rightSpace = fieldSize.width - anchor.right - contextMenuMarginPx

        val localX = when {
            rightSpace >= menuWidth -> {
                (anchor.right + contextMenuMarginPx).roundToInt()
            }

            else -> {
                if (leftSpace >= menuWidth) {
                    (anchor.left - menuWidth - contextMenuMarginPx).roundToInt()
                } else {
                    (anchor.right + contextMenuMarginPx).roundToInt()
                }
            }
        }

        var localY = (anchor.centerY - menuHeight / 2f).roundToInt()
        val minY = -menuHeight + contextMenuMarginPx
        val maxY = fieldSize.height - contextMenuMarginPx
        localY = localY.coerceIn(minY, maxY)

        return IntOffset(x = localX, y = localY)
    }

    LaunchedEffect(inputSession, onInputSessionReady) {
        onInputSessionReady(inputSession)
    }

    val selectionHandlesState = remember(
        state.selection,
        painter,
        activeHandleType,
        density,
        textAlign,
        canvasHeightPx,
        showCaretHandle
    ) {
        if (canvasHeightPx > 0) {
            painter.layout(maxHeight = canvasHeightPx.toFloat())
        }
        MongolSelectionHandlesCalculator.calculate(
            painter = painter,
            selection = state.selection,
            density = density.density,
            activeHandle = activeHandleType,
            showCaretHandle = showCaretHandle,
        )
    }
    LaunchedEffect(selectionHandlesState, onSelectionHandlesChanged) {
        onSelectionHandlesChanged(selectionHandlesState)
    }
    LaunchedEffect(state.text, state.selection, state.composingRange, imeBridgeView) {
        imeBridgeView?.syncSelection()
    }

    LaunchedEffect(
        hasFocus, imeBridgeHasFocus, selectionGestureInProgress, showContextMenu, readOnly, enabled
    ) {
        val focused = hasFocus || imeBridgeHasFocus || selectionGestureInProgress || showContextMenu
        onFocusChanged(focused)

        // Clear selection when losing focus
        if (!focused && state.hasSelection()) {
            state.placeCaret(state.caret)
        }

        // Hide menu when losing focus
        if (!focused) {
            showContextMenu = false
        }

        // Keep keyboard open while focused and not read-only
        if (focused && !readOnly && enabled) {
            keyboardController?.show()
            imeBridgeView?.showIme()
        }
    }
    LaunchedEffect(hasFocus, imeBottomPadding, canvasWidthPx, canvasHeightPx) {
        if (hasFocus && canvasWidthPx > 0 && canvasHeightPx > 0) {
            val fieldRect = androidx.compose.ui.geometry.Rect(
                left = 0f,
                top = 0f,
                right = canvasWidthPx.toFloat(),
                bottom = canvasHeightPx.toFloat() + bringIntoViewBottomMarginPx,
            )
            bringIntoViewRequester.bringIntoView(fieldRect)
        }
    }

    LaunchedEffect(state.selection, hasFocus, imeBridgeHasFocus, selectionGestureInProgress) {
        val focused = hasFocus || imeBridgeHasFocus
        if (!focused || selectionGestureInProgress) {
            showContextMenu = false
            return@LaunchedEffect
        }

        val hasSelection = !state.selection.normalized().isCollapsed
        if (hasSelection) {
            kotlinx.coroutines.delay(300)
            // Re-check state to ensure no new gesture occurred during delay
            if (!selectionGestureInProgress && (hasFocus || imeBridgeHasFocus)) {
                showContextMenu = true
            }
        }
    }

    MongolTextMeasuredLayout(
        painter = painter,
        modifier = Modifier.bringIntoViewRequester(bringIntoViewRequester).then(modifier)
            .focusRequester(focusRequester).onFocusChanged { focusState ->
                hasFocus = focusState.isFocused || imeBridgeHasFocus
                if (focusState.isFocused) {
                    if (!readOnly) {
                        keyboardController?.show()
                        imeBridgeView?.showIme()
                    }
                }
            }.focusable(enabled = enabled).mongolImeSession(inputSession)
            .onPreviewKeyEvent { event ->
                if (!enabled) {
                    return@onPreviewKeyEvent false
                }
                if (event.type != KeyEventType.KeyDown) {
                    return@onPreviewKeyEvent false
                }

                if (event.isCtrlPressed && event.key == Key.A) {
                    state.applyCommand(MongolEditCommand.SelectAll)
                    showCaretHandle = false
                    return@onPreviewKeyEvent true
                }

                if (event.isCtrlPressed && event.key == Key.Z) {
                    state.applyCommand(MongolEditCommand.Undo)
                    onTextChange(state.text)
                    return@onPreviewKeyEvent true
                }

                if (event.isCtrlPressed && event.key == Key.Y) {
                    state.applyCommand(MongolEditCommand.Redo)
                    onTextChange(state.text)
                    return@onPreviewKeyEvent true
                }

                if (event.isCtrlPressed && event.key == Key.C) {
                    val selected = state.selectedText()
                    if (selected.isNotEmpty()) {
                        clipboardManager.setText(AnnotatedString(selected))
                        return@onPreviewKeyEvent true
                    }
                    return@onPreviewKeyEvent false
                }

                if (event.isCtrlPressed && event.key == Key.Insert) {
                    val selected = state.selectedText()
                    if (selected.isNotEmpty()) {
                        clipboardManager.setText(AnnotatedString(selected))
                        return@onPreviewKeyEvent true
                    }
                    return@onPreviewKeyEvent false
                }

                if (event.isCtrlPressed && event.key == Key.X) {
                    if (readOnly) return@onPreviewKeyEvent false
                    val selected = state.selectedText()
                    if (selected.isNotEmpty()) {
                        clipboardManager.setText(AnnotatedString(selected))
                        inputSession.commitText("")
                        return@onPreviewKeyEvent true
                    }
                    return@onPreviewKeyEvent false
                }

                if (event.isCtrlPressed && (event.key == Key.V || event.key == Key.Insert && event.isShiftPressed)) {
                    if (readOnly) return@onPreviewKeyEvent false
                    val pasted = clipboardManager.getText()?.text.orEmpty()
                    if (pasted.isNotEmpty()) {
                        inputSession.commitText(pasted)
                        return@onPreviewKeyEvent true
                    }
                    return@onPreviewKeyEvent false
                }

                if (event.isShiftPressed && event.key == Key.Delete) {
                    if (readOnly) return@onPreviewKeyEvent false
                    val selected = state.selectedText()
                    if (selected.isNotEmpty()) {
                        clipboardManager.setText(AnnotatedString(selected))
                        inputSession.commitText("")
                        return@onPreviewKeyEvent true
                    }
                    return@onPreviewKeyEvent false
                }

                val extendSelection = event.isShiftPressed

                when (event.key) {
                    Key.DirectionLeft -> {
                        state.applyCommand(
                            command = MongolEditCommand.MoveCaretLeft,
                            extendSelection = extendSelection,
                        )
                        showCaretHandle = false
                        true
                    }

                    Key.DirectionRight -> {
                        state.applyCommand(
                            command = MongolEditCommand.MoveCaretRight,
                            extendSelection = extendSelection,
                        )
                        showCaretHandle = false
                        true
                    }

                    Key.MoveHome -> {
                        if (event.isCtrlPressed) {
                            state.applyCommand(
                                command = MongolEditCommand.MoveCaretToStart,
                                extendSelection = extendSelection,
                            )
                        } else {
                            val anchor = state.caret.offset
                            val lineRange = painter.getLineBoundary(state.caret)
                            if (extendSelection) {
                                inputSession.setSelection(anchor, lineRange.start)
                            } else {
                                inputSession.setSelection(lineRange.start, lineRange.start)
                            }
                        }
                        showCaretHandle = false
                        true
                    }

                    Key.MoveEnd -> {
                        if (event.isCtrlPressed) {
                            state.applyCommand(
                                command = MongolEditCommand.MoveCaretToEnd,
                                extendSelection = extendSelection,
                            )
                        } else {
                            val anchor = state.caret.offset
                            val lineRange = painter.getLineBoundary(state.caret)
                            if (extendSelection) {
                                inputSession.setSelection(anchor, lineRange.end)
                            } else {
                                inputSession.setSelection(lineRange.end, lineRange.end)
                            }
                        }
                        showCaretHandle = false
                        true
                    }

                    Key.Escape -> {
                        state.placeCaret(state.caret)
                        true
                    }

                    Key.Backspace -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        if (state.hasSelection()) {
                            inputSession.commitText("")
                        } else {
                            inputSession.deleteSurroundingText(beforeLength = 1, afterLength = 0)
                        }
                        showCaretHandle = false
                        true
                    }

                    Key.Delete -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        if (state.hasSelection()) {
                            inputSession.commitText("")
                        } else {
                            inputSession.deleteSurroundingText(beforeLength = 0, afterLength = 1)
                        }
                        showCaretHandle = false
                        true
                    }

                    Key.Enter -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        inputSession.commitText("\n")
                        showCaretHandle = false
                        true
                    }

                    else -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        val cp = event.utf16CodePoint
                        if (cp > 0 && !Character.isISOControl(cp)) {
                            inputSession.commitText(String(Character.toChars(cp)))
                            showCaretHandle = false
                            true
                        } else {
                            false
                        }
                    }
                }
            }.onGloballyPositioned { coords ->
                canvasWidthPx = coords.size.width.coerceAtLeast(1)
                canvasHeightPx = coords.size.height.coerceAtLeast(1)
                painter.layout(maxHeight = canvasHeightPx.toFloat())
            }.pointerInput(canvasHeightPx, textAlign, enabled, readOnly, painter) {
                if (!enabled) return@pointerInput
                coroutineScope {
                    launch {
                        detectTapGestures(onTap = { tapOffset ->
                            val pos = resolveCaretPositionForOffset(tapOffset)
                            focusRequester.requestFocus()
                            if (!readOnly && enabled) {
                                keyboardController?.show()
                                imeBridgeView?.showIme()
                            }
                            // Force show handle even if pos is same as current caret
                            state.placeCaret(pos)
                            showCaretHandle = !readOnly
                            showContextMenu = false
                            
                            // To ensure visual feedback, we can trigger a slight state change if needed,
                            // but placeCaret already triggers recomposition.
                        }, onDoubleTap = { tapOffset ->
                            focusRequester.requestFocus()
                            val pos = resolveCaretPositionForOffset(tapOffset)
                            state.setSelection(painter.getWordBoundary(pos))
                            showCaretHandle = false
                            showContextMenu = true
                        }, onLongPress = { tapOffset ->
                            focusRequester.requestFocus()
                            val pos = resolveCaretPositionForOffset(tapOffset)
                            state.setSelection(painter.getWordBoundary(pos))
                            showCaretHandle = false
                            showContextMenu = true
                        })
                    }
                    launch {
                        detectDragGestures(onDragStart = { dragStart ->
                            selectionGestureInProgress = true
                            showContextMenu = false
                            focusRequester.requestFocus()
                            if (!readOnly) {
                                keyboardController?.show()
                                imeBridgeView?.showIme()
                            }
                            val pos = resolveCaretPositionForOffset(dragStart)
                            val selection = state.selection.normalized()
                            if (selection.isCollapsed) {
                                activeHandleType = MongolSelectionHandleType.CARET
                                dragSelectionAnchor = pos.offset
                            } else {
                                val edgeHandle = resolveSelectionDragHandle(dragStart)
                                activeHandleType = edgeHandle ?: MongolSelectionHandleType.END
                                dragSelectionAnchor =
                                    if (activeHandleType == MongolSelectionHandleType.START) selection.end else selection.start
                            }
                            state.setSelection(dragSelectionAnchor, pos.offset)
                        }, onDragEnd = {
                            selectionGestureInProgress = false
                            activeHandleType = null
                            dragSelectionAnchor = -1
                            // Note: Delayed menu display is handled in LaunchedEffect
                        }, onDragCancel = {
                            selectionGestureInProgress = false
                            activeHandleType = null
                            dragSelectionAnchor = -1
                        }, onDrag = { change, _ ->
                            change.consume()
                            val anchor =
                                if (dragSelectionAnchor >= 0) dragSelectionAnchor else state.caret.offset
                            val pos = resolveCaretPositionForOffset(change.position)
                            state.setSelection(anchor, pos.offset)
                        })
                    }
                }
            }) {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier.weight(1f, fill = true).onGloballyPositioned { coordinates ->
                    fieldSize = coordinates.size
                },
            ) {
                AndroidView(
                    factory = { context ->
                        MongolImeBridgeView(context).also { view ->
                            view.session = inputSession
                            view.inputType = keyboardOptions.toInputType(singleLine)
                            view.imeOptions = keyboardOptions.toImeOptions(singleLine)
                            view.onFocusChangeListener =
                                android.view.View.OnFocusChangeListener { _, focused ->
                                    imeBridgeHasFocus = focused
                                    if (focused) {
                                        hasFocus = true
                                    }
                                }
                            imeBridgeView = view
                        }
                    },
                    update = { view ->
                        view.session = inputSession
                        view.inputType = keyboardOptions.toInputType(singleLine)
                        view.imeOptions = keyboardOptions.toImeOptions(singleLine)
                        imeBridgeView = view
                    },
                    modifier = Modifier.size(1.dp),
                )

                Canvas(
                    modifier = Modifier.fillMaxSize().clip(RectangleShape)
                ) {
                    clipRect(left = 0f, top = 0f, right = size.width, bottom = size.height) {
                        val selection = state.selection.normalized()

                        if (!selection.isCollapsed) {
                            val selectionBoxes =
                                painter.getBoxesForRange(selection.start, selection.end)
                            if (selectionBoxes.isNotEmpty()) {
                                val selMinTop = selectionBoxes.minOf { it.top }
                                val selMaxBottom = selectionBoxes.maxOf { it.bottom }
                                val columnGroups = selectionBoxes.groupBy { it.left }.toList()
                                    .sortedBy { it.first }
                                val n = columnGroups.size
                                if (n == 1) {
                                    val boxes = columnGroups[0].second
                                    drawRect(
                                        color = selectionColor,
                                        topLeft = Offset(
                                            boxes.first().left, boxes.minOf { it.top }),
                                        size = Size(
                                            boxes.first().right - boxes.first().left,
                                            boxes.maxOf { it.bottom } - boxes.minOf { it.top })
                                    )
                                } else {
                                    val firstCol = columnGroups[0]
                                    val lastCol = columnGroups[n - 1]

                                    drawRect(
                                        color = selectionColor,
                                        topLeft = Offset(
                                            firstCol.first, firstCol.second.minOf { it.top }),
                                        size = Size(
                                            columnGroups[1].first - firstCol.first,
                                            selMaxBottom - firstCol.second.minOf { it.top })
                                    )

                                    if (n > 2) {
                                        val midLeft = columnGroups[1].first
                                        val midRight = lastCol.first
                                        drawRect(
                                            color = selectionColor,
                                            topLeft = Offset(midLeft, selMinTop),
                                            size = Size(
                                                midRight - midLeft, selMaxBottom - selMinTop
                                            )
                                        )
                                    }

                                    drawRect(
                                        color = selectionColor,
                                        topLeft = Offset(lastCol.first, selMinTop),
                                        size = Size(
                                            lastCol.second.first().right - lastCol.first,
                                            lastCol.second.maxOf { it.bottom } - selMinTop))
                                }
                            }
                        }

                        for (run in painter.textRuns) {
                            if (run.start >= run.end) continue

                            val useForcedClusterDraw =
                                !run.isRotated && painter.requiresClusterDrawing(run.start, run.end)

                            val useRunLevelDraw =
                                !run.isRotated && !useForcedClusterDraw && state.spans.isEmpty()
                            if (useRunLevelDraw) {
                                val runText = state.text.substring(run.start, run.end)
                                if (runText.isNotBlank()) {
                                    val runBoxes = painter.getBoxesForRange(run.start, run.end)
                                    if (runBoxes.isNotEmpty()) {
                                        val left = runBoxes.minOf { it.left }
                                        val top = runBoxes.minOf { it.top }
                                        val right = runBoxes.maxOf { it.right }
                                        val bottom = runBoxes.maxOf { it.bottom }
                                        val layout = runLayouts[run]
                                        if (layout != null) {
                                            val runHeight =
                                                layout.size.height.toFloat().coerceAtLeast(1f)
                                            clipRect(
                                                left = left,
                                                top = top,
                                                right = right,
                                                bottom = bottom,
                                            ) {
                                                withTransform({
                                                    translate(left = left + runHeight, top = top)
                                                    rotate(degrees = 90f, pivot = Offset.Zero)
                                                }) {
                                                    drawText(
                                                        textLayoutResult = layout,
                                                        topLeft = Offset.Zero,
                                                    )
                                                }
                                            }
                                            continue
                                        }
                                    }
                                }
                            }

                            if (run.isRotated) {
                                val layout = runLayouts[run]
                                if (layout != null) {
                                    MongolTextTools.forEachGraphemeCluster(
                                        state.text, run.start, run.end
                                    ) { clusterStart, clusterEnd ->
                                        val clusterText =
                                            state.text.substring(clusterStart, clusterEnd)
                                        if (clusterText == "\n") return@forEachGraphemeCluster

                                        val box = painter.getBoxesForRange(clusterStart, clusterEnd)
                                            .firstOrNull() ?: return@forEachGraphemeCluster
                                        val codePoint =
                                            Character.codePointAt(state.text, clusterStart)
                                        val glyphLayout = textMeasurer.measure(
                                            text = state.text.substring(clusterStart, clusterEnd),
                                            style = style,
                                        )

                                        with(VerticalGlyphPlacementPolicy) {
                                            drawGlyphInVerticalBox(
                                                codePoint = codePoint,
                                                previousCodePoint = VerticalGlyphPlacementPolicy.previousVisibleCodePoint(
                                                    state.text, clusterStart
                                                ),
                                                box = box,
                                                glyphLayout = glyphLayout,
                                            )
                                        }
                                    }
                                }
                            } else if (useForcedClusterDraw) {
                                MongolTextTools.forEachGraphemeCluster(
                                    state.text, run.start, run.end
                                ) { clusterStart, clusterEnd ->
                                    val clusterText = state.text.substring(clusterStart, clusterEnd)
                                    if (clusterText == "\n" || clusterText.isBlank()) {
                                        return@forEachGraphemeCluster
                                    }

                                    val box = painter.getBoxesForRange(clusterStart, clusterEnd)
                                        .firstOrNull() ?: return@forEachGraphemeCluster
                                    val glyphLayout = textMeasurer.measure(
                                        text = clusterText,
                                        style = style,
                                    )
                                    val glyphHeight =
                                        glyphLayout.size.height.toFloat().coerceAtLeast(1f)

                                    clipRect(
                                        left = box.left,
                                        top = box.top,
                                        right = box.right,
                                        bottom = box.bottom,
                                    ) {
                                        withTransform({
                                            translate(left = box.left + glyphHeight, top = box.top)
                                            rotate(degrees = 90f, pivot = Offset.Zero)
                                        }) {
                                            drawText(
                                                textLayoutResult = glyphLayout,
                                                topLeft = Offset.Zero,
                                            )
                                        }
                                    }
                                }
                            } else {
                                val layout = runLayouts[run]
                                if (layout != null) {
                                    val runBoxes = painter.getBoxesForRange(run.start, run.end)
                                    if (runBoxes.isNotEmpty()) {
                                        val left = runBoxes.minOf { it.left }
                                        val top = runBoxes.minOf { it.top }
                                        val right = runBoxes.maxOf { it.right }
                                        val bottom = runBoxes.maxOf { it.bottom }
                                        clipRect(
                                            left = left,
                                            top = top,
                                            right = right,
                                            bottom = bottom,
                                        ) {
                                            drawText(layout, topLeft = Offset(left, top))
                                        }
                                    }
                                }
                            }
                        }

                        val caretOffset = painter.getOffsetForCaret(state.caret)
                        val directCaretBox = if (state.caret.offset in state.text.indices) {
                            painter.getBoxesForRange(state.caret.offset, state.caret.offset + 1)
                                .firstOrNull()
                        } else {
                            null
                        }
                        val prevCaretBox = if (state.caret.offset > 0) {
                            painter.getBoxesForRange(state.caret.offset - 1, state.caret.offset)
                                .firstOrNull()
                        } else {
                            null
                        }
                        val fallbackCaretLayout = textMeasurer.measure(
                            text = "ᠠ",
                            style = style,
                        )
                        val fallbackCaretWidth =
                            fallbackCaretLayout.size.height.toFloat().coerceAtLeast(1f)
                        val caretWidth = (directCaretBox?.let { it.right - it.left }
                            ?: prevCaretBox?.let { it.right - it.left }
                            ?: fallbackCaretWidth).coerceAtLeast(1f)
                        val caretY = caretOffset.y
                        val caretStroke = with(density) { 2.dp.toPx() }
                        val caretLeft = caretOffset.x - 1.dp.toPx()
                        val caretRight = caretLeft + caretWidth + 2.dp.toPx()
                        val visibleCaretColor = caretColor.copy(alpha = caretAlpha)

                        // ========== RENDER: Caret (Blinking text insertion point) ==========
                        val shouldShowCaret = enabled && !readOnly && (hasFocus || imeBridgeHasFocus)
                        if (shouldShowCaret) {
                            drawLine(
                                color = visibleCaretColor,
                                start = Offset(caretLeft, caretY),
                                end = Offset(caretRight, caretY),
                                strokeWidth = caretStroke,
                            )
                        }
                    }
                }

                val shouldShowHandles = enabled && (hasFocus || imeBridgeHasFocus)
                if (selectionHandlesState.isVisible && shouldShowHandles) {
                    MongolSelectionHandles(
                        state = selectionHandlesState,
                        color = selectionColor.copy(alpha = 1f),
                        onHandleDragStart = { handleType ->
                            selectionGestureInProgress = true
                            showContextMenu = false
                            if (handleType == MongolSelectionHandleType.CARET) {
                                showCaretHandle = !readOnly
                            }
                            val normalized = state.selection.normalized()
                            activeHandleType = handleType
                            handleDragAnchor = when (handleType) {
                                MongolSelectionHandleType.START -> normalized.end
                                MongolSelectionHandleType.END -> normalized.start
                                MongolSelectionHandleType.CARET -> -1
                            }
                        },
                        onHandleDragEnd = {
                            selectionGestureInProgress = false
                            handleDragAnchor = -1
                            activeHandleType = null
                        },
                        onHandleDrag = { handleType, nextLocalPos ->
                            val position = resolveCaretPositionForOffset(nextLocalPos).offset
                            val normalized = state.selection.normalized()
                            activeHandleType = handleType
                            when (handleType) {
                                MongolSelectionHandleType.CARET -> {
                                    state.placeCaret(mongol.compose.core.TextPosition(position))
                                }

                                MongolSelectionHandleType.START -> {
                                    val anchor =
                                        if (handleDragAnchor >= 0) handleDragAnchor else normalized.end
                                    state.setSelection(position, anchor)
                                }

                                MongolSelectionHandleType.END -> {
                                    val anchor =
                                        if (handleDragAnchor >= 0) handleDragAnchor else normalized.start
                                    state.setSelection(anchor, position)
                                }
                            }
                        },
                        onTap = { tapOffset ->
                            val pos = resolveCaretPositionForOffset(tapOffset)
                            focusRequester.requestFocus()
                            if (!readOnly && enabled) {
                                keyboardController?.show()
                                imeBridgeView?.showIme()
                            }
                            state.placeCaret(pos)
                            showCaretHandle = !readOnly
                            showContextMenu = false
                        },
                        onDoubleTap = { tapOffset ->
                            focusRequester.requestFocus()
                            val pos = resolveCaretPositionForOffset(tapOffset)
                            state.setSelection(painter.getWordBoundary(pos))
                            showCaretHandle = false
                            showContextMenu = true
                        },
                        onLongPress = { tapOffset ->
                            focusRequester.requestFocus()
                            val pos = resolveCaretPositionForOffset(tapOffset)
                            state.setSelection(painter.getWordBoundary(pos))
                            showCaretHandle = false
                            showContextMenu = true
                        }
                    )
                }

                if (enabled && showContextMenu) {
                    val anchor = resolveContextMenuAnchor()
                    val popupOffset = resolveContextMenuWindowOffset(anchor)
                    val selectedText = state.selectedText()
                    val clipboardText = clipboardManager.getText()?.text.orEmpty()
                    val hasSelection = selectedText.isNotEmpty()
                    val canCut = hasSelection && !readOnly
                    val canPaste = clipboardText.isNotEmpty() && !readOnly

                    Popup(
                        alignment = androidx.compose.ui.Alignment.TopStart,
                        offset = popupOffset,
                        onDismissRequest = { showContextMenu = false },
                        properties = PopupProperties(
                            focusable = false,
                            dismissOnBackPress = false,
                            dismissOnClickOutside = true,
                            usePlatformDefaultWidth = false,
                        ),
                    ) {
                        Surface(
                            shape = MaterialTheme.shapes.small,
                            tonalElevation = 6.dp,
                            shadowElevation = 8.dp,
                            modifier = Modifier.onSizeChanged { contextMenuSize = it },
                        ) {
                            Column {
                                ContextMenuItem(
                                    label = "ᠪᠦᠬᠦᠨ ᠢ",
                                    enabled = state.text.isNotEmpty(),
                                    onClick = {
                                        state.selectAll()
                                    },
                                )
                                ContextMenuItem(
                                    label = "ᠬᠠᠭᠤᠯ",
                                    enabled = hasSelection,
                                    onClick = {
                                        clipboardManager.setText(AnnotatedString(selectedText))
                                        showContextMenu = false
                                    },
                                )
                                ContextMenuItem(
                                    label = "ᠨᠠᠭ\u180Eᠠ",
                                    enabled = canPaste,
                                    onClick = {
                                        inputSession.commitText(clipboardText)
                                        showContextMenu = false
                                    },
                                )
                                ContextMenuItem(
                                    label = "ᠬᠠᠢᠴᠢᠯᠠ",
                                    enabled = canCut,
                                    onClick = {
                                        clipboardManager.setText(AnnotatedString(selectedText))
                                        inputSession.commitText("")
                                        showContextMenu = false
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContextMenuItem(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val font = FontFamily(Font(R.font.moskwa))
    val textColor = if (enabled) {
        MaterialTheme.colorScheme.onSurface
    } else {
        MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
    }

    MongolText(
        text = label,
        style = TextStyle(color = textColor, fontFamily = font),
        modifier = Modifier.clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

/**
 * Value-based overload for direct string value management.
 *
 * Use this overload when you manage text state directly as a String.
 * For more advanced control (undo/redo, selective styling), use state-based overload.
 *
 * @param text Current text content
 * @param onValueChange Callback when text changes
 */
@Composable
fun MongolBasicTextField(
    text: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color(0xFF1B5E20),
    selectionColor: Color = Color(0x552196F3),
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    singleLine: Boolean = false,
    normalizeTextChange: (String, String) -> String = { _, proposed -> proposed },
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    onFocusChanged: (Boolean) -> Unit = {},
) {
    val state = rememberMongolEditableState(initialText = text)

    LaunchedEffect(text) {
        if (state.text != text) {
            state.replaceText(text)
        }
    }

    MongolBasicTextField(
        state = state,
        modifier = modifier,
        style = style,
        textAlign = textAlign,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        enabled = enabled,
        readOnly = readOnly,
        caretColor = caretColor,
        selectionColor = selectionColor,
        keyboardOptions = keyboardOptions,
        singleLine = singleLine,
        normalizeTextChange = normalizeTextChange,
        onTextChange = onValueChange,
        onInputSessionReady = onInputSessionReady,
        onSelectionHandlesChanged = onSelectionHandlesChanged,
        onFocusChanged = onFocusChanged,
    )
}

private fun KeyboardOptions.toImeOptions(singleLine: Boolean): Int {
    var imeOptions = when (imeAction) {
        ImeAction.None -> EditorInfo.IME_ACTION_NONE
        ImeAction.Default -> if (singleLine) EditorInfo.IME_ACTION_DONE else EditorInfo.IME_ACTION_NONE
        ImeAction.Go -> EditorInfo.IME_ACTION_GO
        ImeAction.Search -> EditorInfo.IME_ACTION_SEARCH
        ImeAction.Send -> EditorInfo.IME_ACTION_SEND
        ImeAction.Previous -> EditorInfo.IME_ACTION_PREVIOUS
        ImeAction.Next -> EditorInfo.IME_ACTION_NEXT
        ImeAction.Done -> EditorInfo.IME_ACTION_DONE
        else -> EditorInfo.IME_ACTION_UNSPECIFIED
    }
    imeOptions = imeOptions or EditorInfo.IME_FLAG_NO_FULLSCREEN
    return imeOptions
}

private fun KeyboardOptions.toInputType(singleLine: Boolean): Int {
    var type = when (keyboardType) {
        KeyboardType.Text -> InputType.TYPE_CLASS_TEXT
        KeyboardType.Number -> InputType.TYPE_CLASS_NUMBER
        KeyboardType.Phone -> InputType.TYPE_CLASS_PHONE
        KeyboardType.Uri -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
        KeyboardType.Email -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
        KeyboardType.Password -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        KeyboardType.NumberPassword -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
        KeyboardType.Decimal -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
        else -> InputType.TYPE_CLASS_TEXT
    }
    if (type == InputType.TYPE_CLASS_TEXT && !singleLine) {
        type = type or InputType.TYPE_TEXT_FLAG_MULTI_LINE
    }
    return type
}

