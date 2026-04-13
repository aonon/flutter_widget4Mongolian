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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.input.InputTransformation
import androidx.compose.foundation.text.input.TextFieldState
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.TextFieldColors
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.TextRun
import kotlin.math.max

@Immutable
data class MongolTextFieldColors(
    val focusedContainerColor: Color,
    val unfocusedContainerColor: Color,
    val disabledContainerColor: Color,
    val errorContainerColor: Color,
    val focusedBorderColor: Color,
    val unfocusedBorderColor: Color,
    val disabledBorderColor: Color,
    val errorBorderColor: Color,
    val focusedTextColor: Color,
    val unfocusedTextColor: Color,
    val disabledTextColor: Color,
    val errorTextColor: Color,
    val focusedPlaceholderColor: Color,
    val unfocusedPlaceholderColor: Color,
    val disabledPlaceholderColor: Color,
    val errorPlaceholderColor: Color,
    val focusedLabelColor: Color,
    val unfocusedLabelColor: Color,
    val disabledLabelColor: Color,
    val errorLabelColor: Color,
    val focusedSupportingTextColor: Color,
    val unfocusedSupportingTextColor: Color,
    val disabledSupportingTextColor: Color,
    val errorSupportingTextColor: Color,
    val caretColor: Color,
    val errorCaretColor: Color,
    val selectionColor: Color,
) {
    fun containerColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (!enabled) return disabledContainerColor
        if (isError) return errorContainerColor
        return if (focused) focusedContainerColor else unfocusedContainerColor
    }

    fun borderColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (isError) return errorBorderColor
        if (!enabled) return disabledBorderColor
        return if (focused) focusedBorderColor else unfocusedBorderColor
    }

    fun textColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (!enabled) return disabledTextColor
        if (isError) return errorTextColor
        return if (focused) focusedTextColor else unfocusedTextColor
    }

    fun placeholderColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (!enabled) return disabledPlaceholderColor
        if (isError) return errorPlaceholderColor
        return if (focused) focusedPlaceholderColor else unfocusedPlaceholderColor
    }

    fun labelColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (isError) return errorLabelColor
        if (!enabled) return disabledLabelColor
        return if (focused) focusedLabelColor else unfocusedLabelColor
    }

    fun supportingColor(enabled: Boolean, focused: Boolean, isError: Boolean): Color {
        if (isError) return errorSupportingTextColor
        if (!enabled) return disabledSupportingTextColor
        return if (focused) focusedSupportingTextColor else unfocusedSupportingTextColor
    }

    fun caretColor(isError: Boolean): Color {
        return if (isError) errorCaretColor else caretColor
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
)

enum class MongolTextFieldLabelPosition {
    Attached,
    Above,
}

private fun applyInputTransformation(
    current: String,
    proposed: String,
    inputTransformation: InputTransformation?,
): String {
    if (inputTransformation == null || current == proposed) return proposed

    val prefixLength = current.commonPrefixWith(proposed).length
    var currentSuffixLength = 0
    var proposedSuffixLength = 0
    val maxSuffixLength = minOf(current.length - prefixLength, proposed.length - prefixLength)
    while (
        currentSuffixLength < maxSuffixLength &&
        current[current.length - currentSuffixLength - 1] ==
        proposed[proposed.length - proposedSuffixLength - 1]
    ) {
        currentSuffixLength += 1
        proposedSuffixLength += 1
    }

    val currentReplaceEnd = current.length - currentSuffixLength
    val proposedReplaceEnd = proposed.length - proposedSuffixLength
    val replacement = proposed.substring(prefixLength, proposedReplaceEnd)

    val transformedState = TextFieldState(
        initialText = current,
        initialSelection = TextRange(current.length),
    )
    transformedState.edit {
        replace(prefixLength, currentReplaceEnd, replacement)
        selection = TextRange(prefixLength + replacement.length)
        with(inputTransformation) {
            transformInput()
        }
    }
    return transformedState.text.toString()
}

object MongolTextFieldDefaults {
    @Composable
    fun filledColors(): MongolTextFieldColors = colors(TextFieldDefaults.colors())

    @Composable
    fun colors(): MongolTextFieldColors = filledColors()

    fun colors(material3Colors: TextFieldColors): MongolTextFieldColors {
        return MongolTextFieldColors(
            focusedContainerColor = material3Colors.focusedContainerColor,
            unfocusedContainerColor = material3Colors.unfocusedContainerColor,
            disabledContainerColor = material3Colors.disabledContainerColor,
            errorContainerColor = material3Colors.errorContainerColor,
            focusedBorderColor = material3Colors.focusedIndicatorColor,
            unfocusedBorderColor = material3Colors.unfocusedIndicatorColor,
            disabledBorderColor = material3Colors.disabledIndicatorColor,
            errorBorderColor = material3Colors.errorIndicatorColor,
            focusedTextColor = material3Colors.focusedTextColor,
            unfocusedTextColor = material3Colors.unfocusedTextColor,
            disabledTextColor = material3Colors.disabledTextColor,
            errorTextColor = material3Colors.errorTextColor,
            focusedPlaceholderColor = material3Colors.focusedPlaceholderColor,
            unfocusedPlaceholderColor = material3Colors.unfocusedPlaceholderColor,
            disabledPlaceholderColor = material3Colors.disabledPlaceholderColor,
            errorPlaceholderColor = material3Colors.errorPlaceholderColor,
            focusedLabelColor = material3Colors.focusedLabelColor,
            unfocusedLabelColor = material3Colors.unfocusedLabelColor,
            disabledLabelColor = material3Colors.disabledLabelColor,
            errorLabelColor = material3Colors.errorLabelColor,
            focusedSupportingTextColor = material3Colors.focusedSupportingTextColor,
            unfocusedSupportingTextColor = material3Colors.unfocusedSupportingTextColor,
            disabledSupportingTextColor = material3Colors.disabledSupportingTextColor,
            errorSupportingTextColor = material3Colors.errorSupportingTextColor,
            caretColor = material3Colors.cursorColor,
            errorCaretColor = material3Colors.errorCursorColor,
            selectionColor = material3Colors.textSelectionColors.backgroundColor,
        )
    }

    @Composable
    fun OutlinedDecorationBox(
        decorationState: MongolTextFieldDecorationState,
        innerTextField: @Composable () -> Unit,
        modifier: Modifier = Modifier,
        label: (@Composable () -> Unit)? = null,
        labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
        placeholder: (@Composable () -> Unit)? = null,
        leadingIcon: (@Composable () -> Unit)? = null,
        trailingIcon: (@Composable () -> Unit)? = null,
        prefix: (@Composable () -> Unit)? = null,
        suffix: (@Composable () -> Unit)? = null,
        colors: MongolTextFieldColors = colors(),
        contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        shape: Shape = RoundedCornerShape(12.dp),
        borderWidth: Dp = 1.dp,
        placeholderStyle: TextStyle = decorationState.style,
    ) {
        val container: @Composable (Modifier) -> Unit = { containerModifier ->
            Row(
                modifier = containerModifier
                    .background(
                        color = colors.containerColor(
                            enabled = decorationState.enabled,
                            focused = decorationState.focused,
                            isError = decorationState.isError,
                        ),
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
                if (label != null && labelPosition == MongolTextFieldLabelPosition.Attached) {
                    CompositionLocalProvider(
                        LocalContentColor provides colors.labelColor(
                            enabled = decorationState.enabled,
                            focused = decorationState.focused,
                            isError = decorationState.isError,
                        ),
                    ) {
                        label()
                    }
                }

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    horizontalAlignment = Alignment.Start,
                ) {
                    leadingIcon?.invoke()
                    prefix?.invoke()

                    Box(
                        modifier = Modifier
                            .weight(1f),
                    ) {
                        if (decorationState.isEmpty && placeholder != null) {
                            androidx.compose.material3.ProvideTextStyle(placeholderStyle) {
                                CompositionLocalProvider(
                                    LocalContentColor provides colors.placeholderColor(
                                        enabled = decorationState.enabled,
                                        focused = decorationState.focused,
                                        isError = decorationState.isError,
                                    ),
                                ) {
                                    placeholder()
                                }
                            }
                        }
                        innerTextField()
                    }

                    suffix?.invoke()
                    trailingIcon?.invoke()
                }
            }
        }

        container(modifier)
    }

    @Composable
    fun DecorationBox(
        decorationState: MongolTextFieldDecorationState,
        innerTextField: @Composable () -> Unit,
        modifier: Modifier = Modifier,
        label: (@Composable () -> Unit)? = null,
        labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
        placeholder: (@Composable () -> Unit)? = null,
        leadingIcon: (@Composable () -> Unit)? = null,
        trailingIcon: (@Composable () -> Unit)? = null,
        prefix: (@Composable () -> Unit)? = null,
        suffix: (@Composable () -> Unit)? = null,
        colors: MongolTextFieldColors = colors(),
        contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        shape: Shape = RoundedCornerShape(12.dp),
        borderWidth: Dp = 1.dp,
        placeholderStyle: TextStyle = decorationState.style,
    ) {
        OutlinedDecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            modifier = modifier,
            label = label,
            labelPosition = labelPosition,
            placeholder = placeholder,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            prefix = prefix,
            suffix = suffix,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            borderWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    }

    @Composable
    fun FilledDecorationBox(
        decorationState: MongolTextFieldDecorationState,
        innerTextField: @Composable () -> Unit,
        modifier: Modifier = Modifier,
        label: (@Composable () -> Unit)? = null,
        labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
        placeholder: (@Composable () -> Unit)? = null,
        leadingIcon: (@Composable () -> Unit)? = null,
        trailingIcon: (@Composable () -> Unit)? = null,
        prefix: (@Composable () -> Unit)? = null,
        suffix: (@Composable () -> Unit)? = null,
        colors: MongolTextFieldColors = colors(),
        contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        shape: Shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
        indicatorWidth: Dp = 1.dp,
        placeholderStyle: TextStyle = decorationState.style,
    ) {
        val container: @Composable (Modifier) -> Unit = { containerModifier ->
            Row(
                modifier = containerModifier
                    .background(
                        color = colors.containerColor(
                            enabled = decorationState.enabled,
                            focused = decorationState.focused,
                            isError = decorationState.isError,
                        ),
                        shape = shape,
                    ),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .padding(contentPadding),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (label != null && labelPosition == MongolTextFieldLabelPosition.Attached) {
                        CompositionLocalProvider(
                            LocalContentColor provides colors.labelColor(
                                enabled = decorationState.enabled,
                                focused = decorationState.focused,
                                isError = decorationState.isError,
                            ),
                        ) {
                            label()
                        }
                    }

                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        horizontalAlignment = Alignment.Start,
                    ) {
                        leadingIcon?.invoke()
                        prefix?.invoke()

                        Box(
                            modifier = Modifier
                                .weight(1f),
                        ) {
                            if (decorationState.isEmpty && placeholder != null) {
                                androidx.compose.material3.ProvideTextStyle(placeholderStyle) {
                                    CompositionLocalProvider(
                                        LocalContentColor provides colors.placeholderColor(
                                            enabled = decorationState.enabled,
                                            focused = decorationState.focused,
                                            isError = decorationState.isError,
                                        ),
                                    ) {
                                        placeholder()
                                    }
                                }
                            }
                            innerTextField()
                        }

                        suffix?.invoke()
                        trailingIcon?.invoke()
                    }
                }

                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(indicatorWidth)
                        .background(
                            color = colors.borderColor(
                                enabled = decorationState.enabled,
                                focused = decorationState.focused,
                                isError = decorationState.isError,
                            ),
                        ),
                )
            }
        }

        container(modifier)
    }
}

/**
 * High-level editable entry point for a filled text field.
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
    caretColor: Color = Color.Unspecified,
    selectionColor: Color = Color.Unspecified,
    onTextChange: (String) -> Unit = {},
    value: String? = null,
    onValueChange: ((String) -> Unit)? = null,
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    inputTransformation: InputTransformation? = null,
    singleLine: Boolean = false,
    label: (@Composable () -> Unit)? = null,
    labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
    isError: Boolean = false,
    placeholder: (@Composable () -> Unit)? = null,
    placeholderStyle: TextStyle = style,
    supportingText: (@Composable () -> Unit)? = null,
    leadingIcon: (@Composable () -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    prefix: (@Composable () -> Unit)? = null,
    suffix: (@Composable () -> Unit)? = null,
    colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(),
    shape: Shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
    borderWidth: Dp = 1.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    decorationBox: @Composable (
        innerTextField: @Composable () -> Unit,
        decorationState: MongolTextFieldDecorationState,
    ) -> Unit = { innerTextField, decorationState ->
        MongolTextFieldDefaults.FilledDecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            label = label,
            labelPosition = labelPosition,
            placeholder = placeholder,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            prefix = prefix,
            suffix = suffix,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            indicatorWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    },
    autoWidthByContent: Boolean = true,
) {
    MongolOutlinedTextField(
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
        onTextChange = onTextChange,
        value = value,
        onValueChange = onValueChange,
        onInputSessionReady = onInputSessionReady,
        onSelectionHandlesChanged = onSelectionHandlesChanged,
        inputTransformation = inputTransformation,
        singleLine = singleLine,
        label = label,
        labelPosition = labelPosition,
        isError = isError,
        placeholder = placeholder,
        placeholderStyle = placeholderStyle,
        supportingText = supportingText,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        prefix = prefix,
        suffix = suffix,
        colors = colors,
        shape = shape,
        borderWidth = borderWidth,
        contentPadding = contentPadding,
        decorationBox = decorationBox,
        autoWidthByContent = autoWidthByContent,
    )
}

/**
 * Value-based overload for Compose-style call sites.
 */
@Composable
fun MongolOutlinedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color.Unspecified,
    selectionColor: Color = Color.Unspecified,
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    inputTransformation: InputTransformation? = null,
    singleLine: Boolean = false,
    label: (@Composable () -> Unit)? = null,
    labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
    isError: Boolean = false,
    placeholder: (@Composable () -> Unit)? = null,
    placeholderStyle: TextStyle = style,
    supportingText: (@Composable () -> Unit)? = null,
    leadingIcon: (@Composable () -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    prefix: (@Composable () -> Unit)? = null,
    suffix: (@Composable () -> Unit)? = null,
    colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(),
    shape: Shape = RoundedCornerShape(12.dp),
    borderWidth: Dp = 1.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    decorationBox: @Composable (
        innerTextField: @Composable () -> Unit,
        decorationState: MongolTextFieldDecorationState,
    ) -> Unit = { innerTextField, decorationState ->
        MongolTextFieldDefaults.OutlinedDecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            label = label,
            labelPosition = labelPosition,
            placeholder = placeholder,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            prefix = prefix,
            suffix = suffix,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            borderWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    },
    autoWidthByContent: Boolean = true,
) {
    val state = rememberMongolEditableState(initialText = value)

    MongolOutlinedTextField(
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
        inputTransformation = inputTransformation,
        singleLine = singleLine,
        label = label,
        labelPosition = labelPosition,
        isError = isError,
        placeholder = placeholder,
        placeholderStyle = placeholderStyle,
        supportingText = supportingText,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        prefix = prefix,
        suffix = suffix,
        colors = colors,
        shape = shape,
        borderWidth = borderWidth,
        contentPadding = contentPadding,
        decorationBox = decorationBox,
        autoWidthByContent = autoWidthByContent,
    )
}

/**
 * High-level editable entry point for an outlined text field.
 */
@Composable
fun MongolOutlinedTextField(
    state: MongolEditableState,
    modifier: Modifier = Modifier,
    style: TextStyle = TextStyle.Default,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    caretColor: Color = Color.Unspecified,
    selectionColor: Color = Color.Unspecified,
    onTextChange: (String) -> Unit = {},
    value: String? = null,
    onValueChange: ((String) -> Unit)? = null,
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    inputTransformation: InputTransformation? = null,
    singleLine: Boolean = false,
    label: (@Composable () -> Unit)? = null,
    labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
    isError: Boolean = false,
    placeholder: (@Composable () -> Unit)? = null,
    placeholderStyle: TextStyle = style,
    supportingText: (@Composable () -> Unit)? = null,
    leadingIcon: (@Composable () -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    prefix: (@Composable () -> Unit)? = null,
    suffix: (@Composable () -> Unit)? = null,
    colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(),
    shape: Shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
    borderWidth: Dp = 1.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    decorationBox: @Composable (
        innerTextField: @Composable () -> Unit,
        decorationState: MongolTextFieldDecorationState,
    ) -> Unit = { innerTextField, decorationState ->
        MongolTextFieldDefaults.OutlinedDecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            label = label,
            labelPosition = labelPosition,
            placeholder = placeholder,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            prefix = prefix,
            suffix = suffix,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            borderWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    },
    autoWidthByContent: Boolean = true,
) {
    var focused by remember { mutableStateOf(false) }
    LaunchedEffect(value, state) {
        if (value != null && value != state.text) {
            state.replaceText(value)
        }
    }

    fun normalizeText(next: String): String {
        var normalized = applyInputTransformation(state.text, next, inputTransformation)
        normalized = if (singleLine) {
            normalized.replace('\n', ' ')
        } else {
            normalized
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
        style = style.copy(color = colors.textColor(enabled, focused, isError)),
        textAlign = textAlign,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        isError = isError,
    )

    val effectiveCaretColor = if (caretColor != Color.Unspecified) caretColor else colors.caretColor(isError)
    val effectiveSelectionColor = if (selectionColor != Color.Unspecified) selectionColor else colors.selectionColor

    val innerTextField: @Composable () -> Unit = {
        MongolBasicTextField(
            state = state,
            modifier = Modifier.fillMaxHeight(),
            style = style.copy(color = colors.textColor(enabled, focused, isError)),
            textAlign = textAlign,
            textRuns = textRuns,
            rotateCjk = rotateCjk,
            enabled = enabled,
            readOnly = readOnly,
            caretColor = effectiveCaretColor,
            selectionColor = effectiveSelectionColor,
            normalizeTextChange = { current, proposed ->
                var normalized = applyInputTransformation(current, proposed, inputTransformation)
                if (singleLine) {
                    normalized = normalized.replace('\n', ' ')
                }
                normalized
            },
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

    val showAboveLabel = label != null && labelPosition == MongolTextFieldLabelPosition.Above

    Layout(
        modifier = modifier,
        content = {
            if (showAboveLabel) {
                CompositionLocalProvider(
                    LocalContentColor provides colors.labelColor(
                        enabled = enabled,
                        focused = focused,
                        isError = isError,
                    ),
                ) {
                    label.invoke()
                }
            }
            Box {
                decorationBox(
                    innerTextField,
                    decorationState.copy(),
                )
            }
            if (supportingText != null) {
                CompositionLocalProvider(
                    LocalContentColor provides colors.supportingColor(
                        enabled = enabled,
                        focused = focused,
                        isError = isError,
                    ),
                ) {
                    supportingText()
                }
            }
        },
    ) { measurables, constraints ->
        val spacing = 6.dp.roundToPx()
        val fieldMinWidth = 20.dp.roundToPx()
        val unconstrainedWidthFallback = 1200.dp.roundToPx()
        val looseConstraints = constraints.copy(minWidth = 0, minHeight = 0)
        var index = 0
        val labelPlaceable = if (showAboveLabel) {
            measurables[index++].measure(looseConstraints)
        } else {
            null
        }

        val labelSpacing = if (labelPlaceable != null) spacing else 0
        val availableAfterLabel = if (constraints.maxWidth == Int.MAX_VALUE) {
            Int.MAX_VALUE
        } else {
            max(0, constraints.maxWidth - (labelPlaceable?.width ?: 0) - labelSpacing)
        }

        val fieldMeasurable = measurables[index++]
        val supportingTextMeasurable = measurables.getOrNull(index)?.takeIf { supportingText != null }
        if (supportingText != null) {
            index += 1
        }

        val supportSlotSpacing = if (supportingTextMeasurable != null) spacing else 0

        val supportingTextPlaceable = supportingTextMeasurable?.measure(looseConstraints)
        val supportingWidth = supportingTextPlaceable?.width ?: 0

        val fieldMaxWidth = if (constraints.maxWidth == Int.MAX_VALUE) {
            Int.MAX_VALUE
        } else {
            max(0, availableAfterLabel - supportingWidth - if (supportingWidth > 0) spacing else 0)
        }
        val effectiveFieldMaxWidth = if (fieldMaxWidth == Int.MAX_VALUE) {
            unconstrainedWidthFallback
        } else {
            fieldMaxWidth
        }

        val fontSizePx = if (style.fontSize.type == TextUnitType.Sp) style.fontSize.toPx() else 16.sp.toPx()
        val lineSpan = max((fontSizePx * 1.5f).toInt(), 1)
        val intrinsicHeightHint = if (constraints.hasBoundedHeight) {
            constraints.maxHeight
        } else {
            10_000
        }

        val intrinsicFieldWidth = fieldMeasurable
            .minIntrinsicWidth(intrinsicHeightHint)
            .coerceAtLeast(0)

        val targetFieldWidth = if (autoWidthByContent) {
            val steppedWidth = if (intrinsicFieldWidth <= 0) {
                lineSpan
            } else {
                ((intrinsicFieldWidth + lineSpan - 1) / lineSpan) * lineSpan
            }

            steppedWidth.coerceIn(
                minimumValue = fieldMinWidth,
                maximumValue = max(fieldMinWidth, effectiveFieldMaxWidth),
            )
        } else {
            intrinsicFieldWidth
                .coerceAtLeast(fieldMinWidth)
                .coerceAtMost(max(fieldMinWidth, effectiveFieldMaxWidth))
        }

        val fieldPlaceable = fieldMeasurable.measure(
            looseConstraints.copy(
                minWidth = targetFieldWidth,
                maxWidth = targetFieldWidth,
            ),
        )

        val totalWidth =
            (labelPlaceable?.width ?: 0) +
                labelSpacing +
                fieldPlaceable.width +
                (if (supportingWidth > 0) spacing + supportingWidth else 0)
        val supportingHeight =
            if (supportingTextPlaceable != null) {
                max(
                    fieldPlaceable.height,
                    supportingTextPlaceable.height,
                )
            } else {
                0
            }
        val totalHeight = max(max(labelPlaceable?.height ?: 0, fieldPlaceable.height), supportingHeight)

        layout(
            width = totalWidth.coerceIn(constraints.minWidth, constraints.maxWidth),
            height = totalHeight.coerceIn(constraints.minHeight, constraints.maxHeight),
        ) {
            var x = 0
            labelPlaceable?.let {
                it.placeRelative(x, 0)
                x += it.width + spacing
            }
            fieldPlaceable.placeRelative(x, 0)
            x += fieldPlaceable.width
            if (supportingWidth > 0) {
                val supportingX = x + spacing
                supportingTextPlaceable?.placeRelative(supportingX, 0)
            }
        }
    }
}

/**
 * Value-based overload for a filled text field.
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
    caretColor: Color = Color.Unspecified,
    selectionColor: Color = Color.Unspecified,
    onInputSessionReady: (MongolInputSession) -> Unit = {},
    onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    inputTransformation: InputTransformation? = null,
    singleLine: Boolean = false,
    label: (@Composable () -> Unit)? = null,
    labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
    isError: Boolean = false,
    placeholder: (@Composable () -> Unit)? = null,
    placeholderStyle: TextStyle = style,
    supportingText: (@Composable () -> Unit)? = null,
    leadingIcon: (@Composable () -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    prefix: (@Composable () -> Unit)? = null,
    suffix: (@Composable () -> Unit)? = null,
    colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(),
    shape: Shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
    borderWidth: Dp = 1.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    decorationBox: @Composable (
        innerTextField: @Composable () -> Unit,
        decorationState: MongolTextFieldDecorationState,
    ) -> Unit = { innerTextField, decorationState ->
        MongolTextFieldDefaults.FilledDecorationBox(
            decorationState = decorationState,
            innerTextField = innerTextField,
            label = label,
            labelPosition = labelPosition,
            placeholder = placeholder,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            prefix = prefix,
            suffix = suffix,
            colors = colors,
            contentPadding = contentPadding,
            shape = shape,
            indicatorWidth = borderWidth,
            placeholderStyle = placeholderStyle,
        )
    },
    autoWidthByContent: Boolean = true,
) {
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
        inputTransformation = inputTransformation,
        singleLine = singleLine,
        label = label,
        labelPosition = labelPosition,
        isError = isError,
        placeholder = placeholder,
        placeholderStyle = placeholderStyle,
        supportingText = supportingText,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        prefix = prefix,
        suffix = suffix,
        colors = colors,
        shape = shape,
        borderWidth = borderWidth,
        contentPadding = contentPadding,
        decorationBox = decorationBox,
        autoWidthByContent = autoWidthByContent,
    )
}
