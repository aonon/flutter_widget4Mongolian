package mongol.compose.editing

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.input.InputTransformation
import androidx.compose.foundation.text.input.TextFieldLineLimits
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.changedToDown
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.TextRun
import kotlin.math.max
import kotlin.math.roundToInt

@Immutable
data class MongolTextFieldColors(
    val focusedContainerColor: Color, val unfocusedContainerColor: Color, val disabledContainerColor: Color, val errorContainerColor: Color,
    val focusedBorderColor: Color, val unfocusedBorderColor: Color, val disabledBorderColor: Color, val errorBorderColor: Color,
    val focusedTextColor: Color, val unfocusedTextColor: Color, val disabledTextColor: Color, val errorTextColor: Color,
    val focusedPlaceholderColor: Color, val unfocusedPlaceholderColor: Color, val disabledPlaceholderColor: Color, val errorPlaceholderColor: Color,
    val focusedLabelColor: Color, val unfocusedLabelColor: Color, val disabledLabelColor: Color, val errorLabelColor: Color,
    val focusedSupportingTextColor: Color, val unfocusedSupportingTextColor: Color, val disabledSupportingTextColor: Color, val errorSupportingTextColor: Color,
    val caretColor: Color, val errorCaretColor: Color, val selectionColor: Color,
) {
    fun containerColor(e: Boolean, f: Boolean, r: Boolean): Color = if (!e) disabledContainerColor else if (r) errorContainerColor else if (f) focusedContainerColor else unfocusedContainerColor
    fun borderColor(e: Boolean, f: Boolean, r: Boolean): Color = if (r) errorBorderColor else if (!e) disabledBorderColor else if (f) focusedBorderColor else unfocusedBorderColor
    fun textColor(e: Boolean, f: Boolean, r: Boolean): Color = if (!e) disabledTextColor else if (r) errorTextColor else if (f) focusedTextColor else unfocusedTextColor
    fun placeholderColor(e: Boolean, f: Boolean, r: Boolean): Color = if (!e) disabledPlaceholderColor else if (r) errorPlaceholderColor else if (f) focusedPlaceholderColor else unfocusedPlaceholderColor
    fun labelColor(e: Boolean, f: Boolean, r: Boolean): Color = if (r) errorLabelColor else if (!e) disabledLabelColor else if (f) focusedLabelColor else unfocusedLabelColor
    fun supportingColor(e: Boolean, f: Boolean, r: Boolean): Color = if (r) errorSupportingTextColor else if (!e) disabledSupportingTextColor else if (f) focusedSupportingTextColor else unfocusedSupportingTextColor
    fun caretColor(r: Boolean): Color = if (r) errorCaretColor else caretColor
}

@Immutable
data class MongolTextFieldDecorationState(
    val text: String, val isEmpty: Boolean, val focused: Boolean, val enabled: Boolean, val readOnly: Boolean,
    val style: TextStyle, val textAlign: MongolTextAlign, val textRuns: List<TextRun>?, val rotateCjk: Boolean, val isError: Boolean,
)

enum class MongolTextFieldLabelPosition { Attached, Above }

private fun applyInputTransformation(c: String, p: String, t: InputTransformation?): String {
    if (t == null || c == p) return p
    val s = TextFieldState(c, TextRange(c.length))
    s.edit { val pl = c.commonPrefixWith(p).length; val sl = c.substring(pl).commonSuffixWith(p.substring(pl)).length; replace(pl, c.length - sl, p.substring(pl, p.length - sl)); with(t) { transformInput() } }
    return s.text.toString()
}

object MongolTextFieldDefaults {
    @Composable fun colors(): MongolTextFieldColors = colors(TextFieldDefaults.colors())
    fun colors(m: TextFieldColors): MongolTextFieldColors = MongolTextFieldColors(
        focusedContainerColor = m.focusedContainerColor, unfocusedContainerColor = m.unfocusedContainerColor, disabledContainerColor = m.disabledContainerColor, errorContainerColor = m.errorContainerColor,
        focusedBorderColor = m.focusedIndicatorColor, unfocusedBorderColor = m.unfocusedIndicatorColor, disabledBorderColor = m.disabledIndicatorColor, errorBorderColor = m.errorIndicatorColor,
        focusedTextColor = m.focusedTextColor, unfocusedTextColor = m.unfocusedTextColor, disabledTextColor = m.disabledTextColor, errorTextColor = m.errorTextColor,
        focusedPlaceholderColor = m.focusedPlaceholderColor, unfocusedPlaceholderColor = m.unfocusedPlaceholderColor, disabledPlaceholderColor = m.disabledPlaceholderColor, errorPlaceholderColor = m.errorPlaceholderColor,
        focusedLabelColor = m.focusedLabelColor, unfocusedLabelColor = m.unfocusedLabelColor, disabledLabelColor = m.disabledLabelColor, errorLabelColor = m.errorLabelColor,
        focusedSupportingTextColor = m.focusedSupportingTextColor, unfocusedSupportingTextColor = m.unfocusedSupportingTextColor, disabledSupportingTextColor = m.disabledSupportingTextColor, errorSupportingTextColor = m.errorSupportingTextColor,
        caretColor = m.cursorColor, errorCaretColor = m.errorCursorColor, selectionColor = m.textSelectionColors.backgroundColor,
    )

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
        contentPadding: PaddingValues = PaddingValues(12.dp, 10.dp),
        shape: Shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
        focusedIndicatorWidth: Dp = 2.dp,
        unfocusedIndicatorWidth: Dp = 1.dp,
        placeholderStyle: TextStyle = decorationState.style,
    ) {
        val iw = if (decorationState.focused) focusedIndicatorWidth else unfocusedIndicatorWidth
        Row(modifier.background(colors.containerColor(decorationState.enabled, decorationState.focused, decorationState.isError), shape)) {
            Row(Modifier.weight(1f).fillMaxHeight().padding(contentPadding), Arrangement.spacedBy(8.dp), Alignment.CenterVertically) {
                if (label != null && labelPosition == MongolTextFieldLabelPosition.Attached) { CompositionLocalProvider(LocalContentColor provides colors.labelColor(decorationState.enabled, decorationState.focused, decorationState.isError)) { label() } }
                Column(Modifier.weight(1f).fillMaxHeight(), Arrangement.spacedBy(8.dp), Alignment.CenterHorizontally) {
                    leadingIcon?.invoke(); prefix?.invoke()
                    Box(Modifier.weight(1f), Alignment.TopCenter) {
                        if (decorationState.isEmpty && placeholder != null) { CompositionLocalProvider(LocalContentColor provides colors.placeholderColor(decorationState.enabled, decorationState.focused, decorationState.isError)) { androidx.compose.material3.ProvideTextStyle(placeholderStyle) { placeholder() } } }
                        innerTextField()
                    }
                    suffix?.invoke(); trailingIcon?.invoke()
                }
            }
            Box(Modifier.fillMaxHeight().width(iw).background(colors.borderColor(decorationState.enabled, decorationState.focused, decorationState.isError)))
        }
    }
}

@Composable
fun MongolTextField(
    state: MongolEditableState, modifier: Modifier = Modifier, style: TextStyle = TextStyle.Default, textAlign: MongolTextAlign = MongolTextAlign.TOP,
    textRuns: List<TextRun>? = null, rotateCjk: Boolean = true, enabled: Boolean = true, readOnly: Boolean = false,
    caretColor: Color = Color.Unspecified, selectionColor: Color = Color.Unspecified, keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    onTextChange: (String) -> Unit = {}, value: String? = null, onValueChange: ((String) -> Unit)? = null,
    onInputSessionReady: (MongolInputSession) -> Unit = {}, onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {},
    inputTransformation: InputTransformation? = null, lineLimits: TextFieldLineLimits = TextFieldLineLimits.Default,
    label: (@Composable () -> Unit)? = null, labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached,
    isError: Boolean = false, placeholder: (@Composable () -> Unit)? = null, placeholderStyle: TextStyle = style,
    supportingText: (@Composable () -> Unit)? = null, leadingIcon: (@Composable () -> Unit)? = null, trailingIcon: (@Composable () -> Unit)? = null,
    prefix: (@Composable () -> Unit)? = null, suffix: (@Composable () -> Unit)? = null, colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(),
    autoWidthByContent: Boolean = true,
) {
    val density = LocalDensity.current; var focused by remember { mutableStateOf(false) }; val focusRequester = remember { FocusRequester() }
    LaunchedEffect(value, state) { if (value != null && value != state.text) state.replaceText(value) }
    val isSingleLine = lineLimits == TextFieldLineLimits.SingleLine
    val minL = if (isSingleLine) 1 else (lineLimits as? TextFieldLineLimits.MultiLine)?.minHeightInLines ?: 1
    val maxL = if (isSingleLine) 1 else (lineLimits as? TextFieldLineLimits.MultiLine)?.maxHeightInLines ?: Int.MAX_VALUE
    val fs = with(density) { if (style.fontSize.isSp) style.fontSize.toPx() else 16.sp.toPx() }; val ls = (fs * 1.5f).roundToInt()
    val ds = MongolTextFieldDecorationState(state.text, state.text.isEmpty(), focused, enabled, readOnly, style.copy(colors.textColor(enabled, focused, isError)), textAlign, textRuns, rotateCjk, isError)
    val inner: @Composable () -> Unit = { MongolBasicTextField(state, Modifier.fillMaxHeight().focusRequester(focusRequester), style.copy(colors.textColor(enabled, focused, isError)), textAlign, textRuns, rotateCjk, enabled, readOnly, if (caretColor != Color.Unspecified) caretColor else colors.caretColor(isError), if (selectionColor != Color.Unspecified) selectionColor else colors.selectionColor, keyboardOptions, lineLimits, { c, p -> val n = applyInputTransformation(c, p, inputTransformation); if (isSingleLine) n.replace('\n', ' ') else n }, { n -> val f = if (isSingleLine) n.replace('\n', ' ') else n; if (f != n) state.replaceText(f); (onValueChange ?: onTextChange)(f) }, onInputSessionReady, onSelectionHandlesChanged, { focused = it }) }
    val showAboveLabel = label != null && labelPosition == MongolTextFieldLabelPosition.Above
    
    Layout(
        modifier = modifier.pointerInput(enabled, readOnly) { 
            awaitPointerEventScope { 
                while (true) { 
                    val e = awaitPointerEvent(PointerEventPass.Initial)
                    if (e.changes.any { it.changedToDown() } && enabled && !readOnly) focusRequester.requestFocus() 
                } 
            } 
        },
        content = {
            if (showAboveLabel) { CompositionLocalProvider(LocalContentColor provides colors.labelColor(enabled, focused, isError)) { label() } }
            Box { MongolTextFieldDefaults.FilledDecorationBox(ds, inner, label = label, labelPosition = labelPosition, placeholder = placeholder, leadingIcon = leadingIcon, trailingIcon = trailingIcon, prefix = prefix, suffix = suffix, colors = colors, placeholderStyle = placeholderStyle) }
            if (supportingText != null) { CompositionLocalProvider(LocalContentColor provides colors.supportingColor(enabled, focused, isError)) { supportingText() } }
        }
    ) { measurables, constraints ->
        val sp = 6.dp.roundToPx(); var idx = 0
        val lp = if (showAboveLabel) measurables[idx++].measure(constraints.copy(0, Int.MAX_VALUE, 0, Int.MAX_VALUE)) else null
        val fm = measurables[idx++]
        val sp_p = if (supportingText != null) measurables[idx++].measure(constraints.copy(0, Int.MAX_VALUE, 0, Int.MAX_VALUE)) else null
        val nw = (lp?.width ?: 0) + (if (lp != null) sp else 0) + (sp_p?.width ?: 0) + (if (sp_p != null) sp else 0)
        val amw = if (constraints.maxWidth == Int.MAX_VALUE) Int.MAX_VALUE else max(0, constraints.maxWidth - nw)
        val iw = fm.minIntrinsicWidth(constraints.maxHeight); val minW = minL * ls + 32.dp.roundToPx(); val maxW = if (maxL == Int.MAX_VALUE) amw else maxL * ls + 32.dp.roundToPx()
        val tw = if (autoWidthByContent) { val st = if (iw <= 0) minW else ((iw + ls - 1) / ls) * ls; st.coerceIn(minW, max(minW, maxW)) } else amw
        val fp = fm.measure(constraints.copy(tw.coerceAtMost(amw), tw.coerceAtMost(amw), 0))
        val th = max(max(lp?.height ?: 0, fp.height), sp_p?.height ?: 0)
        val totalW = (lp?.width ?: 0) + (if (lp != null) sp else 0) + fp.width + (if (sp_p != null) sp + sp_p.width else 0)
        layout(totalW.coerceIn(constraints.minWidth, constraints.maxWidth), th.coerceIn(constraints.minHeight, constraints.maxHeight)) {
            var x = 0; lp?.let { it.placeRelative(x, (th - it.height)/2); x += it.width + sp }; fp.placeRelative(x, (th - fp.height)/2); x += fp.width
            sp_p?.let { it.placeRelative(x + sp, (th - it.height)/2) }
        }
    }
}

@Composable
fun MongolTextField(value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, style: TextStyle = TextStyle.Default, textAlign: MongolTextAlign = MongolTextAlign.TOP, textRuns: List<TextRun>? = null, rotateCjk: Boolean = true, enabled: Boolean = true, readOnly: Boolean = false, caretColor: Color = Color.Unspecified, selectionColor: Color = Color(0x552196F3), keyboardOptions: KeyboardOptions = KeyboardOptions.Default, onInputSessionReady: (MongolInputSession) -> Unit = {}, onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {}, inputTransformation: InputTransformation? = null, lineLimits: TextFieldLineLimits = TextFieldLineLimits.Default, label: (@Composable () -> Unit)? = null, labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached, isError: Boolean = false, placeholder: (@Composable () -> Unit)? = null, placeholderStyle: TextStyle = style, supportingText: (@Composable () -> Unit)? = null, leadingIcon: (@Composable () -> Unit)? = null, trailingIcon: (@Composable () -> Unit)? = null, prefix: (@Composable () -> Unit)? = null, suffix: (@Composable () -> Unit)? = null, colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(), autoWidthByContent: Boolean = true) {
    val state = rememberMongolEditableState(initialText = value)
    MongolTextField(state, modifier, style, textAlign, textRuns, rotateCjk, enabled, readOnly, caretColor, selectionColor, keyboardOptions, {}, value, onValueChange, onInputSessionReady, onSelectionHandlesChanged, inputTransformation, lineLimits, label, labelPosition, isError, placeholder, placeholderStyle, supportingText, leadingIcon, trailingIcon, prefix, suffix, colors, autoWidthByContent)
}

@Composable
fun MongolOutlinedTextField(value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, style: TextStyle = TextStyle.Default, textAlign: MongolTextAlign = MongolTextAlign.TOP, textRuns: List<TextRun>? = null, rotateCjk: Boolean = true, enabled: Boolean = true, readOnly: Boolean = false, caretColor: Color = Color.Unspecified, selectionColor: Color = Color(0x552196F3), keyboardOptions: KeyboardOptions = KeyboardOptions.Default, onInputSessionReady: (MongolInputSession) -> Unit = {}, onSelectionHandlesChanged: (MongolSelectionHandlesState) -> Unit = {}, inputTransformation: InputTransformation? = null, lineLimits: TextFieldLineLimits = TextFieldLineLimits.Default, label: (@Composable () -> Unit)? = null, labelPosition: MongolTextFieldLabelPosition = MongolTextFieldLabelPosition.Attached, isError: Boolean = false, placeholder: (@Composable () -> Unit)? = null, placeholderStyle: TextStyle = style, supportingText: (@Composable () -> Unit)? = null, leadingIcon: (@Composable () -> Unit)? = null, trailingIcon: (@Composable () -> Unit)? = null, prefix: (@Composable () -> Unit)? = null, suffix: (@Composable () -> Unit)? = null, colors: MongolTextFieldColors = MongolTextFieldDefaults.colors(), autoWidthByContent: Boolean = true) {
    val state = rememberMongolEditableState(initialText = value)
    MongolTextField(state, modifier, style, textAlign, textRuns, rotateCjk, enabled, readOnly, caretColor, selectionColor, keyboardOptions, {}, value, onValueChange, onInputSessionReady, onSelectionHandlesChanged, inputTransformation, lineLimits, label, labelPosition, isError, placeholder, placeholderStyle, supportingText, leadingIcon, trailingIcon, prefix, suffix, colors, autoWidthByContent)
}
