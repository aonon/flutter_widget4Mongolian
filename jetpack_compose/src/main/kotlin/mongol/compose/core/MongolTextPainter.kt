package mongol.compose.core

/**
 * Core painter facade for Mongolian vertical text.
 *
 * This class mirrors the responsibility of Flutter's MongolTextPainter while
 * staying UI-framework agnostic at this stage.
 */
class MongolTextPainter(
    text: String,
    textRuns: List<TextRun>? = null,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    maxLines: Int? = null,
    private val rotateCjk: Boolean = true,
    private val runMeasurer: TextRunMeasurer? = null,
) {
    companion object {
        fun computeHeight(
            text: String,
            textRuns: List<TextRun>? = null,
            textAlign: MongolTextAlign = MongolTextAlign.TOP,
            maxLines: Int? = null,
            rotateCjk: Boolean = true,
            minHeight: Float = 0f,
            maxHeight: Float,
            runMeasurer: TextRunMeasurer? = null,
        ): Float {
            val painter = MongolTextPainter(
                text = text,
                textRuns = textRuns,
                textAlign = textAlign,
                maxLines = maxLines,
                rotateCjk = rotateCjk,
                runMeasurer = runMeasurer,
            )
            return try {
                painter.layout(minHeight = minHeight, maxHeight = maxHeight)
                painter.height
            } finally {
                painter.dispose()
            }
        }

        fun computeMaxIntrinsicHeight(
            text: String,
            textRuns: List<TextRun>? = null,
            textAlign: MongolTextAlign = MongolTextAlign.TOP,
            maxLines: Int? = null,
            rotateCjk: Boolean = true,
            minHeight: Float = 0f,
            maxHeight: Float,
            runMeasurer: TextRunMeasurer? = null,
        ): Float {
            val painter = MongolTextPainter(
                text = text,
                textRuns = textRuns,
                textAlign = textAlign,
                maxLines = maxLines,
                rotateCjk = rotateCjk,
                runMeasurer = runMeasurer,
            )
            return try {
                painter.layout(minHeight = minHeight, maxHeight = maxHeight)
                painter.maxIntrinsicLineExtent
            } finally {
                painter.dispose()
            }
        }
    }

    private var _text: String = text
    var text: String
        get() = _text
        set(value) {
            if (_text == value) return
            _text = value
            _textRuns = normalizeRuns(_textRuns, value)
            markNeedsLayout()
        }

    private var _textRuns: List<TextRun> = normalizeRuns(textRuns, text)
    var textRuns: List<TextRun>
        get() = _textRuns
        set(value) {
            val normalized = normalizeRuns(value, _text)
            if (_textRuns == normalized) return
            _textRuns = normalized
            markNeedsLayout()
        }

    private var _textAlign: MongolTextAlign = textAlign
    var textAlign: MongolTextAlign
        get() = _textAlign
        set(value) {
            if (_textAlign == value) return
            _textAlign = value
            markNeedsLayout()
        }

    private var _maxLines: Int? = maxLines
    var maxLines: Int?
        get() = _maxLines
        set(value) {
            if (_maxLines == value) return
            _maxLines = value
            markNeedsLayout()
        }

    private var paragraph: MongolParagraph = buildParagraph()
    private var needsLayout: Boolean = true
    private var inputHeight: Float = Float.NaN
    private var disposed: Boolean = false

    private fun normalizeRuns(runs: List<TextRun>?, text: String): List<TextRun> {
        if (text.isEmpty()) return emptyList()
        if (runs.isNullOrEmpty()) {
            return buildAutoRuns(text)
        }

        return runs.mapNotNull { run ->
            val start = run.start.coerceIn(0, text.length)
            val end = run.end.coerceIn(0, text.length)
            if (start >= end) {
                null
            } else {
                run.copy(start = start, end = end)
            }
        }.sortedBy { it.start }
    }

    private fun buildAutoRuns(text: String): List<TextRun> {
        if (text.isEmpty()) return emptyList()

        // isSolo: this segment must NOT be merged with its neighbors.
        // Used for ideographic (CJK/emoji) characters when rotateCjk=false —
        // they are not cursive so they can wrap at every character boundary,
        // unlike Mongolian which is cursive and must stay in one run per word.
        data class Segment(
            val start: Int,
            val end: Int,
            val isRotatable: Boolean,
            val isSolo: Boolean = false,
        ) {
            val textRangeLength: Int get() = end - start
        }

        fun isBreakCluster(start: Int, end: Int): Boolean {
            if (start >= end || end - start > 1) return false
            val ch = text[start]
            return ch == ' ' || ch == '\n'
        }

        // True if ANY code point in this cluster is inherently ideographic/emoji,
        // regardless of the rotateCjk flag.
        fun isIdeographicCluster(start: Int, end: Int): Boolean {
            if (start >= end) return false
            var cursor = start
            while (cursor < end) {
                val codePoint = Character.codePointAt(text, cursor)
                if (CodePointLists.isRotatedRunCodePoint(codePoint)) return true
                cursor += Character.charCount(codePoint)
            }
            return false
        }

        fun isRotatableCluster(start: Int, end: Int): Boolean {
            if (start >= end) return false
            var cursor = start
            while (cursor < end) {
                val codePoint = Character.codePointAt(text, cursor)
                if (CodePointLists.isEmoji(codePoint)) {
                    return true
                }
                if (rotateCjk && CodePointLists.isRotatedRunCodePoint(codePoint)) {
                    return true
                }
                cursor += Character.charCount(codePoint)
            }
            return false
        }

        fun startsWithBreak(segment: Segment): Boolean {
            return segment.textRangeLength > 0 && isBreakCluster(segment.start, segment.end)
        }

        fun endsWithBreak(segment: Segment): Boolean {
            return segment.textRangeLength > 0 && isBreakCluster(segment.start, segment.end)
        }

        val rawSegments = mutableListOf<Segment>()
        val clusters = mutableListOf<Segment>()
        MongolTextTools.forEachGraphemeCluster(text) { clusterStart, clusterEnd ->
            clusters += Segment(
                start = clusterStart,
                end = clusterEnd,
                isRotatable = isRotatableCluster(clusterStart, clusterEnd),
                isSolo = !isRotatableCluster(clusterStart, clusterEnd) &&
                    isIdeographicCluster(clusterStart, clusterEnd),
            )
        }

        var clusterIndex = 0
        while (clusterIndex < clusters.size) {
            val cluster = clusters[clusterIndex]

            if (isBreakCluster(cluster.start, cluster.end)) {
                rawSegments += cluster.copy(isRotatable = false, isSolo = false)
                clusterIndex += 1
                continue
            }

            if (cluster.isRotatable) {
                rawSegments += cluster
                clusterIndex += 1
                continue
            }

            // CJK/emoji with rotateCjk=false: keep each character as its own segment
            // so it can wrap independently (they are not cursive/connected script).
            if (cluster.isSolo) {
                rawSegments += cluster
                clusterIndex += 1
                continue
            }

            // Cursive scripts (Mongolian) and Latin words: merge consecutive
            // non-rotatable, non-solo, non-break clusters into one word run.
            val segmentStart = cluster.start
            var segmentEnd = cluster.end
            clusterIndex += 1
            while (clusterIndex < clusters.size) {
                val nextCluster = clusters[clusterIndex]
                if (isBreakCluster(nextCluster.start, nextCluster.end) ||
                    nextCluster.isRotatable ||
                    nextCluster.isSolo) {
                    break
                }
                segmentEnd = nextCluster.end
                clusterIndex += 1
            }
            rawSegments += Segment(segmentStart, segmentEnd, false)
        }

        val mergedRuns = mutableListOf<TextRun>()
        var pendingStart: Int? = null
        var pendingEnd: Int? = null

        fun flushPending() {
            val start = pendingStart ?: return
            val end = pendingEnd ?: return
            if (start < end) {
                mergedRuns += TextRun(
                    start = start,
                    end = end,
                    isRotated = false,
                    runId = mergedRuns.size,
                )
            }
            pendingStart = null
            pendingEnd = null
        }

        for ((segmentIndex, segment) in rawSegments.withIndex()) {
            if (segment.isRotatable) {
                flushPending()
                mergedRuns += TextRun(
                    start = segment.start,
                    end = segment.end,
                    isRotated = true,
                    runId = mergedRuns.size,
                )
                continue
            }

            // Solo ideographic (CJK/emoji when rotateCjk=false): flush any
            // pending cursive run and emit this character as its own run.
            if (segment.isSolo) {
                flushPending()
                mergedRuns += TextRun(
                    start = segment.start,
                    end = segment.end,
                    isRotated = false,
                    runId = mergedRuns.size,
                )
                continue
            }

            if (pendingStart == null) {
                pendingStart = segment.start
            }
            pendingEnd = segment.end

            val nextSegment = rawSegments.getOrNull(segmentIndex + 1)
            val keepMerging = !endsWithBreak(segment) &&
                nextSegment != null &&
                !nextSegment.isRotatable &&
                !nextSegment.isSolo &&
                !startsWithBreak(nextSegment)

            if (!keepMerging) {
                flushPending()
            }
        }

        flushPending()
        return mergedRuns
    }

    private fun buildParagraph(): MongolParagraph {
        return MongolParagraph(
            runs = _textRuns,
            text = _text,
            maxLines = _maxLines,
            textAlign = _textAlign,
            runMeasurer = runMeasurer,
        )
    }

    val debugDisposed: Boolean
        get() = disposed

    val minIntrinsicLineExtent: Float
        get() = paragraph.minIntrinsicHeight

    val maxIntrinsicLineExtent: Float
        get() = paragraph.maxIntrinsicHeight

    val width: Float
        get() = paragraph.width

    val height: Float
        get() = paragraph.height

    val longestLine: Float
        get() = paragraph.longestLine

    val didExceedMaxLines: Boolean
        get() = paragraph.didExceedMaxLines

    fun layout(minHeight: Float = 0f, maxHeight: Float) {
        check(!disposed) { "MongolTextPainter is disposed." }
        val targetHeight = maxOf(minHeight, maxHeight)
        if (!needsLayout && inputHeight == targetHeight) {
            return
        }
        if (needsLayout) {
            paragraph.dispose()
            paragraph = buildParagraph()
        }
        paragraph.layout(MongolParagraphConstraints(height = targetHeight))
        inputHeight = targetHeight
        needsLayout = false
    }

    fun markNeedsLayout() {
        check(!disposed) { "MongolTextPainter is disposed." }
        needsLayout = true
        inputHeight = Float.NaN
    }

    fun getPositionForOffset(offset: Offset): TextPosition {
        check(!disposed) { "MongolTextPainter is disposed." }
        return paragraph.getPositionForOffset(offset)
    }

    fun getOffsetForCaret(position: TextPosition, caretPrototype: Rect): Offset {
        check(!disposed) { "MongolTextPainter is disposed." }
        val base = paragraph.getOffsetForCaret(position)
        return Offset(base.x + caretPrototype.left, base.y + caretPrototype.top)
    }

    fun getOffsetForCaret(position: TextPosition): Offset {
        check(!disposed) { "MongolTextPainter is disposed." }
        return paragraph.getOffsetForCaret(position)
    }

    fun getWordBoundary(position: TextPosition): TextRange {
        check(!disposed) { "MongolTextPainter is disposed." }
        return paragraph.getWordBoundary(position)
    }

    fun getLineBoundary(position: TextPosition): TextRange {
        check(!disposed) { "MongolTextPainter is disposed." }
        return paragraph.getLineBoundary(position)
    }

    fun computeLineMetrics(): List<MongolLineMetrics> {
        check(!disposed) { "MongolTextPainter is disposed." }
        return paragraph.computeLineMetrics()
    }

    fun getBoxesForRange(start: Int, end: Int): List<Rect> {
        check(!disposed) { "MongolTextPainter is disposed." }
        return paragraph.getBoxesForRange(start, end)
    }

    fun dispose() {
        if (disposed) return
        paragraph.dispose()
        disposed = true
        needsLayout = true
        inputHeight = Float.NaN
    }
}
