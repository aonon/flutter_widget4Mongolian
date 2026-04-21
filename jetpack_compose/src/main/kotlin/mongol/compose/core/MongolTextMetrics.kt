package mongol.compose.core

import kotlin.math.max
import kotlin.math.min

/**
 * Base type for caret metrics.
 */
sealed interface CaretMetrics

/**
 * Caret metrics for non-empty lines.
 */
data class LineCaretMetrics(
    val offset: Offset,
    val fullWidth: Float,
) : CaretMetrics

/**
 * Caret metrics for empty lines.
 */
data class EmptyLineCaretMetrics(
    val lineHorizontalOffset: Float,
) : CaretMetrics

/**
 * Calculates caret metrics for a text position.
 *
 * This is a direct Kotlin adaptation of Flutter's CaretMetricsCalculator from:
 * lib/src/base/mongol_text_metrics.dart
 */
class CaretMetricsCalculator {
    private companion object {
        const val ZERO_WIDTH_JOINER_CODE_UNIT = 0x200d
        const val NEWLINE_CODE_UNIT = 0x0A
        val EMPTY_CARET_METRICS = EmptyLineCaretMetrics(lineHorizontalOffset = 0f)
    }

    private var cachedCaretMetrics: CaretMetrics = EMPTY_CARET_METRICS

    private var lastQueriedCaretPosition: TextPosition? = null
    private var lastQueriedPlainText: String? = null
    private var lastQueriedParagraph: ParagraphBoxProvider? = null

    private fun canUseCached(
        position: TextPosition,
        plainText: String,
        paragraph: ParagraphBoxProvider,
    ): Boolean {
        return position == lastQueriedCaretPosition && plainText === lastQueriedPlainText && paragraph === lastQueriedParagraph
    }

    private fun cacheAndReturn(
        position: TextPosition,
        plainText: String,
        paragraph: ParagraphBoxProvider,
        metrics: CaretMetrics,
    ): CaretMetrics {
        lastQueriedCaretPosition = position
        lastQueriedPlainText = plainText
        lastQueriedParagraph = paragraph
        cachedCaretMetrics = metrics
        return metrics
    }

    fun compute(
        position: TextPosition,
        plainText: String,
        paragraph: ParagraphBoxProvider,
    ): CaretMetrics {
        if (canUseCached(position, plainText, paragraph)) {
            return cachedCaretMetrics
        }

        val offset = position.offset
        val plainTextLength = plainText.length
        if (offset < 0 || offset > plainTextLength || plainTextLength == 0) {
            return cacheAndReturn(position, plainText, paragraph, EMPTY_CARET_METRICS)
        }

        val metrics = when (position.affinity) {
            TextAffinity.UPSTREAM -> {
                getMetricsFromUpstream(offset, plainText, paragraph) ?: getMetricsFromDownstream(
                    offset,
                    plainText,
                    paragraph
                )
            }

            TextAffinity.DOWNSTREAM -> {
                getMetricsFromDownstream(offset, plainText, paragraph) ?: getMetricsFromUpstream(
                    offset,
                    plainText,
                    paragraph
                )
            }
        }

        return cacheAndReturn(position, plainText, paragraph, metrics ?: EMPTY_CARET_METRICS)
    }

    private fun getMetricsFromUpstream(
        offset: Int,
        plainText: String,
        paragraph: ParagraphBoxProvider,
    ): CaretMetrics? {
        val plainTextLength = plainText.length
        if (plainTextLength == 0 || offset < 0 || offset > plainTextLength) {
            return null
        }

        val safeOffset = offset.coerceIn(0, plainTextLength)
        val prevCodeUnit = plainText[max(0, safeOffset - 1)].code
        val nextCodeUnit = plainText.getOrNull(safeOffset)?.code

        val needsSearch = needsGraphemeExtendedSearch(prevCodeUnit, nextCodeUnit)

        val boxes = findBoxesUpstream(
            paragraph = paragraph,
            offset = safeOffset,
            plainTextLength = plainTextLength,
            needsSearch = needsSearch,
            stopAtNewline = prevCodeUnit == NEWLINE_CODE_UNIT,
        )
        if (boxes.isEmpty()) return null

        val box = boxes.last()
        return if (prevCodeUnit == NEWLINE_CODE_UNIT) {
            EmptyLineCaretMetrics(lineHorizontalOffset = box.right)
        } else {
            LineCaretMetrics(
                offset = Offset(x = box.left, y = box.bottom),
                fullWidth = box.right - box.left,
            )
        }
    }

    private fun getMetricsFromDownstream(
        offset: Int,
        plainText: String,
        paragraph: ParagraphBoxProvider,
    ): CaretMetrics? {
        val plainTextLength = plainText.length
        if (plainTextLength == 0 || offset < 0 || offset > plainTextLength) {
            return null
        }

        val safeOffset = offset.coerceIn(0, plainTextLength)
        val nextCodeUnit = plainText[min(safeOffset, plainTextLength - 1)].code

        val needsSearch = needsGraphemeExtendedSearch(nextCodeUnit, null)
        val boxes = findBoxesDownstream(
            paragraph = paragraph,
            offset = safeOffset,
            plainTextLength = plainTextLength,
            needsSearch = needsSearch,
        )

        if (boxes.isEmpty()) return null

        val box = boxes.first()
        return LineCaretMetrics(
            offset = Offset(x = box.left, y = box.top),
            fullWidth = box.right - box.left,
        )
    }

    private fun findBoxesUpstream(
        paragraph: ParagraphBoxProvider,
        offset: Int,
        plainTextLength: Int,
        needsSearch: Boolean,
        stopAtNewline: Boolean,
    ): List<Rect> {
        var graphemeLength = if (needsSearch) 2 else 1

        while (true) {
            val rangeStart = max(0, offset - graphemeLength)
            val boxes = paragraph.getBoxesForRange(rangeStart, offset)
            if (boxes.isNotEmpty()) {
                return boxes
            }

            if (!needsSearch || stopAtNewline || rangeStart == 0) {
                return emptyList()
            }

            val nextLength = min(plainTextLength, graphemeLength * 2)
            if (nextLength == graphemeLength) {
                return emptyList()
            }
            graphemeLength = nextLength
        }
    }

    private fun findBoxesDownstream(
        paragraph: ParagraphBoxProvider,
        offset: Int,
        plainTextLength: Int,
        needsSearch: Boolean,
    ): List<Rect> {
        var graphemeLength = if (needsSearch) 2 else 1
        val maxSearchEnd = plainTextLength shl 1

        while (true) {
            val rangeEnd = offset + graphemeLength
            val boxes = paragraph.getBoxesForRange(offset, rangeEnd)
            if (boxes.isNotEmpty()) {
                return boxes
            }

            if (!needsSearch || rangeEnd >= maxSearchEnd) {
                return emptyList()
            }

            val nextLength = graphemeLength * 2
            if (nextLength == graphemeLength) {
                return emptyList()
            }
            graphemeLength = nextLength
        }
    }

    private fun needsGraphemeExtendedSearch(codeUnit: Int, codeUnitAfter: Int?): Boolean {
        return MongolTextTools.isHighSurrogate(codeUnit) || MongolTextTools.isLowSurrogate(codeUnit) || codeUnitAfter == ZERO_WIDTH_JOINER_CODE_UNIT || MongolTextTools.isUnicodeDirectionality(
            codeUnit
        )
    }
}
