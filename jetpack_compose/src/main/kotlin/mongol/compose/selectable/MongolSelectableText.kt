package mongol.compose.selectable

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
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
