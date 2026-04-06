package mongol.compose.editing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import mongol.compose.core.MongolTextAlign

/**
 * Editing bootstrap widget.
 *
 * This is not the final MongolEditableText implementation. It demonstrates
 * how selection hit-testing and caret placement are consumed from
 * MongolTextPainter in Compose.
 */
@Composable
fun MongolEditablePreview(
    text: String,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    caretColor: Color = Color(0xFF1B5E20),
    selectionColor: Color = Color(0x552196F3),
) {
    val state = remember(text) { MongolEditableState(text) }
    MongolEditableText(
        state = state,
        modifier = modifier,
        style = style,
        textAlign = textAlign,
        caretColor = caretColor,
        selectionColor = selectionColor,
    )
}
