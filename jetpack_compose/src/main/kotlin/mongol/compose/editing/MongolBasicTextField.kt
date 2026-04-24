package mongol.compose.editing

import android.text.InputType
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
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.input.TextFieldLineLimits
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layout
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
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Editable-stage text canvas backed by MongolTextPainter APIs.
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
    lineLimits: TextFieldLineLimits = TextFieldLineLimits.Default,
    normalizeTextChange: (String, String) -> String = { _, proposed -> proposed },
    onTextChange: (String) -> Unit = {},
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    onFocusChanged: (Boolean) -> Unit = {},
) {
    val focusRequester = remember { FocusRequester() }
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    val density = LocalDensity.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val textMeasurer = rememberTextMeasurer()
    @Suppress("DEPRECATION") val clipboardManager = LocalClipboardManager.current

    val isSingleLine = lineLimits == TextFieldLineLimits.SingleLine
    val minLines = if (isSingleLine) 1 else (lineLimits as? TextFieldLineLimits.MultiLine)?.minHeightInLines ?: 1
    val maxLines = if (isSingleLine) 1 else (lineLimits as? TextFieldLineLimits.MultiLine)?.maxHeightInLines ?: Int.MAX_VALUE

    val caretAlpha by rememberInfiniteTransition(label = "blink").animateFloat(
        initialValue = 1f, targetValue = 0f,
        animationSpec = infiniteRepeatable(animation = tween(durationMillis = 533, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "alpha"
    )
    
    val runMeasurer = remember(textMeasurer, style) {
        object : TextRunMeasurer {
            override fun measureRun(text: String, isRotated: Boolean): RunMetrics {
                val result = textMeasurer.measure(text = text, style = style)
                val rawAdvances = mutableListOf<Float>()
                MongolTextTools.forEachGraphemeCluster(text) { s, e ->
                    rawAdvances += textMeasurer.measure(text.substring(s, e), style).size.width.toFloat().coerceAtLeast(1f)
                }
                if (rawAdvances.isEmpty()) rawAdvances += result.size.width.toFloat().coerceAtLeast(1f)
                val scale = result.size.width.toFloat() / max(rawAdvances.sum(), 1f)
                return RunMetrics(result.size.width.toFloat(), result.size.height.toFloat(), result.size.height * 0.8f, result.size.height * 0.2f, rawAdvances.map { it * scale })
            }
        }
    }

    val horizontalScrollState = rememberScrollState()
    val verticalScrollState = rememberScrollState()
    val scrollModifier = if (isSingleLine) Modifier.verticalScroll(verticalScrollState) else Modifier.horizontalScroll(horizontalScrollState)

    val painter = remember(state.text, textAlign, textRuns, rotateCjk, runMeasurer, lineLimits) {
        MongolTextPainter(
            text = state.text,
            textRuns = textRuns,
            textAlign = textAlign,
            // For an editable field, maxLines in painter causes truncation.
            // We only use it for SingleLine to prevent wrapping.
            // For MultiLine, we let the painter measure everything and limit the viewport in the layout.
            maxLines = if (isSingleLine) 1 else null,
            rotateCjk = rotateCjk,
            runMeasurer = runMeasurer
        )
    }
    val runLayouts = remember(state.text, style, painter.textRuns) {
        painter.textRuns.associateWith { run -> textMeasurer.measure(state.text.substring(run.start, run.end), style) }
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
        DefaultMongolInputSession(state, onTextChange, normalizeTextChange, readOnly, { showCaretHandle = false })
    }
    var imeBridgeView by remember { mutableStateOf<MongolImeBridgeView?>(null) }

    val fontSizePx = with(density) { if (style.fontSize.isSp) style.fontSize.toPx() else 16.sp.toPx() }
    val lineSpanPx = (fontSizePx * 1.5f).roundToInt()
    val imeBottomPadding = WindowInsets.ime.asPaddingValues().calculateBottomPadding()

    data class ContextMenuAnchor(val left: Float, val right: Float, val centerY: Float)

    fun resolveCaretPositionForOffset(tapOffset: Offset): mongol.compose.core.TextPosition {
        // Use coordinates relative to the Canvas by adding current scroll offsets
        val adjustedX = tapOffset.x + horizontalScrollState.value
        val adjustedY = tapOffset.y + verticalScrollState.value
        val x = adjustedX.coerceIn(0f, max(1f, painter.width))
        val y = adjustedY.coerceIn(0f, max(1f, painter.height))
        return painter.getPositionForOffset(mongol.compose.core.Offset(x, y))
    }

    fun resolveSelectionDragHandle(tapOffset: Offset): MongolSelectionHandleType? {
        val normalized = state.selection.normalized()
        if (normalized.isCollapsed) return null
        
        // Use coordinates relative to the Canvas
        val adjustedX = tapOffset.x + horizontalScrollState.value
        val adjustedY = tapOffset.y + verticalScrollState.value
        
        val boxes = painter.getBoxesForRange(normalized.start, normalized.end)
        if (boxes.isEmpty()) return null
        val left = boxes.minOf { it.left }
        val top = boxes.minOf { it.top }
        val right = boxes.maxOf { it.right }
        val bottom = boxes.maxOf { it.bottom }
        val slop = with(density) { 18.dp.toPx() }
        if (adjustedY in top..bottom) {
            if (abs(adjustedX - left) < slop) return MongolSelectionHandleType.START
            if (abs(adjustedX - right) < slop) return MongolSelectionHandleType.END
        }
        return null
    }

    fun resolveContextMenuAnchor(): ContextMenuAnchor {
        val scrollX = horizontalScrollState.value.toFloat(); val scrollY = verticalScrollState.value.toFloat()
        val normalized = state.selection.normalized()
        if (!normalized.isCollapsed) {
            val boxes = painter.getBoxesForRange(normalized.start, normalized.end)
            if (boxes.isNotEmpty()) {
                val left = boxes.minOf { it.left } - scrollX
                val top = boxes.minOf { it.top } - scrollY
                val right = boxes.maxOf { it.right } - scrollX
                val bottom = boxes.maxOf { it.bottom } - scrollY
                return ContextMenuAnchor(left, right, (top + bottom) / 2f)
            }
        }
        val co = painter.getOffsetForCaret(state.caret)
        return ContextMenuAnchor(co.x - scrollX, co.x - scrollX, co.y - scrollY)
    }

    fun resolveContextMenuWindowOffset(anchor: ContextMenuAnchor): IntOffset {
        val menuWidth = contextMenuSize.width.coerceAtLeast(50); val menuHeight = contextMenuSize.height.coerceAtLeast(100)
        val handleMargin = with(density) { 35.dp.toPx() }
        val rightSpace = fieldSize.width - anchor.right; val leftSpace = anchor.left
        val localX = if (rightSpace >= menuWidth + handleMargin || rightSpace >= leftSpace) (anchor.right + handleMargin).roundToInt()
                    else (anchor.left - menuWidth - handleMargin).roundToInt()
        val localY = (anchor.centerY - menuHeight / 2f).roundToInt()
        return IntOffset(localX, localY)
    }

    val selectionHandlesState = remember(state.selection, painter, activeHandleType, density, textAlign, canvasHeightPx, showCaretHandle) {
        if (canvasHeightPx > 0) painter.layout(maxHeight = canvasHeightPx.toFloat())
        MongolSelectionHandlesCalculator.calculate(painter, state.selection, density.density, activeHandleType, showCaretHandle)
    }
    LaunchedEffect(selectionHandlesState, onSelectionHandlesChanged) { onSelectionHandlesChanged(selectionHandlesState) }
    LaunchedEffect(state.text, state.selection, state.composingRange, imeBridgeView) { imeBridgeView?.syncSelection() }

    LaunchedEffect(hasFocus, imeBridgeHasFocus, selectionGestureInProgress, showContextMenu, readOnly, enabled) {
        val focused = hasFocus || imeBridgeHasFocus || selectionGestureInProgress || showContextMenu
        onFocusChanged(focused)
        if (!focused) { showContextMenu = false; if (state.hasSelection()) state.placeCaret(state.caret) }
        if (focused && !readOnly && enabled) { keyboardController?.show(); imeBridgeView?.showIme() }
    }

    LaunchedEffect(state.selection, hasFocus, imeBridgeHasFocus, selectionGestureInProgress) {
        val focused = hasFocus || imeBridgeHasFocus
        if (!focused || selectionGestureInProgress) { showContextMenu = false; return@LaunchedEffect }
        if (!state.selection.normalized().isCollapsed) {
            kotlinx.coroutines.delay(300)
            if (!selectionGestureInProgress && (hasFocus || imeBridgeHasFocus)) showContextMenu = true
        }
    }

    LaunchedEffect(state.caret, painter, hasFocus, isSingleLine, fieldSize, canvasHeightPx) {
        if (!hasFocus || canvasHeightPx <= 0) return@LaunchedEffect
        
        // 1. 同步布局测量
        painter.layout(maxHeight = canvasHeightPx.toFloat())
        
        // 模仿 TextField: 等待测量完成并提供足够的重试，确保滚动条 maxValue 已更新
        var retry = 0
        val co = painter.getOffsetForCaret(state.caret)
        val metrics = painter.computeLineMetrics()
        val metric = metrics.find { co.x >= it.baseline - 0.5f && co.x < it.baseline + it.width + 0.5f } ?: metrics.lastOrNull()
        val targetX = metric?.baseline ?: co.x
        val targetWidth = metric?.width ?: lineSpanPx.toFloat()
        
        while (horizontalScrollState.maxValue < (targetX + targetWidth - fieldSize.width) && retry < 10) {
            kotlinx.coroutines.delay(16)
            retry++
        }

        // 2. 内部滚动：直接驱动 ScrollState 以实现最稳定的跟随
        if (!isSingleLine && fieldSize.width > 0) {
            val vw = fieldSize.width.toFloat()
            val padding = with(density) { 20.dp.toPx() }
            val currentScroll = horizontalScrollState.value.toFloat()
            
            if (targetX < currentScroll) {
                horizontalScrollState.animateScrollTo((targetX - padding).toInt().coerceAtLeast(0))
            } else if (targetX + targetWidth > currentScroll + vw) {
                horizontalScrollState.animateScrollTo((targetX + targetWidth - vw + padding).toInt().coerceAtLeast(0))
            }
        } else if (isSingleLine && fieldSize.height > 0) {
            val vh = fieldSize.height.toFloat()
            val padding = with(density) { 20.dp.toPx() }
            if (co.y < verticalScrollState.value) {
                verticalScrollState.animateScrollTo(max(0, (co.y - padding).toInt()))
            } else if (co.y > verticalScrollState.value + vh) {
                verticalScrollState.animateScrollTo((co.y - vh + padding).toInt())
            }
        }

        // 3. 外部避让：模仿 TextField，仅向上传递垂直方向的可见性请求
        // 通过将 left 锁定在当前滚动位置，父容器会认为水平方向“已完全可见”，从而不会发生界面漂移
        val scrollX = horizontalScrollState.value.toFloat()
        val scrollY = verticalScrollState.value.toFloat()
        val caretRectExternal = with(density) {
            androidx.compose.ui.geometry.Rect(
                left = scrollX, 
                top = co.y - scrollY,
                right = scrollX + 1f,
                bottom = (co.y - scrollY) + 40.dp.toPx()
            )
        }
        bringIntoViewRequester.bringIntoView(caretRectExternal)
    }

    MongolTextMeasuredLayout(
        painter = painter, 
        modifier = Modifier.then(modifier).focusRequester(focusRequester).onFocusChanged { hasFocus = it.isFocused || imeBridgeHasFocus; if (it.isFocused && !readOnly) { keyboardController?.show(); imeBridgeView?.showIme() } }.focusable(enabled).mongolImeSession(inputSession).onPreviewKeyEvent { event ->
            // ... (keep key event logic same)
            if (!enabled || event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
            if (event.isCtrlPressed && event.key == Key.A) { state.applyCommand(MongolEditCommand.SelectAll); return@onPreviewKeyEvent true }
            if (event.isCtrlPressed && event.key == Key.Z) { state.applyCommand(MongolEditCommand.Undo); onTextChange(state.text); return@onPreviewKeyEvent true }
            if (event.isCtrlPressed && event.key == Key.Y) { state.applyCommand(MongolEditCommand.Redo); onTextChange(state.text); return@onPreviewKeyEvent true }
            if (event.isCtrlPressed && (event.key == Key.C || event.key == Key.Insert)) { val s = state.selectedText(); if (s.isNotEmpty()) clipboardManager.setText(AnnotatedString(s)); return@onPreviewKeyEvent true }
            if (event.isCtrlPressed && event.key == Key.X) { if (readOnly) return@onPreviewKeyEvent false; val s = state.selectedText(); if (s.isNotEmpty()) { clipboardManager.setText(AnnotatedString(s)); inputSession.commitText("") }; return@onPreviewKeyEvent true }
            if (event.isCtrlPressed && (event.key == Key.V || (event.key == Key.Insert && event.isShiftPressed))) { if (readOnly) return@onPreviewKeyEvent false; val p = clipboardManager.getText()?.text.orEmpty(); if (p.isNotEmpty()) inputSession.commitText(p); return@onPreviewKeyEvent true }
            val extend = event.isShiftPressed
            when (event.key) {
                Key.DirectionLeft -> { state.applyCommand(MongolEditCommand.MoveCaretLeft, extend); true }
                Key.DirectionRight -> { state.applyCommand(MongolEditCommand.MoveCaretRight, extend); true }
                Key.Backspace -> { if (readOnly) false else { if (state.hasSelection()) inputSession.commitText("") else inputSession.deleteSurroundingText(1, 0); true } }
                Key.Enter -> { if (readOnly || isSingleLine) false else { inputSession.commitText("\n"); true } }
                else -> { if (readOnly) false else { val cp = event.utf16CodePoint; if (cp > 0 && !Character.isISOControl(cp)) { inputSession.commitText(String(Character.toChars(cp))); true } else false } }
            }
        }.onGloballyPositioned { canvasWidthPx = it.size.width; canvasHeightPx = it.size.height }.pointerInput(canvasHeightPx, textAlign, enabled, readOnly, painter) {
            if (!enabled) return@pointerInput
            coroutineScope {
                launch { detectTapGestures(onTap = { focusRequester.requestFocus(); state.placeCaret(resolveCaretPositionForOffset(it)); showCaretHandle = !readOnly; showContextMenu = false }, onDoubleTap = { focusRequester.requestFocus(); state.setSelection(painter.getWordBoundary(resolveCaretPositionForOffset(it))); showContextMenu = true }, onLongPress = { focusRequester.requestFocus(); state.setSelection(painter.getWordBoundary(resolveCaretPositionForOffset(it))); showContextMenu = true }) }
                launch { detectDragGestures(onDragStart = { selectionGestureInProgress = true; showContextMenu = false; focusRequester.requestFocus(); val pos = resolveCaretPositionForOffset(it); val h = resolveSelectionDragHandle(it); activeHandleType = h ?: (if (state.selection.isCollapsed) MongolSelectionHandleType.CARET else MongolSelectionHandleType.END); dragSelectionAnchor = if (activeHandleType == MongolSelectionHandleType.START) state.selection.normalized().end else if (activeHandleType == MongolSelectionHandleType.END) state.selection.normalized().start else pos.offset; if (activeHandleType == MongolSelectionHandleType.CARET) state.placeCaret(pos) else state.setSelection(dragSelectionAnchor, pos.offset) }, onDragEnd = { selectionGestureInProgress = false; activeHandleType = null }, onDrag = { change, _ -> change.consume(); val pos = resolveCaretPositionForOffset(change.position); if (activeHandleType == MongolSelectionHandleType.CARET) state.placeCaret(pos) else state.setSelection(dragSelectionAnchor, pos.offset) }) }
            }
        },
        minLines = minLines, maxLines = maxLines, lineSpan = lineSpanPx
    ) {
        Column(Modifier.fillMaxSize()) {
            Box(Modifier.weight(1f, true).then(scrollModifier).onGloballyPositioned { fieldSize = it.size }) {
                // The content box should match the painter content.
                val contentModifier = Modifier.layout { m, _ ->
                    val w = max(ceil(painter.width).toInt(), minLines * lineSpanPx).coerceAtLeast(1)
                    val h = ceil(painter.height).toInt().coerceAtLeast(1)
                    val p = m.measure(Constraints.fixed(w, h))
                    layout(w, h) { p.place(0, 0) }
                }
                Box(contentModifier) {
                    AndroidView(factory = { ctx -> MongolImeBridgeView(ctx).also { v -> v.session = inputSession; v.inputType = keyboardOptions.toInputType(lineLimits == TextFieldLineLimits.SingleLine); v.imeOptions = keyboardOptions.toImeOptions(lineLimits == TextFieldLineLimits.SingleLine); v.onFocusChangeListener = android.view.View.OnFocusChangeListener { _, f -> imeBridgeHasFocus = f; if (f) hasFocus = true }; imeBridgeView = v } }, update = { v -> v.session = inputSession; v.inputType = keyboardOptions.toInputType(lineLimits == TextFieldLineLimits.SingleLine); v.imeOptions = keyboardOptions.toImeOptions(lineLimits == TextFieldLineLimits.SingleLine) }, modifier = Modifier.size(1.dp))
                    Canvas(Modifier.fillMaxSize().clip(RectangleShape).bringIntoViewRequester(bringIntoViewRequester)) {
                        // ... (keep canvas drawing logic same)
                        clipRect {
                            val selection = state.selection.normalized()
                            if (!selection.isCollapsed) {
                                val boxes = painter.getBoxesForRange(selection.start, selection.end)
                                if (boxes.isNotEmpty()) {
                                    val selMinTop = boxes.minOf { it.top }; val selMaxBottom = boxes.maxOf { it.bottom }
                                    val colGroups = boxes.groupBy { it.left }.toList().sortedBy { it.first }; val n = colGroups.size
                                    if (n == 1) { val b = colGroups[0].second; drawRect(selectionColor, Offset(b.first().left, b.minOf { it.top }), Size(b.first().right - b.first().left, b.maxOf { it.bottom } - b.minOf { it.top })) }
                                    else {
                                        val fc = colGroups[0]; val lc = colGroups[n - 1]
                                        drawRect(selectionColor, Offset(fc.first, fc.second.minOf { it.top }), Size(colGroups[1].first - fc.first, selMaxBottom - fc.second.minOf { it.top }))
                                        if (n > 2) { val ml = colGroups[1].first; val mr = lc.first; drawRect(selectionColor, Offset(ml, selMinTop), Size(mr - ml, selMaxBottom - selMinTop)) }
                                        drawRect(selectionColor, Offset(lc.first, selMinTop), Size(lc.second.first().right - lc.first, lc.second.maxOf { it.bottom } - selMinTop))
                                    }
                                }
                            }
                            painter.textRuns.forEach { run ->
                                val lyt = runLayouts[run] ?: return@forEach
                                val bxs = painter.getBoxesForRange(run.start, run.end); if (bxs.isEmpty()) return@forEach
                                val l = bxs.minOf { it.left }; val t = bxs.minOf { it.top }; val r = bxs.maxOf { it.right }; val b = bxs.maxOf { it.bottom }
                                clipRect(l, t, r, b) {
                                    if (!run.isRotated) withTransform({ translate(l + lyt.size.height, t); rotate(90f, Offset.Zero) }) { drawText(lyt) }
                                    else MongolTextTools.forEachGraphemeCluster(state.text, run.start, run.end) { s, e ->
                                        val box = painter.getBoxesForRange(s, e).firstOrNull() ?: return@forEachGraphemeCluster
                                        val gl = textMeasurer.measure(state.text.substring(s, e), style)
                                        with(VerticalGlyphPlacementPolicy) { drawGlyphInVerticalBox(Character.codePointAt(state.text, s), previousVisibleCodePoint(state.text, s), box, gl) }
                                    }
                                }
                            }
                            val co = painter.getOffsetForCaret(state.caret); val st = with(density) { 2.dp.toPx() }
                            if (enabled && !readOnly && (hasFocus || imeBridgeHasFocus)) drawLine(caretColor.copy(alpha = caretAlpha), Offset(co.x - 1.dp.toPx(), co.y.coerceIn(st/2f, size.height - st/2f)), Offset(co.x + lineSpanPx, co.y.coerceIn(st/2f, size.height - st/2f)), st)
                        }
                    }
                    if (enabled && (hasFocus || imeBridgeHasFocus) && selectionHandlesState.isVisible) {
                        MongolSelectionHandles(state = selectionHandlesState, color = selectionColor.copy(alpha = 1f), onHandleDragStart = { h -> selectionGestureInProgress = true; showContextMenu = false; activeHandleType = h; if (h == MongolSelectionHandleType.CARET) showCaretHandle = !readOnly; handleDragAnchor = if (h == MongolSelectionHandleType.START) state.selection.normalized().end else if (h == MongolSelectionHandleType.END) state.selection.normalized().start else -1 }, onHandleDragEnd = { selectionGestureInProgress = false; activeHandleType = null }, onHandleDrag = { h, offset -> val pos = resolveCaretPositionForOffset(offset); if (h == MongolSelectionHandleType.CARET) state.placeCaret(pos) else if (h == MongolSelectionHandleType.START) state.setSelection(pos.offset, handleDragAnchor) else state.setSelection(handleDragAnchor, pos.offset) }, onTap = { state.placeCaret(resolveCaretPositionForOffset(it)); showCaretHandle = !readOnly; showContextMenu = false })
                    }
                    if (enabled && showContextMenu) {
                        val anchor = resolveContextMenuAnchor(); val popupOffset = resolveContextMenuWindowOffset(anchor)
                        Popup(offset = popupOffset, onDismissRequest = { showContextMenu = false }, properties = PopupProperties(focusable = false, dismissOnClickOutside = true)) {
                            Surface(shape = MaterialTheme.shapes.small, tonalElevation = 6.dp, shadowElevation = 8.dp, modifier = Modifier.onSizeChanged { contextMenuSize = it }) {
                                Column {
                                    ContextMenuItem("ᠪᠦᠬᠦᠨ ᠢ", state.text.isNotEmpty()) { state.selectAll(); showContextMenu = false }
                                    ContextMenuItem("ᠬᠠᠭᠤᠯ", state.hasSelection()) { clipboardManager.setText(AnnotatedString(state.selectedText())); showContextMenu = false }
                                    ContextMenuItem("ᠨᠠᠭ\u180Eᠠ", !readOnly && clipboardManager.hasText()) { inputSession.commitText(clipboardManager.getText()?.text.orEmpty()); showContextMenu = false }
                                    ContextMenuItem("ᠬᠠᠢᠴᠢᠯᠠ", !readOnly && state.hasSelection()) { clipboardManager.setText(AnnotatedString(state.selectedText())); inputSession.commitText(""); showContextMenu = false }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContextMenuItem(label: String, enabled: Boolean, onClick: () -> Unit) {
    val font = FontFamily(Font(R.font.moskwa))
    val color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(0.38f)
    MongolText(label, Modifier.clickable(enabled, onClick = onClick).padding(10.dp, 6.dp), style = TextStyle(color, fontFamily = font))
}

@Composable
fun MongolBasicTextField(text: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, style: TextStyle = TextStyle.Default, textAlign: MongolTextAlign = MongolTextAlign.TOP, textRuns: List<TextRun>? = null, rotateCjk: Boolean = true, enabled: Boolean = true, readOnly: Boolean = false, caretColor: Color = Color(0xFF1B5E20), selectionColor: Color = Color(0x552196F3), keyboardOptions: KeyboardOptions = KeyboardOptions.Default, lineLimits: TextFieldLineLimits = TextFieldLineLimits.Default, normalizeTextChange: (String, String) -> String = { _, proposed -> proposed }, onInputSessionReady: (MongolInputSession) -> Unit = {}, onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {}, onFocusChanged: (Boolean) -> Unit = {}) {
    val state = rememberMongolEditableState(initialText = text)
    LaunchedEffect(text) { if (state.text != text) state.replaceText(text) }
    MongolBasicTextField(state, modifier, style, textAlign, textRuns, rotateCjk, enabled, readOnly, caretColor, selectionColor, keyboardOptions, lineLimits, normalizeTextChange, onValueChange, onInputSessionReady, onSelectionHandlesChanged, onFocusChanged)
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
