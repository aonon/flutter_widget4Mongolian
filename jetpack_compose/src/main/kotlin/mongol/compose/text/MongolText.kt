package mongol.compose.text

import androidx.compose.foundation.ScrollState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.TextRun

/**
 * Simple vertical Mongolian text composable.
 *
 * This mirrors Flutter's MongolText and delegates to MongolRichText.
 */
@Composable
fun MongolText(
    text: String,
    modifier: Modifier = Modifier,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    maxLines: Int? = null,
    textRuns: List<TextRun>? = null,
    rotateCjk: Boolean = true,
    horizontalScrollState: ScrollState? = null,
    horizontalScrollEnabled: Boolean = false,
    style: TextStyle = TextStyle.Default,
    debugColor: Color = Color(0xFF3A7D44),
    debugDrawBoxes: Boolean = false,
) {
    MongolRichText(
        text = text,
        modifier = modifier,
        textAlign = textAlign,
        maxLines = maxLines,
        textRuns = textRuns,
        rotateCjk = rotateCjk,
        horizontalScrollState = horizontalScrollState,
        horizontalScrollEnabled = horizontalScrollEnabled,
        style = style,
        debugColor = debugColor,
        debugDrawBoxes = debugDrawBoxes,
    )
}
