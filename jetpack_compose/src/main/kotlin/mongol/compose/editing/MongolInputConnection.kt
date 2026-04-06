package mongol.compose.editing

import android.view.KeyEvent
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.CompletionInfo
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection

/**
 * Android [InputConnection] implementation that bridges the system IME to
 * [MongolInputSession].
 *
 * Usage — inside any [android.view.View] that hosts Mongolian text input:
 *
 * ```kotlin
 * override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection {
 *     outAttrs.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
 *     outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_FULLSCREEN
 *     return MongolInputConnection(this, session)
 * }
 * ```
 *
 * The [view] parameter is passed to [BaseInputConnection] so that
 * [BaseInputConnection.finishComposingText] and related housekeeping work
 * correctly from the framework side.
 */
class MongolInputConnection(
    view: android.view.View,
    private val session: MongolInputSession,
) : BaseInputConnection(view, /* fullEditor = */ true) {

    // ------------------------------------------------------------------ //
    // Composing-text management
    // ------------------------------------------------------------------ //

    override fun setComposingText(text: CharSequence?, newCursorPosition: Int): Boolean {
        if (text == null) return false
        session.setComposingText(text.toString(), newCursorPosition)
        return true
    }

    override fun setComposingRegion(start: Int, end: Int): Boolean {
        session.setComposingRegion(start, end)
        return true
    }

    override fun finishComposingText(): Boolean {
        session.finishComposingText()
        return true
    }

    // ------------------------------------------------------------------ //
    // Commit
    // ------------------------------------------------------------------ //

    override fun commitText(text: CharSequence?, newCursorPosition: Int): Boolean {
        if (text == null) return false
        session.commitText(text.toString(), newCursorPosition)
        return true
    }

    override fun commitCompletion(text: CompletionInfo?): Boolean {
        val completionText = text?.text ?: return false
        session.commitText(completionText.toString(), 1)
        return true
    }

    // ------------------------------------------------------------------ //
    // Deletion
    // ------------------------------------------------------------------ //

    override fun deleteSurroundingText(beforeLength: Int, afterLength: Int): Boolean {
        session.deleteSurroundingText(beforeLength, afterLength)
        return true
    }

    // ------------------------------------------------------------------ //
    // Selection / cursor
    // ------------------------------------------------------------------ //

    override fun setSelection(start: Int, end: Int): Boolean {
        session.setSelection(start, end)
        return true
    }

    override fun getSelectedText(flags: Int): CharSequence {
        val snap = session.snapshot()
        val start = snap.selectionStart.coerceIn(0, snap.text.length)
        val end = snap.selectionEnd.coerceIn(0, snap.text.length)
        if (start >= end) return ""
        return snap.text.substring(start, end)
    }

    // ------------------------------------------------------------------ //
    // Extracted text (used by IME candidate window)
    // ------------------------------------------------------------------ //

    override fun getExtractedText(
        request: android.view.inputmethod.ExtractedTextRequest?,
        flags: Int,
    ): android.view.inputmethod.ExtractedText {
        val snap = session.snapshot()
        return android.view.inputmethod.ExtractedText().apply {
            text = snap.text
            selectionStart = snap.selectionStart
            selectionEnd = snap.selectionEnd
            partialStartOffset = -1
            partialEndOffset = -1
            startOffset = 0
        }
    }

    // ------------------------------------------------------------------ //
    // Surrounding text (used by smart-backspace, autocorrect, etc.)
    // ------------------------------------------------------------------ //

    override fun getTextBeforeCursor(n: Int, flags: Int): CharSequence {
        val snap = session.snapshot()
        val count = n.coerceAtLeast(0)
        val end = snap.selectionStart.coerceAtLeast(0)
        val start = (end - count).coerceAtLeast(0)
        return snap.text.substring(start, end)
    }

    override fun getTextAfterCursor(n: Int, flags: Int): CharSequence {
        val snap = session.snapshot()
        val count = n.coerceAtLeast(0)
        val start = snap.selectionEnd.coerceAtMost(snap.text.length)
        val end = (start + count).coerceAtMost(snap.text.length)
        return snap.text.substring(start, end)
    }

    // ------------------------------------------------------------------ //
    // Batch edits
    // ------------------------------------------------------------------ //

    override fun beginBatchEdit(): Boolean {
        session.beginBatchEdit()
        return true
    }

    override fun endBatchEdit(): Boolean {
        session.endBatchEdit()
        return true
    }

    // ------------------------------------------------------------------ //
    // Hardware key events
    // ------------------------------------------------------------------ //

    /**
     * Forward hardware key-down events that carry printable characters.
     * Arrow keys and special keys are handled by the Compose [onPreviewKeyEvent]
     * chain in [MongolEditableText] and are intentionally ignored here to avoid
     * double-processing.
     */
    override fun sendKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false
        if (event.action != KeyEvent.ACTION_DOWN) return true
        if (event.keyCode == KeyEvent.KEYCODE_DEL) {
            session.deleteSurroundingText(1, 0)
            return true
        }
        if (event.keyCode == KeyEvent.KEYCODE_FORWARD_DEL) {
            session.deleteSurroundingText(0, 1)
            return true
        }
        val cp = event.unicodeChar
        if (cp > 0 && !Character.isISOControl(cp)) {
            session.commitText(String(Character.toChars(cp)))
            return true
        }
        return super.sendKeyEvent(event)
    }
}
