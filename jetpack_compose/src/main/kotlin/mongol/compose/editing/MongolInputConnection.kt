package mongol.compose.editing

import android.view.KeyEvent
import android.view.inputmethod.CompletionInfo
import android.view.inputmethod.InputConnection
import android.os.Bundle
import android.view.inputmethod.*

/**
 * 更好的方案：直接实现 InputConnection 接口。
 * 这样可以完全控制输入逻辑，避免 BaseInputConnection 内部 Editable 导致的同步问题。
 */
class MongolInputConnection(
    private val view: android.view.View,
    private val session: MongolInputSession,
) : InputConnection {

    override fun getTextBeforeCursor(n: Int, flags: Int): CharSequence {
        val snap = session.snapshot()
        val count = n.coerceAtLeast(0)
        val end = snap.selectionStart
        val start = (end - count).coerceAtLeast(0)
        return snap.text.substring(start, end)
    }

    override fun getTextAfterCursor(n: Int, flags: Int): CharSequence {
        val snap = session.snapshot()
        val count = n.coerceAtLeast(0)
        val start = snap.selectionEnd
        val end = (start + count).coerceAtMost(snap.text.length)
        return snap.text.substring(start, end)
    }

    override fun getSelectedText(flags: Int): CharSequence? {
        val snap = session.snapshot()
        if (snap.selectionStart == snap.selectionEnd) return null
        return snap.text.substring(snap.selectionStart, snap.selectionEnd)
    }

    override fun getCursorCapsMode(reqModes: Int): Int = 0

    override fun getExtractedText(request: ExtractedTextRequest?, flags: Int): ExtractedText {
        val snap = session.snapshot()
        return ExtractedText().apply {
            text = snap.text
            startOffset = 0
            selectionStart = snap.selectionStart
            selectionEnd = snap.selectionEnd
        }
    }

    override fun deleteSurroundingText(beforeLength: Int, afterLength: Int): Boolean {
        session.deleteSurroundingText(beforeLength, afterLength)
        return true
    }

    override fun deleteSurroundingTextInCodePoints(beforeLength: Int, afterLength: Int): Boolean {
        // 简单处理：蒙古文主要在 BMP 内，但在支持 Emoji 时此方法很重要
        return deleteSurroundingText(beforeLength, afterLength)
    }

    override fun setSelection(start: Int, end: Int): Boolean {
        session.setSelection(start, end)
        return true
    }

    override fun setComposingText(text: CharSequence?, newCursorPosition: Int): Boolean {
        session.setComposingText(text?.toString() ?: "", newCursorPosition)
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

    override fun commitText(text: CharSequence?, newCursorPosition: Int): Boolean {
        session.commitText(text?.toString() ?: "", newCursorPosition)
        return true
    }

    override fun commitCompletion(text: CompletionInfo?): Boolean = false

    override fun commitCorrection(correctionInfo: CorrectionInfo?): Boolean = false


    override fun beginBatchEdit(): Boolean {
        session.beginBatchEdit()
        return true
    }

    override fun endBatchEdit(): Boolean {
        session.endBatchEdit()
        return true
    }

    override fun sendKeyEvent(event: KeyEvent): Boolean {
        // 处理退格键等硬件按键
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_DEL -> return deleteSurroundingText(1, 0)
                KeyEvent.KEYCODE_FORWARD_DEL -> return deleteSurroundingText(0, 1)
                KeyEvent.KEYCODE_ENTER -> return commitText("\n", 1)
            }
        }
        return false
    }

    override fun clearMetaKeyStates(states: Int): Boolean = false
    override fun reportFullscreenMode(enabled: Boolean): Boolean = false
    override fun performPrivateCommand(action: String?, data: Bundle?): Boolean = false
    override fun performEditorAction(editorAction: Int): Boolean = true
    override fun performContextMenuAction(id: Int): Boolean = false
    override fun requestCursorUpdates(cursorUpdateMode: Int): Boolean = false
    override fun commitContent(
        inputContentInfo: InputContentInfo,
        flags: Int,
        opts: Bundle?
    ): Boolean = false

    override fun closeConnection() {}
    override fun getHandler(): android.os.Handler? = null
}
