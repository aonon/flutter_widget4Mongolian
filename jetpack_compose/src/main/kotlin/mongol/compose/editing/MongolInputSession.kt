package mongol.compose.editing

import mongol.compose.core.MongolTextTools

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
        return if (newCursorPosition > 0) {
            (replacementStart + insertedLength + newCursorPosition - 1).coerceIn(0, state.text.length)
        } else {
            (replacementStart + newCursorPosition).coerceIn(0, state.text.length)
        }
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
        val composing = state.composingRange
        val selection = state.selection
        val active = composing ?: selection
        
        val replacementStart = active.start
        state.replaceRange(active.start, active.end, text, clearComposing = true)
        
        val cursor = resolveCursorPosition(replacementStart, text.length, newCursorPosition)
        state.setSelection(cursor, cursor, clearComposing = true)
        notifyTextChanged()
    }

    override fun setComposingText(text: String, newCursorPosition: Int) {
        val composing = state.composingRange
        val selection = state.selection
        val active = composing ?: selection
        
        val replacementStart = active.start
        state.replaceRange(active.start, active.end, text, clearComposing = false)
        state.setComposingRange(replacementStart, replacementStart + text.length)
        
        val cursor = resolveCursorPosition(replacementStart, text.length, newCursorPosition)
        state.setSelection(cursor, cursor, clearComposing = false)
        notifyTextChanged()
    }

    override fun setComposingRegion(start: Int, end: Int) {
        state.setComposingRange(start, end)
    }

    override fun finishComposingText() {
        state.clearComposingRange()
        notifyTextChanged()
    }

    override fun deleteSurroundingText(beforeLength: Int, afterLength: Int) {
        if (beforeLength < 0 || afterLength < 0) return

        val selection = state.selection.normalized()
        if (!selection.isCollapsed) {
            state.replaceRange(selection.start, selection.end, "", clearComposing = false)
            notifyTextChanged()
            return
        }

        val cursor = selection.end
        var start = cursor
        repeat(beforeLength) {
            start = MongolTextTools.getOffsetBefore(start, state.text) ?: 0
        }

        var end = cursor
        repeat(afterLength) {
            end = MongolTextTools.getOffsetAfter(end, state.text) ?: state.text.length
        }

        if (start < end) {
            state.replaceRange(start, end, "", clearComposing = false)
            notifyTextChanged()
        }
    }

    override fun setSelection(start: Int, end: Int) {
        state.setSelection(start, end)
    }
}
