package mongol.compose.editing

import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.key.utf16CodePoint
import androidx.compose.ui.platform.ClipboardManager
import androidx.compose.ui.text.AnnotatedString
import mongol.compose.core.MongolTextPainter

/**
 * Handles hardware key events for Mongol text fields.
 */
internal fun handleMongolKeyEvent(
    event: KeyEvent,
    state: MongolEditableState,
    painter: MongolTextPainter,
    inputSession: MongolInputSession,
    clipboardManager: ClipboardManager,
    readOnly: Boolean,
    onTextChange: (String) -> Unit,
    onCaretMovement: () -> Unit,
): Boolean {
    if (event.type != KeyEventType.KeyDown) return false

    if (event.isCtrlPressed) {
        when (event.key) {
            Key.A -> {
                state.applyCommand(MongolEditCommand.SelectAll)
                onCaretMovement()
                return true
            }
            Key.Z -> {
                state.applyCommand(MongolEditCommand.Undo)
                onTextChange(state.text)
                return true
            }
            Key.Y -> {
                state.applyCommand(MongolEditCommand.Redo)
                onTextChange(state.text)
                return true
            }
            Key.C, Key.Insert -> {
                val selected = state.selectedText()
                if (selected.isNotEmpty()) {
                    clipboardManager.setText(AnnotatedString(selected))
                    return true
                }
            }
            Key.X -> {
                if (readOnly) return false
                val selected = state.selectedText()
                if (selected.isNotEmpty()) {
                    clipboardManager.setText(AnnotatedString(selected))
                    inputSession.commitText("")
                    return true
                }
            }
            Key.V -> {
                if (readOnly) return false
                val pasted = clipboardManager.getText()?.text.orEmpty()
                if (pasted.isNotEmpty()) {
                    inputSession.commitText(pasted)
                    return true
                }
            }
        }
    }

    if (event.isShiftPressed) {
        when (event.key) {
            Key.Insert -> {
                if (readOnly) return false
                val pasted = clipboardManager.getText()?.text.orEmpty()
                if (pasted.isNotEmpty()) {
                    inputSession.commitText(pasted)
                    return true
                }
            }
            Key.Delete -> {
                if (readOnly) return false
                val selected = state.selectedText()
                if (selected.isNotEmpty()) {
                    clipboardManager.setText(AnnotatedString(selected))
                    inputSession.commitText("")
                    return true
                }
            }
        }
    }

    val extendSelection = event.isShiftPressed

    return when (event.key) {
        Key.DirectionLeft -> {
            state.applyCommand(MongolEditCommand.MoveCaretLeft, extendSelection)
            onCaretMovement()
            true
        }
        Key.DirectionRight -> {
            state.applyCommand(MongolEditCommand.MoveCaretRight, extendSelection)
            onCaretMovement()
            true
        }
        Key.MoveHome -> {
            if (event.isCtrlPressed) {
                state.applyCommand(MongolEditCommand.MoveCaretToStart, extendSelection)
            } else {
                val anchor = state.caret.offset
                val lineRange = painter.getLineBoundary(state.caret)
                if (extendSelection) {
                    inputSession.setSelection(anchor, lineRange.start)
                } else {
                    inputSession.setSelection(lineRange.start, lineRange.start)
                }
            }
            onCaretMovement()
            true
        }
        Key.MoveEnd -> {
            if (event.isCtrlPressed) {
                state.applyCommand(MongolEditCommand.MoveCaretToEnd, extendSelection)
            } else {
                val anchor = state.caret.offset
                val lineRange = painter.getLineBoundary(state.caret)
                if (extendSelection) {
                    inputSession.setSelection(anchor, lineRange.end)
                } else {
                    inputSession.setSelection(lineRange.end, lineRange.end)
                }
            }
            onCaretMovement()
            true
        }
        Key.Escape -> {
            state.placeCaret(state.caret)
            true
        }
        Key.Backspace -> {
            if (readOnly) return false
            if (state.hasSelection()) {
                inputSession.commitText("")
            } else {
                inputSession.deleteSurroundingText(beforeLength = 1, afterLength = 0)
            }
            onCaretMovement()
            true
        }
        Key.Delete -> {
            if (readOnly) return false
            if (state.hasSelection()) {
                inputSession.commitText("")
            } else {
                inputSession.deleteSurroundingText(beforeLength = 0, afterLength = 1)
            }
            onCaretMovement()
            true
        }
        Key.Enter -> {
            if (readOnly) return false
            inputSession.commitText("\n")
            onCaretMovement()
            true
        }
        else -> {
            if (readOnly) return false
            val cp = event.utf16CodePoint
            if (cp > 0 && !Character.isISOControl(cp)) {
                inputSession.commitText(String(Character.toChars(cp)))
                onCaretMovement()
                true
            } else {
                false
            }
        }
    }
}
