package mongol.compose.editing

/**
 * Command model for future IME bridge integration.
 *
 * These commands map naturally to platform input operations and can be applied
 * to MongolEditableState without coupling the state to any specific input API.
 */
sealed interface MongolEditCommand {
    data class InsertText(val text: String) : MongolEditCommand
    data object DeleteBackward : MongolEditCommand
    data object DeleteForward : MongolEditCommand
    data object MoveCaretLeft : MongolEditCommand
    data object MoveCaretRight : MongolEditCommand
    data object MoveCaretToStart : MongolEditCommand
    data object MoveCaretToEnd : MongolEditCommand
    data object SelectAll : MongolEditCommand
    data object Undo : MongolEditCommand
    data object Redo : MongolEditCommand
}
