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
    private val normalizeTextChange: (String, String) -> String = { _, proposed -> proposed },
) : MongolInputSession {
    private var batchDepth: Int = 0
    private var hasPendingTextChange: Boolean = false

    private fun buildProposedText(start: Int, end: Int, replacement: String): String {
        return buildString {
            append(state.text.substring(0, start))
            append(replacement)
            append(state.text.substring(end))
        }
    }

    private fun replaceWithNormalization(
        start: Int,
        end: Int,
        replacement: String,
        newCursorPosition: Int,
        composing: Boolean,
    ) {
        val normalizedStart = start.coerceIn(0, state.text.length)
        val normalizedEnd = end.coerceIn(0, state.text.length)
        val proposedText = buildProposedText(normalizedStart, normalizedEnd, replacement)
        val transformedText = normalizeTextChange(state.text, proposedText)

        if (transformedText == proposedText) {
            state.replaceRange(normalizedStart, normalizedEnd, replacement, clearComposing = !composing)
            if (composing) {
                state.setComposingRange(normalizedStart, normalizedStart + replacement.length)
            }
        } else {
            state.replaceText(transformedText)
            if (composing) {
                val composingStart = normalizedStart.coerceIn(0, transformedText.length)
                val composingEnd = (composingStart + replacement.length).coerceIn(composingStart, transformedText.length)
                state.setComposingRange(composingStart, composingEnd)
            }
        }

        val cursor = resolveCursorPosition(normalizedStart, replacement.length, newCursorPosition)
            .coerceIn(0, state.text.length)
        state.setSelection(cursor, cursor, clearComposing = !composing)
    }

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

        replaceWithNormalization(
            start = active.start,
            end = active.end,
            replacement = text,
            newCursorPosition = newCursorPosition,
            composing = false,
        )
        notifyTextChanged()
    }

    override fun setComposingText(text: String, newCursorPosition: Int) {
        val composing = state.composingRange
        val selection = state.selection
        val active = composing ?: selection

        replaceWithNormalization(
            start = active.start,
            end = active.end,
            replacement = text,
            newCursorPosition = newCursorPosition,
            composing = true,
        )
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
            replaceWithNormalization(
                start = selection.start,
                end = selection.end,
                replacement = "",
                newCursorPosition = 1,
                composing = false,
            )
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
            replaceWithNormalization(
                start = start,
                end = end,
                replacement = "",
                newCursorPosition = 1,
                composing = false,
            )
            notifyTextChanged()
        }
    }

    override fun setSelection(start: Int, end: Int) {
        state.setSelection(start, end)
    }
}
