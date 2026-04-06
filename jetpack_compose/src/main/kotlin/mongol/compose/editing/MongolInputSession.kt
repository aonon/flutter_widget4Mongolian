package mongol.compose.editing

/**
 * Minimal text-input session bridge for future platform IME integration.
 */
data class MongolInputSnapshot(
    val text: String,
    val selectionStart: Int,
    val selectionEnd: Int,
    val composingStart: Int?,
    val composingEnd: Int?,
)

interface MongolInputSession {
    fun snapshot(): MongolInputSnapshot
    fun beginBatchEdit()
    fun endBatchEdit()
    fun commitText(text: String, newCursorPosition: Int = 1)
    fun setComposingText(text: String, newCursorPosition: Int = 1)
    fun setComposingRegion(start: Int, end: Int)
    fun finishComposingText()
    fun deleteSurroundingText(beforeLength: Int, afterLength: Int)
    fun setSelection(start: Int, end: Int)
}

class DefaultMongolInputSession(
    private val state: MongolEditableState,
    private val onTextChange: (String) -> Unit,
) : MongolInputSession {
    private var batchDepth: Int = 0
    private var hasPendingTextChange: Boolean = false

    private fun notifyTextChanged() {
        if (batchDepth > 0) {
            hasPendingTextChange = true
            return
        }
        onTextChange(state.text)
    }

    private fun resolveCursorPosition(
        replacementStart: Int,
        insertedLength: Int,
        newCursorPosition: Int,
    ): Int {
        val cursor = if (newCursorPosition > 0) {
            replacementStart + insertedLength + newCursorPosition - 1
        } else {
            replacementStart + newCursorPosition
        }
        return cursor.coerceIn(0, state.text.length)
    }

    override fun snapshot(): MongolInputSnapshot {
        val selection = state.selection.normalized()
        val composing = state.composingRange?.normalized()
        return MongolInputSnapshot(
            text = state.text,
            selectionStart = selection.start,
            selectionEnd = selection.end,
            composingStart = composing?.start,
            composingEnd = composing?.end,
        )
    }

    override fun beginBatchEdit() {
        batchDepth += 1
    }

    override fun endBatchEdit() {
        if (batchDepth > 0) {
            batchDepth -= 1
        }
        if (batchDepth == 0 && hasPendingTextChange) {
            hasPendingTextChange = false
            onTextChange(state.text)
        }
    }

    override fun commitText(text: String, newCursorPosition: Int) {
        val composing = state.composingRange?.normalized()
        val selection = state.selection.normalized()
        val active = composing ?: selection
        val replacementStart = if (active.isCollapsed) state.caret.offset else active.start
        if (active.isCollapsed) {
            state.insertText(text)
        } else {
            state.replaceRange(active.start, active.end, text)
        }
        state.clearComposingRange()
        state.placeCaret(
            mongol.compose.core.TextPosition(
                resolveCursorPosition(replacementStart, text.length, newCursorPosition),
            ),
        )
        notifyTextChanged()
    }

    override fun setComposingText(text: String, newCursorPosition: Int) {
        val composing = state.composingRange?.normalized()
        val selection = state.selection.normalized()
        val active = composing ?: selection
        val start = if (active.isCollapsed) state.caret.offset else active.start
        val end = if (active.isCollapsed) state.caret.offset else active.end
        state.replaceRange(start, end, text)
        state.setComposingRange(start, start + text.length)
        val cursor = resolveCursorPosition(start, text.length, newCursorPosition)
        state.setSelection(cursor, cursor, clearComposing = false)
        onTextChange(state.text)
    }

    override fun setComposingRegion(start: Int, end: Int) {
        state.setComposingRange(start, end)
    }

    override fun finishComposingText() {
        state.clearComposingRange()
        notifyTextChanged()
    }

    override fun deleteSurroundingText(beforeLength: Int, afterLength: Int) {
        val composing = state.composingRange?.normalized()
        if (composing != null && !composing.isCollapsed) {
            state.replaceRange(composing.start, composing.end, "")
            state.clearComposingRange()
            notifyTextChanged()
            return
        }

        val selection = state.selection.normalized()
        if (!selection.isCollapsed) {
            state.replaceRange(selection.start, selection.end, "")
            notifyTextChanged()
            return
        }

        val caret = state.caret.offset
        val start = (caret - beforeLength.coerceAtLeast(0)).coerceAtLeast(0)
        val end = (caret + afterLength.coerceAtLeast(0)).coerceAtMost(state.text.length)
        if (start < end) {
            state.replaceRange(start, end, "")
            notifyTextChanged()
        }
    }

    override fun setSelection(start: Int, end: Int) {
        state.setSelection(start, end)
    }
}
