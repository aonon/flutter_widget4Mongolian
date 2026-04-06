package mongol.compose.editing

import mongol.compose.core.MongolTextPainter
import mongol.compose.core.Offset as CoreOffset
import mongol.compose.core.TextPosition

enum class MongolSelectionHandleType {
    CARET,
    START,
    END,
}

data class MongolSelectionHandle(
    val type: MongolSelectionHandleType,
    val offset: CoreOffset,
)

data class MongolSelectionHandlesState(
    val handles: List<MongolSelectionHandle>,
    val activeHandle: MongolSelectionHandleType? = null,
) {
    val isVisible: Boolean
        get() = handles.isNotEmpty()
}

object MongolSelectionHandlesCalculator {
    fun calculate(
        painter: MongolTextPainter,
        selection: MongolSelection,
        activeHandle: MongolSelectionHandleType? = null,
    ): MongolSelectionHandlesState {
        val normalized = selection.normalized()
        if (normalized.isCollapsed) {
            val caret = painter.getOffsetForCaret(TextPosition(normalized.start))
            return MongolSelectionHandlesState(
                handles = listOf(
                    MongolSelectionHandle(
                        type = MongolSelectionHandleType.CARET,
                        offset = caret,
                    ),
                ),
                activeHandle = activeHandle,
            )
        }

        val start = painter.getOffsetForCaret(TextPosition(normalized.start))
        val end = painter.getOffsetForCaret(TextPosition(normalized.end))
        return MongolSelectionHandlesState(
            handles = listOf(
                MongolSelectionHandle(
                    type = MongolSelectionHandleType.START,
                    offset = start,
                ),
                MongolSelectionHandle(
                    type = MongolSelectionHandleType.END,
                    offset = end,
                ),
            ),
            activeHandle = activeHandle,
        )
    }
}
