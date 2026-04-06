package mongol.compose.editing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.TextRun

/**
 * High-level editable entry point, aligned with Flutter layering where
 * TextField wraps EditableText.
 */
@Composable
fun MongolTextField(
    state: MongolEditableState,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color(0xFF1B5E20),
    selectionColor: Color = Color(0x552196F3),
    onTextChange: (String) -> Unit = {},
    // Compatibility with value/onValueChange-style call sites.
    value: String? = null,
    onValueChange: ((String) -> Unit)? = null,
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
) {
    val effectiveOnTextChange: (String) -> Unit = onValueChange ?: onTextChange

    MongolEditableText(
        state = state,
        modifier = modifier,
        style = style,
        textAlign = textAlign,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        enabled = enabled,
        readOnly = readOnly,
        caretColor = caretColor,
        selectionColor = selectionColor,
        onTextChange = effectiveOnTextChange,
        onInputSessionReady = onInputSessionReady,
        onSelectionHandlesChanged = onSelectionHandlesChanged,
    )
}

/**
 * Value-based overload for Compose-style call sites.
 */
@Composable
fun MongolTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color(0xFF1B5E20),
    selectionColor: Color = Color(0x552196F3),
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
) {
    val state = rememberMongolEditableState(initialText = value)

    LaunchedEffect(value) {
        if (state.text != value) {
            state.replaceText(value)
        }
    }

    MongolTextField(
        state = state,
        modifier = modifier,
        style = style,
        textAlign = textAlign,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        enabled = enabled,
        readOnly = readOnly,
        caretColor = caretColor,
        selectionColor = selectionColor,
        onTextChange = onValueChange,
        onInputSessionReady = onInputSessionReady,
        onSelectionHandlesChanged = onSelectionHandlesChanged,
    )
}
