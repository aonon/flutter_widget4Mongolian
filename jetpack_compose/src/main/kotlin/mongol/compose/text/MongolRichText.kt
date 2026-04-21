package mongol.compose.text

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import mongol.compose.core.MongolTextAlign
import mongol.compose.core.MongolTextPainter
import mongol.compose.core.MongolTextTools
import mongol.compose.core.RunMetrics
import mongol.compose.core.TextRun
import mongol.compose.core.TextRunMeasurer
import mongol.compose.core.VerticalGlyphPlacementPolicy
import mongol.compose.layout.MongolTextMeasuredLayout

/**
 * Compose entry for vertical Mongolian rich text.
 *
 * Current stage:
 * - Uses core MongolTextPainter for layout.
 * - Draws glyphs via TextMeasurer, aligned to painter-computed boxes.
 */
@Composable
fun MongolRichText(
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
        text = AnnotatedString(text),
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

@Composable
fun MongolRichText(
    text: AnnotatedString,
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
    val plainText = text.text
    val textMeasurer = rememberTextMeasurer()
    val runMeasurer = remember(textMeasurer, style, text) {
        object : TextRunMeasurer {
            override fun measureRun(text: String, isRotated: Boolean): RunMetrics {
                return measureAnnotatedRun(
                    segment = AnnotatedString(text),
                    textMeasurer = textMeasurer,
                    style = style,
                )
            }

            override fun measureRunRange(
                fullText: String,
                start: Int,
                end: Int,
                isRotated: Boolean,
            ): RunMetrics {
                if (start >= end || start < 0 || end > text.length) {
                    return measureRun("", isRotated)
                }
                return measureAnnotatedRun(
                    segment = text.subSequence(start, end),
                    textMeasurer = textMeasurer,
                    style = style,
                )
            }
        }
    }

    val painter = remember(plainText, textAlign, maxLines, textRuns, rotateCjk, runMeasurer) {
        MongolTextPainter(
            text = plainText,
            textRuns = textRuns,
            textAlign = textAlign,
            maxLines = maxLines,
            rotateCjk = rotateCjk,
            runMeasurer = runMeasurer,
        )
    }
    val runLayouts = remember(text, style, painter.textRuns) {
        painter.textRuns.associateWith { run ->
            textMeasurer.measure(
                text = text.subSequence(run.start, run.end),
                style = style,
            )
        }
    }

    val effectiveHorizontalScrollState = when {
        !horizontalScrollEnabled -> null
        horizontalScrollState != null -> horizontalScrollState
        else -> rememberScrollState()
    }

    val contentModifier = if (effectiveHorizontalScrollState != null) {
        modifier.horizontalScroll(
            state = effectiveHorizontalScrollState,
            enabled = true,
        )
    } else {
        modifier
    }

    MongolTextMeasuredLayout(
        painter = painter,
        modifier = contentModifier,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            clipRect(left = 0f, top = 0f, right = size.width, bottom = size.height) {
                for (run in painter.textRuns) {
                    if (run.start >= run.end) continue

                    if (run.isRotated) {
                        MongolTextTools.forEachGraphemeCluster(
                            plainText,
                            run.start,
                            run.end
                        ) { clusterStart, clusterEnd ->
                            val clusterText = plainText.substring(clusterStart, clusterEnd)
                            if (clusterText == "\n") {
                                return@forEachGraphemeCluster
                            }

                            val box =
                                painter.getBoxesForRange(clusterStart, clusterEnd).firstOrNull()
                            if (box == null) {
                                return@forEachGraphemeCluster
                            }

                            val codePoint = Character.codePointAt(plainText, clusterStart)
                            val glyphLayout = textMeasurer.measure(
                                text = text.subSequence(clusterStart, clusterEnd),
                                style = style,
                            )
                            with(VerticalGlyphPlacementPolicy) {
                                drawGlyphInVerticalBox(
                                    codePoint = codePoint,
                                    previousCodePoint = previousVisibleCodePoint(
                                        plainText,
                                        clusterStart
                                    ),
                                    box = box,
                                    glyphLayout = glyphLayout,
                                )
                            }

                            if (debugDrawBoxes) {
                                drawRect(
                                    color = debugColor,
                                    topLeft = Offset(box.left, box.top),
                                    size = androidx.compose.ui.geometry.Size(
                                        width = box.right - box.left,
                                        height = box.bottom - box.top,
                                    ),
                                    alpha = 0.16f,
                                )
                            }
                        }
                        continue
                    }

                    if (!painter.requiresClusterDrawing(run.start, run.end)) {
                        val runText = plainText.substring(run.start, run.end)
                        if (runText.isBlank()) {
                            continue
                        }

                        val runBoxes = painter.getBoxesForRange(run.start, run.end)
                        if (runBoxes.isEmpty()) continue

                        val left = runBoxes.minOf { it.left }
                        val top = runBoxes.minOf { it.top }
                        val right = runBoxes.maxOf { it.right }
                        val bottom = runBoxes.maxOf { it.bottom }
                        val layout = runLayouts[run] ?: continue
                        val runHeight = layout.size.height.toFloat().coerceAtLeast(1f)

                        clipRect(
                            left = left,
                            top = top,
                            right = right,
                            bottom = bottom,
                        ) {
                            withTransform({
                                translate(left = left + runHeight, top = top)
                                rotate(degrees = 90f, pivot = Offset.Zero)
                            }) {
                                drawText(
                                    textLayoutResult = layout,
                                    topLeft = Offset.Zero,
                                )
                            }
                        }

                        if (debugDrawBoxes) {
                            drawRect(
                                color = debugColor,
                                topLeft = Offset(left, top),
                                size = androidx.compose.ui.geometry.Size(
                                    width = right - left,
                                    height = bottom - top,
                                ),
                                alpha = 0.16f,
                            )
                        }
                        continue
                    }

                    MongolTextTools.forEachGraphemeCluster(
                        plainText,
                        run.start,
                        run.end
                    ) { clusterStart, clusterEnd ->
                        val clusterText = plainText.substring(clusterStart, clusterEnd)
                        if (clusterText == "\n" || clusterText.isBlank()) {
                            return@forEachGraphemeCluster
                        }

                        val box = painter.getBoxesForRange(clusterStart, clusterEnd).firstOrNull()
                            ?: return@forEachGraphemeCluster
                        val glyphLayout = textMeasurer.measure(
                            text = text.subSequence(clusterStart, clusterEnd),
                            style = style,
                        )
                        val glyphHeight = glyphLayout.size.height.toFloat().coerceAtLeast(1f)

                        clipRect(
                            left = box.left,
                            top = box.top,
                            right = box.right,
                            bottom = box.bottom,
                        ) {
                            withTransform({
                                translate(left = box.left + glyphHeight, top = box.top)
                                rotate(degrees = 90f, pivot = Offset.Zero)
                            }) {
                                drawText(
                                    textLayoutResult = glyphLayout,
                                    topLeft = Offset.Zero,
                                )
                            }
                        }

                        if (debugDrawBoxes) {
                            drawRect(
                                color = debugColor,
                                topLeft = Offset(box.left, box.top),
                                size = androidx.compose.ui.geometry.Size(
                                    width = box.right - box.left,
                                    height = box.bottom - box.top,
                                ),
                                alpha = 0.16f,
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun measureAnnotatedRun(
    segment: AnnotatedString,
    textMeasurer: androidx.compose.ui.text.TextMeasurer,
    style: TextStyle,
): RunMetrics {
    val result = textMeasurer.measure(
        text = segment,
        style = style,
    )
    val size = result.size
    val runHeight = size.height.toFloat().coerceAtLeast(1f)
    val runWidth = size.width.toFloat().coerceAtLeast(1f)

    val clusterAdvances = mutableListOf<Float>()
    MongolTextTools.forEachGraphemeCluster(segment.text) { clusterStart, clusterEnd ->
        val clusterLayout = textMeasurer.measure(
            text = segment.subSequence(clusterStart, clusterEnd),
            style = style,
        )
        clusterAdvances += clusterLayout.size.width.toFloat().coerceAtLeast(1f)
    }
    if (clusterAdvances.isEmpty()) {
        clusterAdvances += runWidth
    }

    val rawSum = clusterAdvances.sum().takeIf { it > 0f } ?: 1f
    val scale = runWidth / rawSum
    return RunMetrics(
        advance = runWidth,
        crossAxis = runHeight,
        ascent = runHeight * 0.8f,
        descent = runHeight * 0.2f,
        clusterAdvances = clusterAdvances.map { it * scale },
    )
}
