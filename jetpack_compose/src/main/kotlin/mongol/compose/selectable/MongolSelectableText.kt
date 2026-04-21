package mongol.compose.selectable

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.TextRun
import mongol.compose.editing.MongolBasicTextField
import mongol.compose.editing.rememberMongolEditableState

/**
 * Vertical Mongolian text that supports user selection and copy.
 *
 * Rendering behavior matches MongolText (via MongolBasicTextField painter path),
 * while editing is disabled to keep the component display-only.
 */
@Composable
fun MongolSelectableText(
    text: String,
    modifier: Modifier = Modifier,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    style: TextStyle = TextStyle.Default,
    selectionColor: Color = Color(0x552196F3),
) {
    val state = rememberMongolEditableState(initialText = text)

    LaunchedEffect(text) {
        if (state.text != text) {
            state.replaceText(text)
        }
    }

    Box(modifier = modifier) {
        MongolBasicTextField(
            state = state,
            style = style,
            textAlign = textAlign,
            textRuns = textRuns,
            rotateCjk = rotateCjk,
            enabled = true,
            readOnly = true,
            caretColor = Color.Transparent,
            selectionColor = selectionColor,
            onTextChange = {},
        )
    }
}
