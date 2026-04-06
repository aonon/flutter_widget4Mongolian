package mongol.compose.editing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.SpanStyle
import mongol.compose.core.TextPosition
import mongol.compose.core.TextRange

@Stable
data class MongolSelection(
    val start: Int,
    val end: Int,
) {
    val isCollapsed: Boolean
        get() = start == end

    fun normalized(): MongolSelection {
        return if (start <= end) this else MongolSelection(end, start)
    }
}

@Stable
class MongolEditableState(initialText: String) {
    private data class Snapshot(
        val text: String,
        val caret: TextPosition,
        val selection: MongolSelection,
        val spans: List<MongolTextSpan>,
    )

    private val undoStack: ArrayDeque<Snapshot> = ArrayDeque()
    private val redoStack: ArrayDeque<Snapshot> = ArrayDeque()
    private val historyLimit = 100

    var text by mutableStateOf(initialText)
        private set

    var caret by mutableStateOf(TextPosition(0))
        private set

    var selection by mutableStateOf(MongolSelection(0, 0))
        private set

    var composingRange by mutableStateOf<MongolSelection?>(null)
        private set

    /** Style spans.  Updated automatically on every text mutation. */
    var spans by mutableStateOf(emptyList<MongolTextSpan>())
        private set

    private var selectionAnchor: Int? = null

    val canUndo: Boolean
        get() = undoStack.isNotEmpty()

    val canRedo: Boolean
        get() = redoStack.isNotEmpty()

    private fun captureSnapshot(): Snapshot {
        return Snapshot(
            text = text,
            caret = caret,
            selection = selection,
            spans = spans,
        )
    }

    private fun pushUndoSnapshot() {
        undoStack.addLast(captureSnapshot())
        while (undoStack.size > historyLimit) {
            undoStack.removeFirst()
        }
        redoStack.clear()
    }

    private fun restoreSnapshot(snapshot: Snapshot) {
        text = snapshot.text
        caret = snapshot.caret
        selection = snapshot.selection
        spans = snapshot.spans
        selectionAnchor = if (snapshot.selection.isCollapsed) null else snapshot.selection.start
    }

    fun replaceText(value: String) {
        if (text != value) {
            pushUndoSnapshot()
        }
        text = value
        spans = spans.mapNotNull { it.clampedTo(text.length) }
        val clamped = caret.offset.coerceIn(0, text.length)
        caret = TextPosition(clamped)
        selection = MongolSelection(clamped, clamped)
        selectionAnchor = null
        composingRange = null
    }

    fun placeCaret(position: TextPosition, clearComposing: Boolean = true) {
        val clamped = position.offset.coerceIn(0, text.length)
        caret = TextPosition(clamped, position.affinity)
        selection = MongolSelection(clamped, clamped)
        selectionAnchor = null
        if (clearComposing) {
            composingRange = null
        }
    }

    fun setSelection(start: Int, end: Int, clearComposing: Boolean = true) {
        val normalizedStart = start.coerceIn(0, text.length)
        val normalizedEnd = end.coerceIn(0, text.length)
        val normalized = MongolSelection(normalizedStart, normalizedEnd).normalized()
        selection = normalized
        caret = TextPosition(normalized.end)
        selectionAnchor = if (normalized.isCollapsed) null else normalized.start
        if (clearComposing) {
            composingRange = null
        }
    }

    fun setSelection(range: TextRange) {
        setSelection(range.start, range.end)
    }

    fun hasSelection(): Boolean {
        return !selection.normalized().isCollapsed
    }

    fun selectedText(): String {
        val normalized = selection.normalized()
        if (normalized.isCollapsed) return ""
        return text.substring(normalized.start, normalized.end)
    }

    fun deleteSelection() {
        if (!hasSelection()) return
        replaceSelection("")
    }

    fun setComposingRange(start: Int, end: Int) {
        val normalizedStart = start.coerceIn(0, text.length)
        val normalizedEnd = end.coerceIn(0, text.length)
        val normalized = MongolSelection(normalizedStart, normalizedEnd).normalized()
        composingRange = if (normalized.isCollapsed) null else normalized
    }

    fun clearComposingRange() {
        composingRange = null
    }

    fun replaceRange(start: Int, end: Int, replacement: String) {
        val rangeStart = start.coerceIn(0, text.length)
        val rangeEnd = end.coerceIn(0, text.length)
        val normalized = MongolSelection(rangeStart, rangeEnd).normalized()
        pushUndoSnapshot()
        spans = spans.adjustForDelete(normalized.start, normalized.end)
        if (replacement.isNotEmpty()) {
            spans = spans.adjustForInsert(normalized.start, replacement.length)
        }
        text = buildString {
            append(text.substring(0, normalized.start))
            append(replacement)
            append(text.substring(normalized.end))
        }
        val next = normalized.start + replacement.length
        caret = TextPosition(next)
        selection = MongolSelection(next, next)
        selectionAnchor = null
        composingRange = null
    }

    // ------------------------------------------------------------------ //
    // Span management
    // ------------------------------------------------------------------ //

    /**
     * Add a style span covering [start, end). Overlapping spans are allowed
     * and will be merged at render time via [buildStyleMap].
     */
    fun addSpan(start: Int, end: Int, style: SpanStyle) {
        val s = start.coerceIn(0, text.length)
        val e = end.coerceIn(0, text.length)
        if (e <= s) return
        spans = spans + MongolTextSpan(s, e, style)
    }

    /**
     * Remove all spans whose range overlaps [start, end).
     */
    fun removeSpansInRange(start: Int, end: Int) {
        val s = start.coerceIn(0, text.length)
        val e = end.coerceIn(0, text.length)
        if (e <= s) return
        spans = spans.filter { span -> span.end <= s || span.start >= e }
    }

    /** Remove all style spans from the field. */
    fun clearSpans() {
        spans = emptyList()
    }

    fun applyCommand(command: MongolEditCommand, extendSelection: Boolean = false) {
        when (command) {
            is MongolEditCommand.InsertText -> insertText(command.text)
            MongolEditCommand.DeleteBackward -> deleteBackward()
            MongolEditCommand.DeleteForward -> deleteForward()
            MongolEditCommand.MoveCaretLeft ->
                moveCaretLeft(extendSelection = extendSelection)

            MongolEditCommand.MoveCaretRight ->
                moveCaretRight(extendSelection = extendSelection)

            MongolEditCommand.MoveCaretToStart ->
                moveCaretToStart(extendSelection = extendSelection)

            MongolEditCommand.MoveCaretToEnd ->
                moveCaretToEnd(extendSelection = extendSelection)

            MongolEditCommand.SelectAll -> selectAll()
            MongolEditCommand.Undo -> undo()
            MongolEditCommand.Redo -> redo()
        }
    }

    fun undo() {
        if (undoStack.isEmpty()) return
        redoStack.addLast(captureSnapshot())
        val snapshot = undoStack.removeLast()
        restoreSnapshot(snapshot)
        composingRange = null
    }

    fun redo() {
        if (redoStack.isEmpty()) return
        undoStack.addLast(captureSnapshot())
        val snapshot = redoStack.removeLast()
        restoreSnapshot(snapshot)
        composingRange = null
    }

    fun moveCaretLeft(extendSelection: Boolean = false) {
        if (!extendSelection) {
            val selectionNorm = selection.normalized()
            if (!selectionNorm.isCollapsed) {
                placeCaret(TextPosition(selectionNorm.start))
                return
            }
        }
        val next = (caret.offset - 1).coerceAtLeast(0)
        updateCaretWithOptionalSelection(next, extendSelection)
    }

    fun moveCaretRight(extendSelection: Boolean = false) {
        if (!extendSelection) {
            val selectionNorm = selection.normalized()
            if (!selectionNorm.isCollapsed) {
                placeCaret(TextPosition(selectionNorm.end))
                return
            }
        }
        val next = (caret.offset + 1).coerceAtMost(text.length)
        updateCaretWithOptionalSelection(next, extendSelection)
    }

    fun moveCaretToStart(extendSelection: Boolean = false) {
        updateCaretWithOptionalSelection(0, extendSelection)
    }

    fun moveCaretToEnd(extendSelection: Boolean = false) {
        updateCaretWithOptionalSelection(text.length, extendSelection)
    }

    fun selectAll() {
        setSelection(0, text.length)
    }

    fun insertText(insert: String) {
        if (insert.isEmpty()) return
        pushUndoSnapshot()
        val selectionNorm = selection.normalized()
        // Delete selected range first, then insert.
        if (!selectionNorm.isCollapsed) {
            spans = spans.adjustForDelete(selectionNorm.start, selectionNorm.end)
        }
        val insertPos = selectionNorm.start
        val newText = buildString {
            append(text.substring(0, selectionNorm.start))
            append(insert)
            append(text.substring(selectionNorm.end))
        }
        text = newText
        spans = spans.adjustForInsert(insertPos, insert.length)
        val next = insertPos + insert.length
        caret = TextPosition(next)
        selection = MongolSelection(next, next)
        selectionAnchor = null
        composingRange = null
    }

    fun deleteBackward() {
        val selectionNorm = selection.normalized()
        if (!selectionNorm.isCollapsed) {
            pushUndoSnapshot()
            replaceSelection("")
            return
        }
        if (caret.offset <= 0) return
        pushUndoSnapshot()
        val start = caret.offset - 1
        spans = spans.adjustForDelete(start, caret.offset)
        text = text.removeRange(start, caret.offset)
        caret = TextPosition(start)
        selection = MongolSelection(start, start)
    }

    fun deleteForward() {
        val selectionNorm = selection.normalized()
        if (!selectionNorm.isCollapsed) {
            pushUndoSnapshot()
            replaceSelection("")
            return
        }
        if (caret.offset >= text.length) return
        pushUndoSnapshot()
        spans = spans.adjustForDelete(caret.offset, caret.offset + 1)
        text = text.removeRange(caret.offset, caret.offset + 1)
        selection = MongolSelection(caret.offset, caret.offset)
        selectionAnchor = null
        composingRange = null
    }

    private fun replaceSelection(replacement: String) {
        val selectionNorm = selection.normalized()
        spans = spans.adjustForDelete(selectionNorm.start, selectionNorm.end)
        if (replacement.isNotEmpty()) {
            spans = spans.adjustForInsert(selectionNorm.start, replacement.length)
        }
        text = buildString {
            append(text.substring(0, selectionNorm.start))
            append(replacement)
            append(text.substring(selectionNorm.end))
        }
        val next = selectionNorm.start + replacement.length
        caret = TextPosition(next)
        selection = MongolSelection(next, next)
        selectionAnchor = null
        composingRange = null
    }

    private fun updateCaretWithOptionalSelection(targetOffset: Int, extendSelection: Boolean) {
        val clamped = targetOffset.coerceIn(0, text.length)
        if (!extendSelection) {
            placeCaret(TextPosition(clamped))
            return
        }

        val anchor = selectionAnchor ?: selection.start.coerceIn(0, text.length).also {
            selectionAnchor = it
        }
        val start = minOf(anchor, clamped)
        val end = maxOf(anchor, clamped)
        selection = MongolSelection(start, end)
        caret = TextPosition(clamped)
    }
}

@Composable
fun rememberMongolEditableState(initialText: String): MongolEditableState {
    return remember {
        MongolEditableState(initialText)
    }
}
