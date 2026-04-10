package mongol.compose.editing

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text as M3Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.TextRun
import mongol.compose.text.MongolText

@Immutable
data class MongolTextFieldColors(
    val focusedContainerColor: Color,
    val unfocusedContainerColor: Color,
    val disabledContainerColor: Color,
    val focusedBorderColor: Color,
    val unfocusedBorderColor: Color,
    val disabledBorderColor: Color,
    val focusedTextColor: Color,
    val unfocusedTextColor: Color,
    val disabledTextColor: Color,
    val placeholderColor: Color,
    val focusedLabelColor: Color,
    val unfocusedLabelColor: Color,
    val disabledLabelColor: Color,
    val errorColor: Color,
    val supportingTextColor: Color,
    val caretColor: Color,
    val selectionColor: Color,
) {
    fun containerColor(enabled: Boolean, focused: Boolean): Color {
        if (!enabled) return disabledContainerColor
        return if (focused) focusedContainerColor else unfocusedContainerColor
    }

    fun borderColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (isError) return errorColor
        if (!enabled) return disabledBorderColor
        return if (focused) focusedBorderColor else unfocusedBorderColor
    }

    fun textColor(enabled: Boolean, focused: Boolean): Color {
        if (!enabled) return disabledTextColor
        return if (focused) focusedTextColor else unfocusedTextColor
    }

    fun labelColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (isError) return errorColor
        if (!enabled) return disabledLabelColor
        return if (focused) focusedLabelColor else unfocusedLabelColor
    }

    fun supportingColor(enabled: Boolean, isError: Boolean): Color {
        if (isError) return errorColor
        if (!enabled) return disabledLabelColor
        return supportingTextColor
    }
}

@Immutable
data class MongolTextFieldDecorationState(
    val text: String,
    val isEmpty: Boolean,
    val focused: Boolean,
    val enabled: Boolean,
    val readOnly: Boolean,
    val style: TextStyle,
    val textAlign: MongolTextAlign,
    val textRuns: List<TextRun>?,
    val rotateCjk: Boolean,
    val isError: Boolean,
    val currentLength: Int,
    val maxLength: Int?,
)

object MongolTextFieldDefaults {
    fun colors(
        caretColor: Color = Color(0xFF1B5E20),
        selectionColor: Color = Color(0x552196F3),
    ): MongolTextFieldColors {
        return MongolTextFieldColors(
            focusedContainerColor = Color(0xFFF7FAF7),
            unfocusedContainerColor = Color(0xFFF5F5F5),
            disabledContainerColor = Color(0xFFECECEC),
            focusedBorderColor = Color(0xFF2E7D32),
            unfocusedBorderColor = Color(0xFFBDBDBD),
            disabledBorderColor = Color(0xFFDDDDDD),
            focusedTextColor = Color(0xFF111111),
            unfocusedTextColor = Color(0xFF212121),
            disabledTextColor = Color(0xFF8A8A8A),
            placeholderColor = Color(0xFF8F8F8F),
            focusedLabelColor = Color(0xFF2E7D32),
            unfocusedLabelColor = Color(0xFF6D6D6D),
            disabledLabelColor = Color(0xFF9A9A9A),
            errorColor = Color(0xFFB3261E),
            supportingTextColor = Color(0xFF666666),
            caretColor = caretColor,
            selectionColor = selectionColor,
        )
    }

    @Composable
    fun DecorationBox(
        decorationState: MongolTextFieldDecorationState,
        innerTextField: @Composable () -> Unit,
        modifier: Modifier = Modifier,
        label: String? = null,
        placeholder: String? = null,
        leadingContent: (@Composable () -> Unit)? = null,
        trailingContent: (@Composable () -> Unit)? = null,
        prefixContent: (@Composable () -> Unit)? = null,
        suffixContent: (@Composable () -> Unit)? = null,
        colors: MongolTextFieldColors = colors(),
        contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        shape: Shape = RoundedCornerShape(12.dp),
        borderWidth: Dp = 1.dp,
        placeholderStyle: TextStyle = decorationState.style,
    ) {
        Column(
            modifier = modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (!label.isNullOrEmpty()) {
                M3Text(
                    text = label,
                    color = colors.labelColor(
                        enabled = decorationState.enabled,
                        focused = decorationState.focused,
                        isError = decorationState.isError,
                    ),
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minWidth = 100.dp, minHeight = 120.dp)
                    .background(
                        color = colors.containerColor(decorationState.enabled, decorationState.focused),
                        shape = shape,
                    )
                    .border(
                        width = borderWidth,
                        color = colors.borderColor(
                            enabled = decorationState.enabled,
                            focused = decorationState.focused,
                            isError = decorationState.isError,
                        ),
                        shape = shape,
                    )
                    .padding(contentPadding),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                leadingContent?.invoke()
                prefixContent?.invoke()

                Box(
                    modifier = Modifier
                        .weight(1f, fill = true)
                        .fillMaxHeight(),
                ) {
                    if (decorationState.isEmpty && !placeholder.isNullOrEmpty()) {
                        MongolText(
                            text = placeholder,
                            modifier = Modifier.fillMaxHeight(),
                            textAlign = decorationState.textAlign,
                            textRuns = decorationState.textRuns,
                            rotateCjk = decorationState.rotateCjk,
                            style = placeholderStyle.copy(color = colors.placeholderColor),
                        )
                    }
                    innerTextField()
                }

                suffixContent?.invoke()
                trailingContent?.invoke()
            }
        }
    }
}

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
    singleLine: Boolean = false,
    maxLength: Int? = null,
    label: String? = null,
    isError: Boolean = false,
    placeholder: String? = null,
    placeholderStyle: TextStyle = style,
    supportingText: String? = null,
    leadingContent: (@Composable () -> Unit)? = null,
    trailingContent: (@Composable () -> Unit)? = null,
    prefixContent: (@Composable () -> Unit)? = null,
    suffixContent: (@Composable () -> Unit)? = null,
    supportingContent: (@Composable () -> Unit)? = null,
    colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(
        caretColor = caretColor,
        selectionColor = selectionColor,
    ),
    shape: Shape = RoundedCornerShape(12.dp),
    borderWidth: Dp = 1.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    decorationBox: @Composable (
        innerTextField: @Composable () -> Unit,
        decorationState: MongolTextFieldDecorationState,
    ) -> Unit = { innerTextField, decorationState ->
        MongolTextFieldDefaults.DecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            label = label,
            placeholder = placeholder,
            leadingContent = leadingContent,
            trailingContent = trailingContent,
            prefixContent = prefixContent,
            suffixContent = suffixContent,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            borderWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    },
) {
    require(maxLength == null || maxLength > 0) {
        "maxLength must be null or > 0"
    }

    var focused by remember { mutableStateOf(false) }

    LaunchedEffect(value, state) {
        if (value != null && value != state.text) {
            state.replaceText(value)
        }
    }

    fun normalizeText(next: String): String {
        var normalized = if (singleLine) {
            next.replace('\n', ' ')
        } else {
            next
        }
        if (maxLength != null && maxLength > 0 && normalized.length > maxLength) {
            normalized = normalized.take(maxLength)
        }
        return normalized
    }

    val effectiveOnTextChange: (String) -> Unit = onValueChange ?: onTextChange

    val decorationState = MongolTextFieldDecorationState(
        text = state.text,
        isEmpty = state.text.isEmpty(),
        focused = focused,
        enabled = enabled,
        readOnly = readOnly,
        style = style.copy(color = colors.textColor(enabled, focused)),
        textAlign = textAlign,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        isError = isError,
        currentLength = state.text.length,
        maxLength = maxLength,
    )

    val innerTextField: @Composable () -> Unit = {
        MongolBasicTextField(
            state = state,
            modifier = Modifier.fillMaxSize(),
            style = style.copy(color = colors.textColor(enabled, focused)),
            textAlign = textAlign,
            textRuns = textRuns,
            rotateCjk = rotateCjk,
            enabled = enabled,
            readOnly = readOnly,
            caretColor = colors.caretColor,
            selectionColor = colors.selectionColor,
            onTextChange = { next ->
                val normalized = normalizeText(next)
                if (normalized != next) {
                    state.replaceText(normalized)
                }
                effectiveOnTextChange(normalized)
            },
            onInputSessionReady = onInputSessionReady,
            onSelectionHandlesChanged = onSelectionHandlesChanged,
            onFocusChanged = { focused = it },
        )
    }

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        decorationBox(innerTextField, decorationState)
        when {
            supportingContent != null -> supportingContent()
            !supportingText.isNullOrEmpty() || maxLength != null -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    M3Text(
                        text = supportingText.orEmpty(),
                        color = colors.supportingColor(enabled = enabled, isError = isError),
                    )
                    if (maxLength != null) {
                        M3Text(
                            text = "${state.text.length}/$maxLength",
                            color = colors.supportingColor(
                                enabled = enabled,
                                isError = isError,
                            ),
                        )
                    }
                }
            }
        }
    }
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
    singleLine: Boolean = false,
    maxLength: Int? = null,
    label: String? = null,
    isError: Boolean = false,
    placeholder: String? = null,
    placeholderStyle: TextStyle = style,
    supportingText: String? = null,
    leadingContent: (@Composable () -> Unit)? = null,
    trailingContent: (@Composable () -> Unit)? = null,
    prefixContent: (@Composable () -> Unit)? = null,
    suffixContent: (@Composable () -> Unit)? = null,
    supportingContent: (@Composable () -> Unit)? = null,
    colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(
        caretColor = caretColor,
        selectionColor = selectionColor,
    ),
    shape: Shape = RoundedCornerShape(12.dp),
    borderWidth: Dp = 1.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    decorationBox: @Composable (
        innerTextField: @Composable () -> Unit,
        decorationState: MongolTextFieldDecorationState,
    ) -> Unit = { innerTextField, decorationState ->
        MongolTextFieldDefaults.DecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            label = label,
            placeholder = placeholder,
            leadingContent = leadingContent,
            trailingContent = trailingContent,
            prefixContent = prefixContent,
            suffixContent = suffixContent,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            borderWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    },
) {
    require(maxLength == null || maxLength > 0) {
        "maxLength must be null or > 0"
    }

    val state = rememberMongolEditableState(initialText = value)

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
        onValueChange = onValueChange,
        value = value,
        onInputSessionReady = onInputSessionReady,
        onSelectionHandlesChanged = onSelectionHandlesChanged,
        singleLine = singleLine,
        maxLength = maxLength,
        label = label,
        isError = isError,
        placeholder = placeholder,
        placeholderStyle = placeholderStyle,
        supportingText = supportingText,
        leadingContent = leadingContent,
        trailingContent = trailingContent,
        prefixContent = prefixContent,
        suffixContent = suffixContent,
        supportingContent = supportingContent,
        colors = colors,
        shape = shape,
        borderWidth = borderWidth,
        contentPadding = contentPadding,
        decorationBox = decorationBox,
    )
}
