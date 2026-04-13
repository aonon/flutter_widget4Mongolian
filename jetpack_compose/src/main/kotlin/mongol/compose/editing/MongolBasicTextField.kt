package mongol.compose.editing

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
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
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.MongolTextPainter
import mongol.compose.core.MongolTextTools
import mongol.compose.core.RunMetrics
import mongol.compose.core.TextRun
import mongol.compose.core.TextRunMeasurer
import mongol.compose.core.VerticalGlyphPlacementPolicy
import mongol.compose.layout.MongolTextMeasuredLayout
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Editable-stage text canvas backed by MongolTextPainter APIs.
 *
 * This component currently supports:
 * - Caret placement on tap
 * - Word selection on long press
 * - Selection and caret rendering
 *
 * Keyboard input wiring is the next step.
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
    normalizeTextChange: (String, String) -> String = { _, proposed -> proposed },
    onTextChange: (String) -> Unit = {},
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    onFocusChanged: (Boolean) -> Unit = {},
) {
    val focusRequester = remember { FocusRequester() }
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    @Suppress("DEPRECATION")
    val clipboardManager = LocalClipboardManager.current
    val density = LocalDensity.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val textMeasurer = rememberTextMeasurer()
    val caretAlpha by rememberInfiniteTransition(label = "mongolCaretBlink").animateFloat(
        initialValue = 1f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 450, easing = LinearEasing),
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
    val inputSession = remember(state, onTextChange, normalizeTextChange) {
        DefaultMongolInputSession(state, onTextChange, normalizeTextChange)
    }

    // Declare mutable state BEFORE it is referenced in LaunchedEffect keys.
    var widthPx by remember { mutableIntStateOf(1) }
    var heightPx by remember { mutableIntStateOf(1) }
    var dragAnchor by remember { mutableIntStateOf(-1) }
    var handleDragAnchor by remember { mutableIntStateOf(-1) }
    var activeHandleType by remember { mutableStateOf<MongolSelectionHandleType?>(null) }
    var hasFocus by remember { mutableStateOf(false) }
    var imeBridgeHasFocus by remember { mutableStateOf(false) }
    var imeBridgeView by remember { mutableStateOf<MongolImeBridgeView?>(null) }
    var tapCount by remember { mutableIntStateOf(0) }
    var lastTapTimestamp by remember { mutableLongStateOf(0L) }
    val multiTapWindowMs = 320L
    val imeBottomPadding = WindowInsets.ime.asPaddingValues().calculateBottomPadding()
    val bringIntoViewBottomMarginPx = with(density) { 24.dp.toPx() }
    val edgeDragSlopPx = with(density) { 18.dp.toPx() }

    fun resolveCaretPositionForOffset(tapOffset: Offset): mongol.compose.core.TextPosition {
        if (state.text.isEmpty()) {
            return mongol.compose.core.TextPosition(0)
        }

        val boxes = painter.getBoxesForRange(0, state.text.length)
        val hitGlyphBox = boxes.firstOrNull { box ->
            tapOffset.x >= box.left && tapOffset.x <= box.right &&
                tapOffset.y >= box.top && tapOffset.y <= box.bottom
        }

        // Product rule: tapping/dragging in blank area moves caret to end.
        if (hitGlyphBox == null) {
            return mongol.compose.core.TextPosition(state.text.length)
        }

        val nearest = painter.getPositionForOffset(
            mongol.compose.core.Offset(tapOffset.x, tapOffset.y),
        )
        val glyphIndex = nearest.offset.coerceIn(0, (state.text.length - 1).coerceAtLeast(0))
        val glyphBox = painter.getBoxesForRange(glyphIndex, (glyphIndex + 1).coerceAtMost(state.text.length))
            .firstOrNull()
            ?: return nearest

        // For vertical flow, upper half = before glyph, lower half = after glyph.
        val insertAfter = tapOffset.y >= (glyphBox.top + glyphBox.bottom) / 2f
        val resolved = if (insertAfter) {
            (nearest.offset + 1).coerceAtMost(state.text.length)
        } else {
            nearest.offset.coerceIn(0, state.text.length)
        }
        return mongol.compose.core.TextPosition(resolved)
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

        val startEdgeVertical = if (tapOffset.y in top..bottom) abs(tapOffset.x - left) else Float.POSITIVE_INFINITY
        val startEdgeHorizontal = if (tapOffset.x in left..right) abs(tapOffset.y - top) else Float.POSITIVE_INFINITY
        val endEdgeVertical = if (tapOffset.y in top..bottom) abs(tapOffset.x - right) else Float.POSITIVE_INFINITY
        val endEdgeHorizontal = if (tapOffset.x in left..right) abs(tapOffset.y - bottom) else Float.POSITIVE_INFINITY

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
        if (bestScore > edgeDragSlopPx) return null

        return if (startScore <= endScore) {
            MongolSelectionHandleType.START
        } else {
            MongolSelectionHandleType.END
        }
    }

    LaunchedEffect(inputSession, onInputSessionReady) {
        onInputSessionReady(inputSession)
    }
    val selectionHandlesState = remember(state.selection, painter, activeHandleType) {
        MongolSelectionHandlesCalculator.calculate(
            painter = painter,
            selection = state.selection,
            activeHandle = activeHandleType,
        )
    }
    LaunchedEffect(state.selection, painter, activeHandleType, onSelectionHandlesChanged) {
        onSelectionHandlesChanged(selectionHandlesState)
    }
    LaunchedEffect(state.text, state.selection, state.composingRange, imeBridgeView) {
        imeBridgeView?.syncSelection()
    }
    LaunchedEffect(hasFocus, imeBridgeHasFocus, onFocusChanged) {
        val focused = hasFocus || imeBridgeHasFocus
        onFocusChanged(focused)
        if (!focused && state.hasSelection()) {
            state.placeCaret(state.caret)
        }
    }
    LaunchedEffect(hasFocus, imeBottomPadding, widthPx, heightPx) {
        if (hasFocus && widthPx > 0 && heightPx > 0) {
            val fieldRect = androidx.compose.ui.geometry.Rect(
                left = 0f,
                top = 0f,
                right = widthPx.toFloat(),
                bottom = heightPx.toFloat() + bringIntoViewBottomMarginPx,
            )
            bringIntoViewRequester.bringIntoView(fieldRect)
        }
    }

    MongolTextMeasuredLayout(
        painter = painter,
        modifier = Modifier
            .bringIntoViewRequester(bringIntoViewRequester)
            .then(modifier)
            .focusRequester(focusRequester)
            .onFocusChanged { focusState ->
                hasFocus = focusState.isFocused || imeBridgeHasFocus
                if (focusState.isFocused) {
                    keyboardController?.show()
                    imeBridgeView?.showIme()
                }
            }
            .focusable(enabled = enabled)
            .mongolImeSession(inputSession)
            .onPreviewKeyEvent { event ->
                if (!enabled) {
                    return@onPreviewKeyEvent false
                }
                if (event.type != KeyEventType.KeyDown) {
                    return@onPreviewKeyEvent false
                }

                if (event.isCtrlPressed && event.key == Key.A) {
                    state.applyCommand(MongolEditCommand.SelectAll)
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

                if (event.isCtrlPressed && event.key == Key.V) {
                    if (readOnly) return@onPreviewKeyEvent false
                    val pasted = clipboardManager.getText()?.text.orEmpty()
                    if (pasted.isNotEmpty()) {
                        inputSession.commitText(pasted)
                        return@onPreviewKeyEvent true
                    }
                    return@onPreviewKeyEvent false
                }

                if (event.isShiftPressed && event.key == Key.Insert) {
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
                        true
                    }

                    Key.DirectionRight -> {
                        state.applyCommand(
                            command = MongolEditCommand.MoveCaretRight,
                            extendSelection = extendSelection,
                        )
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
                        true
                    }

                    Key.Delete -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        if (state.hasSelection()) {
                            inputSession.commitText("")
                        } else {
                            inputSession.deleteSurroundingText(beforeLength = 0, afterLength = 1)
                        }
                        true
                    }

                    Key.Enter -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        inputSession.commitText("\n")
                        true
                    }

                    else -> {
                        if (readOnly) return@onPreviewKeyEvent false
                        val cp = event.utf16CodePoint
                        if (cp > 0 && !Character.isISOControl(cp)) {
                            inputSession.commitText(String(Character.toChars(cp)))
                            true
                        } else {
                            false
                        }
                    }
                }
            }
            .onSizeChanged { size ->
                widthPx = size.width.coerceAtLeast(1)
                heightPx = size.height.coerceAtLeast(1)
                painter.layout(maxHeight = heightPx.toFloat())
            }
            .pointerInput(state.text, heightPx) {
                if (!enabled) return@pointerInput
                detectTapGestures(
                    onTap = { tapOffset ->
                        focusRequester.requestFocus()
                        keyboardController?.show()
                        imeBridgeView?.showIme()
                        val pos = resolveCaretPositionForOffset(tapOffset)
                        val now = System.currentTimeMillis()
                        tapCount = if (now - lastTapTimestamp <= multiTapWindowMs) {
                            (tapCount % 3) + 1
                        } else {
                            1
                        }
                        lastTapTimestamp = now

                        when (tapCount) {
                            1 -> state.placeCaret(pos)
                            2 -> state.setSelection(painter.getWordBoundary(pos))
                            else -> {
                                state.setSelection(painter.getLineBoundary(pos))
                                tapCount = 0
                            }
                        }
                    },
                    onLongPress = { tapOffset ->
                        focusRequester.requestFocus()
                        val pos = painter.getPositionForOffset(
                            mongol.compose.core.Offset(tapOffset.x, tapOffset.y),
                        )
                        state.setSelection(painter.getLineBoundary(pos))
                    },
                )
            }
            .pointerInput(state.text, heightPx, enabled, readOnly) {
                if (!enabled) return@pointerInput
                detectDragGestures(
                    onDragStart = { dragStart ->
                        focusRequester.requestFocus()
                        keyboardController?.show()
                        imeBridgeView?.showIme()
                        val pos = resolveCaretPositionForOffset(dragStart)
                        val selection = state.selection.normalized()
                        if (selection.isCollapsed) {
                            activeHandleType = MongolSelectionHandleType.CARET
                            dragAnchor = pos.offset
                        } else {
                            val edgeHandle = resolveSelectionDragHandle(dragStart)
                            if (edgeHandle == MongolSelectionHandleType.START) {
                                activeHandleType = MongolSelectionHandleType.START
                                dragAnchor = selection.end
                            } else if (edgeHandle == MongolSelectionHandleType.END) {
                                activeHandleType = MongolSelectionHandleType.END
                                dragAnchor = selection.start
                            } else {
                                val startHandle = selectionHandlesState.handles
                                    .firstOrNull { it.type == MongolSelectionHandleType.START }
                                val endHandle = selectionHandlesState.handles
                                    .firstOrNull { it.type == MongolSelectionHandleType.END }
                                val distStart = startHandle?.let {
                                    distanceToPoint(dragStart, Offset(it.offset.x, it.offset.y))
                                } ?: Float.POSITIVE_INFINITY
                                val distEnd = endHandle?.let {
                                    distanceToPoint(dragStart, Offset(it.offset.x, it.offset.y))
                                } ?: Float.POSITIVE_INFINITY
                                if (distStart <= distEnd) {
                                    activeHandleType = MongolSelectionHandleType.START
                                    dragAnchor = selection.end
                                } else {
                                    activeHandleType = MongolSelectionHandleType.END
                                    dragAnchor = selection.start
                                }
                            }
                        }
                        state.setSelection(dragAnchor, pos.offset)
                    },
                    onDragEnd = {
                        dragAnchor = -1
                        handleDragAnchor = -1
                        activeHandleType = null
                    },
                    onDragCancel = {
                        dragAnchor = -1
                        handleDragAnchor = -1
                        activeHandleType = null
                    },
                    onDrag = { change, _ ->
                        change.consume()
                        val anchor = if (dragAnchor >= 0) dragAnchor else state.caret.offset
                        val pos = resolveCaretPositionForOffset(change.position)
                        state.setSelection(anchor, pos.offset)
                    },
                )
            },
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f, fill = true)) {
                AndroidView(
                    factory = { context ->
                        MongolImeBridgeView(context).also { view ->
                            view.session = inputSession
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
                        imeBridgeView = view
                    },
                    modifier = Modifier.size(1.dp),
                )

                Canvas(modifier = Modifier.fillMaxSize()) {
                    val selection = state.selection.normalized()
                    // Build per-character style map for rich-text span rendering.
                    val styleMap = state.spans.buildStyleMap(
                        textLength = state.text.length,
                        baseStyle = style.toSpanStyle(),
                    )
                    for (run in painter.textRuns) {
                        if (run.start >= run.end) continue

                        for (index in run.start until run.end) {
                            val char = state.text[index]
                            if (char == '\n') continue

                            val box =
                                painter.getBoxesForRange(index, index + 1).firstOrNull() ?: continue
                            if (index in selection.start until selection.end) {
                                drawRect(
                                    color = selectionColor,
                                    topLeft = Offset(box.left, box.top),
                                    size = Size(box.right - box.left, box.bottom - box.top),
                                )
                            }
                        }

                        val useRunLevelDraw = !run.isRotated && state.spans.isEmpty()
                        if (useRunLevelDraw) {
                            val runText = state.text.substring(run.start, run.end)
                            if (runText.isNotBlank()) {
                                val runBoxes = painter.getBoxesForRange(run.start, run.end)
                                if (runBoxes.isNotEmpty()) {
                                    val left = runBoxes.minOf { it.left }
                                    val top = runBoxes.minOf { it.top }
                                    val layout = runLayouts[run]
                                    if (layout != null) {
                                        val runHeight =
                                            layout.size.height.toFloat().coerceAtLeast(1f)
                                        withTransform({
                                            translate(left = left + runHeight, top = top)
                                            rotate(degrees = 90f, pivot = Offset.Zero)
                                        }) {
                                            drawText(
                                                textLayoutResult = layout,
                                                topLeft = Offset.Zero,
                                            )
                                        }
                                        continue
                                    }
                                }
                            }
                        }

                        if (run.isRotated) {
                            MongolTextTools.forEachGraphemeCluster(
                                state.text,
                                run.start,
                                run.end,
                            ) { clusterStart, clusterEnd ->
                                val clusterText = state.text.substring(clusterStart, clusterEnd)
                                if (clusterText == "\n") {
                                    return@forEachGraphemeCluster
                                }

                                val box = painter.getBoxesForRange(clusterStart, clusterEnd)
                                    .firstOrNull() ?: return@forEachGraphemeCluster

                                val glyphStyle = if (state.spans.isEmpty()) {
                                    style
                                } else {
                                    style.merge(styleMap[clusterStart])
                                }
                                val glyphLayout = textMeasurer.measure(
                                    text = clusterText,
                                    style = glyphStyle,
                                )
                                val codePoint = Character.codePointAt(state.text, clusterStart)
                                with(VerticalGlyphPlacementPolicy) {
                                    drawGlyphInVerticalBox(
                                        codePoint = codePoint,
                                        previousCodePoint = previousVisibleCodePoint(
                                            state.text,
                                            clusterStart,
                                        ),
                                        box = box,
                                        glyphLayout = glyphLayout,
                                    )
                                }
                            }
                        } else {
                            MongolTextTools.forEachGraphemeCluster(
                                state.text,
                                run.start,
                                run.end,
                            ) { clusterStart, clusterEnd ->
                                val clusterText = state.text.substring(clusterStart, clusterEnd)
                                if (clusterText == "\n") return@forEachGraphemeCluster

                                val box = painter.getBoxesForRange(clusterStart, clusterEnd)
                                    .firstOrNull() ?: return@forEachGraphemeCluster
                                val clusterStyle = if (state.spans.isEmpty()) {
                                    style
                                } else {
                                    style.merge(styleMap[clusterStart])
                                }
                                drawText(
                                    textMeasurer = textMeasurer,
                                    text = clusterText,
                                    topLeft = Offset(box.left, box.top),
                                    style = clusterStyle,
                                )
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
                    val caretStroke = 4f
                    val caretLeft = caretOffset.x
                    val caretRight = caretLeft + caretWidth
                    val capHalfHeight = 4f
                    val clampedCaretY = caretY.coerceAtLeast(capHalfHeight + caretStroke / 2f)
                    val visibleCaretColor = caretColor.copy(alpha = caretAlpha)
                    val shouldShowCaret = enabled && (hasFocus || imeBridgeHasFocus)
                    if (shouldShowCaret) {
                        drawLine(
                            color = visibleCaretColor,
                            start = Offset(caretLeft, clampedCaretY),
                            end = Offset(caretRight, clampedCaretY),
                            strokeWidth = caretStroke,
                        )
                        drawLine(
                            color = visibleCaretColor,
                            start = Offset(caretLeft, clampedCaretY - capHalfHeight),
                            end = Offset(caretLeft, clampedCaretY + capHalfHeight),
                            strokeWidth = caretStroke,
                        )
                        drawLine(
                            color = visibleCaretColor,
                            start = Offset(caretRight, clampedCaretY - capHalfHeight),
                            end = Offset(caretRight, clampedCaretY + capHalfHeight),
                            strokeWidth = caretStroke,
                        )
                    }
                }

                val shouldShowHandles = enabled && (hasFocus || imeBridgeHasFocus)
                if (selectionHandlesState.isVisible && shouldShowHandles && !state.selection.isCollapsed) {
                    MongolSelectionHandles(
                        state = selectionHandlesState,
                        color = selectionColor.copy(alpha = 1f),
                        onHandleDragStart = { handleType ->
                            val normalized = state.selection.normalized()
                            activeHandleType = handleType
                            handleDragAnchor = when (handleType) {
                                MongolSelectionHandleType.START -> normalized.end
                                MongolSelectionHandleType.END -> normalized.start
                                MongolSelectionHandleType.CARET -> -1
                            }
                        },
                        onHandleDragEnd = {
                            handleDragAnchor = -1
                            activeHandleType = null
                        },
                        onHandleDrag = { handleType, absolutePos ->
                            val position = resolveCaretPositionForOffset(absolutePos).offset
                            val normalized = state.selection.normalized()
                            activeHandleType = handleType
                            when (handleType) {
                                MongolSelectionHandleType.CARET -> {
                                    state.placeCaret(mongol.compose.core.TextPosition(position))
                                }

                                MongolSelectionHandleType.START -> {
                                    val anchor = if (handleDragAnchor >= 0) handleDragAnchor else normalized.end
                                    state.setSelection(position, anchor)
                                }

                                MongolSelectionHandleType.END -> {
                                    val anchor = if (handleDragAnchor >= 0) handleDragAnchor else normalized.start
                                    state.setSelection(anchor, position)
                                }
                            }
                        },
                    )
                }
            }
        }
    }
}

/**
 * Value-based overload to align with Compose text field usage style.
 */
@Composable
fun MongolBasicTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color(0xFF1B5E20),
    selectionColor: Color = Color(0x552196F3),
    normalizeTextChange: (String, String) -> String = { _, proposed -> proposed },
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    onFocusChanged: (Boolean) -> Unit = {},
) {
    val state = rememberMongolEditableState(initialText = value)

    LaunchedEffect(value) {
        if (state.text != value) {
            state.replaceText(value)
        }
    }

    MongolBasicTextField(
        state = state,
        modifier = modifier,
        style = textStyle,
        textAlign = textAlign,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        enabled = enabled,
        readOnly = readOnly,
        caretColor = caretColor,
        selectionColor = selectionColor,
        normalizeTextChange = normalizeTextChange,
        onTextChange = onValueChange,
        onInputSessionReady = onInputSessionReady,
        onSelectionHandlesChanged = onSelectionHandlesChanged,
        onFocusChanged = onFocusChanged,
    )
}

