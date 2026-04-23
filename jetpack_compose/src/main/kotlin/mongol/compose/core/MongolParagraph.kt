package mongol.compose.core

import kotlin.math.abs

/**
 * Vertical text layout engine skeleton for Mongolian script.
 *
 * Mirrors the role of Flutter's MongolParagraph in:
 * lib/src/base/mongol_paragraph.dart
 *
 * Current status:
 * - Public API and cached layout fields are in place.
 * - Column breaking and glyph box extraction are staged for the next step.
 */
class MongolParagraph(
    private val runs: List<TextRun>,
    private val text: String,
    private val maxLines: Int?,
    private val textAlign: MongolTextAlign,
    private val runMeasurer: TextRunMeasurer? = null,
) : ParagraphBoxProvider {
    init {
        require(maxLines == null || maxLines > 0) { "maxLines must be null or > 0" }
    }

    private data class LayoutColumn(
        val index: Int,
        val left: Float,
        val glyphIndices: MutableList<Int>,
        var usedAdvance: Float = 0f,
        var maxCrossAxis: Float = 0f,
        var maxAscent: Float = 0f,
        var maxDescent: Float = 0f,
    )

    private data class ColumnContentBounds(
        val top: Float,
        val bottom: Float,
    )

    private val columns: MutableList<LayoutColumn> = mutableListOf()
    private val glyphBoxesByIndex: Array<Rect?> = arrayOfNulls(text.length)
    private val glyphMetricsByIndex: Array<GlyphMetrics?> = arrayOfNulls(text.length)
    private val forcedBreakRanges: MutableSet<TextRange> = linkedSetOf()

    // Deterministic fallback metrics before Compose TextMeasurer integration.
    private val columnWidthPx: Float = 18f
    private val glyphAdvancePx: Float = 18f
    private var disposed: Boolean = false

    var width: Float = 0f
        private set

    var height: Float = 0f
        private set

    var longestLine: Float = 0f
        private set

    var minIntrinsicHeight: Float = 0f
        private set

    var maxIntrinsicHeight: Float = Float.POSITIVE_INFINITY
        private set

    var didExceedMaxLines: Boolean = false
        private set

    private var lastLayoutSignatureHash: Int? = null

    val debugDisposed: Boolean
        get() = disposed

    private fun computeLayoutSignature(height: Float): Int {
        var result = height.toBits()
        result = 31 * result + text.hashCode()
        result = 31 * result + runs.hashCode()
        result = 31 * result + (maxLines ?: 0)
        result = 31 * result + textAlign.hashCode()
        return result
    }

    fun layout(constraints: MongolParagraphConstraints) {
        check(!disposed) { "MongolParagraph is disposed." }
        require(constraints.height.isFinite()) { "Constraint height must be finite" }
        require(constraints.height >= 0f) { "Constraint height must be >= 0" }
        val signature = computeLayoutSignature(constraints.height)
        if (lastLayoutSignatureHash == signature) {
            return
        }

        resetComputedLayout()
        computeStagedLayout(constraints.height)
        lastLayoutSignatureHash = signature
    }

    private fun resetComputedLayout() {
        columns.clear()
        glyphBoxesByIndex.fill(null)
        glyphMetricsByIndex.fill(null)
        forcedBreakRanges.clear()
        width = 0f
        height = 0f
        longestLine = 0f
        minIntrinsicHeight = 0f
        maxIntrinsicHeight = Float.POSITIVE_INFINITY
        didExceedMaxLines = false
    }

    private fun computeStagedLayout(availableHeight: Float) {
        if (text.isEmpty()) {
            height = availableHeight
            maxIntrinsicHeight = availableHeight
            return
        }

        if (availableHeight <= 0f) {
            height = availableHeight
            maxIntrinsicHeight = availableHeight
            didExceedMaxLines = true
            return
        }

        val maxColumns = maxLines ?: Int.MAX_VALUE

        var currentColumnLeft = 0f
        var currentColumn = LayoutColumn(
            index = 0,
            left = currentColumnLeft,
            glyphIndices = mutableListOf(),
        )
        columns += currentColumn

        var consumedAdvance = 0f
        var exceeded = false

        fun moveToNextColumn(): Boolean {
            val nextColumnIndex = currentColumn.index + 1
            if (nextColumnIndex >= maxColumns) {
                exceeded = true
                return false
            }
            currentColumnLeft += currentColumn.maxCrossAxis.coerceAtLeast(columnWidthPx)
            currentColumn = LayoutColumn(
                index = nextColumnIndex,
                left = currentColumnLeft,
                glyphIndices = mutableListOf(),
            )
            columns += currentColumn
            consumedAdvance = 0f
            return true
        }

        fun fallbackRunMetrics(startIndex: Int, endIndex: Int): RunMetrics {
            val clusterAdvances = mutableListOf<Float>()
            MongolTextTools.forEachGraphemeCluster(text, startIndex, endIndex) { _, _ ->
                clusterAdvances += glyphAdvancePx
            }
            if (clusterAdvances.isEmpty()) {
                clusterAdvances += glyphAdvancePx
            }
            return RunMetrics(
                advance = clusterAdvances.sum().coerceAtLeast(glyphAdvancePx),
                crossAxis = columnWidthPx,
                ascent = glyphAdvancePx * 0.8f,
                descent = glyphAdvancePx * 0.2f,
                clusterAdvances = clusterAdvances,
            )
        }

        fun placeCluster(startIndex: Int, endIndex: Int, metrics: RunMetrics) {
            if (consumedAdvance == 0f) {
                val isLeadingWhitespaceCluster = (startIndex until endIndex).all { idx ->
                    idx in text.indices && isEdgeWhitespace(text[idx])
                }
                if (isLeadingWhitespaceCluster) {
                    return
                }
            }

            if (consumedAdvance + metrics.advance > availableHeight && currentColumn.glyphIndices.isNotEmpty()) {
                if (!moveToNextColumn()) return
            }

            val left = currentColumn.left
            val top = consumedAdvance
            val rect = Rect(
                left = left,
                top = top,
                right = left + metrics.crossAxis,
                bottom = top + metrics.advance,
            )

            for (index in startIndex until endIndex) {
                glyphBoxesByIndex[index] = rect
                glyphMetricsByIndex[index] = GlyphMetrics(
                    advance = metrics.advance,
                    crossAxis = metrics.crossAxis,
                    ascent = metrics.ascent,
                    descent = metrics.descent,
                )
                currentColumn.glyphIndices += index
            }

            consumedAdvance += metrics.advance
            currentColumn.usedAdvance += metrics.advance
            currentColumn.maxCrossAxis = maxOf(currentColumn.maxCrossAxis, metrics.crossAxis)
            currentColumn.maxAscent = maxOf(currentColumn.maxAscent, metrics.ascent)
            currentColumn.maxDescent = maxOf(currentColumn.maxDescent, metrics.descent)
        }

        fun placeUnrotatedRun(startIndex: Int, endIndex: Int, metrics: RunMetrics) {
            if (startIndex >= endIndex) return
            val clusters = mutableListOf<TextRange>()
            MongolTextTools.forEachGraphemeCluster(
                text,
                startIndex,
                endIndex
            ) { clusterStart, clusterEnd ->
                clusters += TextRange(start = clusterStart, end = clusterEnd)
            }
            if (clusters.isEmpty()) return

            val spanCount = clusters.size
            val rawAdvances = if (metrics.clusterAdvances.size == spanCount) {
                metrics.clusterAdvances
            } else {
                List(spanCount) { metrics.advance / spanCount }
            }
            val rawSum = rawAdvances.sum().takeIf { it > 0f } ?: 1f
            val scale = metrics.advance / rawSum

            val isUnspacedSegment = (startIndex until endIndex).none { idx ->
                idx in text.indices && isEdgeWhitespace(text[idx])
            }
            val shouldForceBreak = isUnspacedSegment && metrics.advance > availableHeight

            if (shouldForceBreak) {
                forcedBreakRanges += TextRange(startIndex, endIndex)
                val scaledAdvances = rawAdvances.map { (it * scale).coerceAtLeast(1f) }

                // For break-all long words, start from a fresh column when possible,
                // then continue splitting before overflow.
                if (currentColumn.glyphIndices.isNotEmpty() && consumedAdvance > 0f) {
                    if (!moveToNextColumn()) return
                }

                var cursor = 0

                while (cursor < clusters.size) {
                    if (consumedAdvance >= availableHeight && currentColumn.glyphIndices.isNotEmpty()) {
                        if (!moveToNextColumn()) return
                    }

                    val room = (availableHeight - consumedAdvance).coerceAtLeast(0f)
                    var takeCount = 0
                    var chunkAdvance = 0f
                    while (cursor + takeCount < clusters.size) {
                        val nextAdvance = scaledAdvances[cursor + takeCount]
                        if (takeCount > 0 && chunkAdvance + nextAdvance > room) break
                        if (takeCount == 0 && nextAdvance > room && currentColumn.glyphIndices.isNotEmpty()) {
                            if (!moveToNextColumn()) return
                            break
                        }
                        chunkAdvance += nextAdvance
                        takeCount += 1
                        if (chunkAdvance >= room) break
                    }

                    if (takeCount == 0) {
                        val singleAdvance = scaledAdvances[cursor]
                        val firstCluster = clusters[cursor]
                        val left = currentColumn.left
                        val top = consumedAdvance
                        val rect = Rect(
                            left = left,
                            top = top,
                            right = left + metrics.crossAxis,
                            bottom = top + singleAdvance,
                        )
                        for (textIndex in firstCluster.start until firstCluster.end) {
                            glyphBoxesByIndex[textIndex] = rect
                            glyphMetricsByIndex[textIndex] = GlyphMetrics(
                                advance = singleAdvance,
                                crossAxis = metrics.crossAxis,
                                ascent = metrics.ascent,
                                descent = metrics.descent,
                            )
                            currentColumn.glyphIndices += textIndex
                        }
                        consumedAdvance += singleAdvance
                        currentColumn.usedAdvance += singleAdvance
                        currentColumn.maxCrossAxis =
                            maxOf(currentColumn.maxCrossAxis, metrics.crossAxis)
                        currentColumn.maxAscent = maxOf(currentColumn.maxAscent, metrics.ascent)
                        currentColumn.maxDescent = maxOf(currentColumn.maxDescent, metrics.descent)
                        cursor += 1
                        continue
                    }

                    val left = currentColumn.left
                    val top = consumedAdvance
                    var y = top
                    for (i in 0 until takeCount) {
                        val cluster = clusters[cursor + i]
                        val clusterAdvance = if (i == takeCount - 1) {
                            (top + chunkAdvance) - y
                        } else {
                            scaledAdvances[cursor + i]
                        }
                        val rect = Rect(
                            left = left,
                            top = y,
                            right = left + metrics.crossAxis,
                            bottom = y + clusterAdvance,
                        )
                        for (textIndex in cluster.start until cluster.end) {
                            glyphBoxesByIndex[textIndex] = rect
                            glyphMetricsByIndex[textIndex] = GlyphMetrics(
                                advance = clusterAdvance,
                                crossAxis = metrics.crossAxis,
                                ascent = metrics.ascent,
                                descent = metrics.descent,
                            )
                            currentColumn.glyphIndices += textIndex
                        }
                        y += clusterAdvance
                    }

                    consumedAdvance += chunkAdvance
                    currentColumn.usedAdvance += chunkAdvance
                    currentColumn.maxCrossAxis =
                        maxOf(currentColumn.maxCrossAxis, metrics.crossAxis)
                    currentColumn.maxAscent = maxOf(currentColumn.maxAscent, metrics.ascent)
                    currentColumn.maxDescent = maxOf(currentColumn.maxDescent, metrics.descent)
                    cursor += takeCount
                }
                return
            }

            if (consumedAdvance + metrics.advance > availableHeight && currentColumn.glyphIndices.isNotEmpty()) {
                if (!moveToNextColumn()) return
            }

            val left = currentColumn.left
            val top = consumedAdvance
            var cursorTop = top

            var firstRenderableClusterIndex = 0
            if (consumedAdvance == 0f) {
                while (firstRenderableClusterIndex < spanCount) {
                    val range = clusters[firstRenderableClusterIndex]
                    val isLeadingWhitespaceCluster = (range.start until range.end).all { idx ->
                        idx in text.indices && isEdgeWhitespace(text[idx])
                    }
                    if (!isLeadingWhitespaceCluster) break
                    firstRenderableClusterIndex += 1
                }
            }

            if (firstRenderableClusterIndex >= spanCount) {
                return
            }

            val renderedAdvances = rawAdvances
                .subList(firstRenderableClusterIndex, spanCount)
                .map { it * scale }
            val renderedAdvanceTotal = renderedAdvances.sum().coerceAtLeast(1f)
            val renderedTop = top
            val renderedBottom = top + renderedAdvanceTotal
            cursorTop = renderedTop

            for (localIndex in firstRenderableClusterIndex until spanCount) {
                val clusterRange = clusters[localIndex]
                val renderedIndex = localIndex - firstRenderableClusterIndex
                val height = if (localIndex == spanCount - 1) {
                    renderedBottom - cursorTop
                } else {
                    renderedAdvances[renderedIndex].coerceAtLeast(1f)
                }
                val rect = Rect(
                    left = left,
                    top = cursorTop,
                    right = left + metrics.crossAxis,
                    bottom = cursorTop + height,
                )
                for (textIndex in clusterRange.start until clusterRange.end) {
                    glyphBoxesByIndex[textIndex] = rect
                    glyphMetricsByIndex[textIndex] = GlyphMetrics(
                        advance = height,
                        crossAxis = metrics.crossAxis,
                        ascent = metrics.ascent,
                        descent = metrics.descent,
                    )
                    currentColumn.glyphIndices += textIndex
                }
                cursorTop += height
            }

            consumedAdvance += renderedAdvanceTotal
            currentColumn.usedAdvance += renderedAdvanceTotal
            currentColumn.maxCrossAxis = maxOf(currentColumn.maxCrossAxis, metrics.crossAxis)
            currentColumn.maxAscent = maxOf(currentColumn.maxAscent, metrics.ascent)
            currentColumn.maxDescent = maxOf(currentColumn.maxDescent, metrics.descent)
        }

        for (run in runs) {
            var segmentStart = run.start
            var cursor = run.start

            while (cursor < run.end) {
                if (text[cursor] == '\n') {
                    val segmentEnd = cursor
                    if (segmentStart < segmentEnd) {
                        if (run.isRotated) {
                            MongolTextTools.forEachGraphemeCluster(
                                text,
                                segmentStart,
                                segmentEnd
                            ) { clusterStart, clusterEnd ->
                                val clusterMetrics = runMeasurer?.measureRunRange(
                                    fullText = text,
                                    start = clusterStart,
                                    end = clusterEnd,
                                    isRotated = true,
                                )
                                    ?: fallbackRunMetrics(clusterStart, clusterEnd)
                                placeCluster(clusterStart, clusterEnd, clusterMetrics)
                            }
                        } else {
                            val runMetrics = runMeasurer?.measureRunRange(
                                fullText = text,
                                start = segmentStart,
                                end = segmentEnd,
                                isRotated = false,
                            )
                                ?: fallbackRunMetrics(segmentStart, segmentEnd)
                            placeUnrotatedRun(segmentStart, segmentEnd, runMetrics)
                        }
                    }
                    if (!moveToNextColumn()) break
                    cursor += 1
                    segmentStart = cursor
                    continue
                }
                cursor += 1
            }

            if (!exceeded && segmentStart < run.end) {
                if (run.isRotated) {
                    MongolTextTools.forEachGraphemeCluster(
                        text,
                        segmentStart,
                        run.end
                    ) { clusterStart, clusterEnd ->
                        val clusterMetrics = runMeasurer?.measureRunRange(
                            fullText = text,
                            start = clusterStart,
                            end = clusterEnd,
                            isRotated = true,
                        )
                            ?: fallbackRunMetrics(clusterStart, clusterEnd)
                        placeCluster(clusterStart, clusterEnd, clusterMetrics)
                    }
                } else {
                    val runMetrics = runMeasurer?.measureRunRange(
                        fullText = text,
                        start = segmentStart,
                        end = run.end,
                        isRotated = false,
                    )
                        ?: fallbackRunMetrics(segmentStart, run.end)
                    placeUnrotatedRun(segmentStart, run.end, runMetrics)
                }
            }

            if (exceeded) break
        }

        height = availableHeight

        if (textAlign == MongolTextAlign.JUSTIFY) {
            val lastColumnIndex = columns.lastIndex

            fun sameRect(a: Rect, b: Rect): Boolean {
                return abs(a.left - b.left) < 0.01f &&
                        abs(a.top - b.top) < 0.01f &&
                        abs(a.right - b.right) < 0.01f &&
                        abs(a.bottom - b.bottom) < 0.01f
            }

            fun isJustifyWhitespace(ch: Char): Boolean {
                return ch.isWhitespace() || ch == '\u180E' || ch == '\u202F'
            }

            fun isPunctuation(ch: Char): Boolean {
                return when (Character.getType(ch)) {
                    Character.CONNECTOR_PUNCTUATION.toInt(),
                    Character.DASH_PUNCTUATION.toInt(),
                    Character.END_PUNCTUATION.toInt(),
                    Character.FINAL_QUOTE_PUNCTUATION.toInt(),
                    Character.INITIAL_QUOTE_PUNCTUATION.toInt(),
                    Character.OTHER_PUNCTUATION.toInt(),
                    Character.START_PUNCTUATION.toInt() -> true

                    else -> false
                }
            }

            for (column in columns) {
                if (column.index == lastColumnIndex) continue
                if (column.glyphIndices.size < 2) continue

                val endExclusive = column.glyphIndices.lastOrNull()?.plus(1) ?: continue
                val hardBreak = endExclusive < text.length && text[endExclusive] == '\n'
                if (hardBreak) continue

                data class VisualGlyphGroup(
                    val indices: MutableList<Int>,
                    val rect: Rect,
                ) {
                    val firstIndex: Int get() = indices.first()
                    val lastIndex: Int get() = indices.last()
                }

                fun isWhitespaceGroup(group: VisualGlyphGroup): Boolean {
                    return group.indices.all { idx ->
                        isJustifyWhitespace(text[idx])
                    }
                }

                val groups = mutableListOf<VisualGlyphGroup>()
                for (index in column.glyphIndices) {
                    val rect = glyphBoxesByIndex[index] ?: continue
                    val current = groups.lastOrNull()
                    if (current != null && sameRect(current.rect, rect)) {
                        current.indices += index
                    } else {
                        groups += VisualGlyphGroup(
                            indices = mutableListOf(index),
                            rect = rect,
                        )
                    }
                }

                if (groups.size < 2) continue

                val lastContentGroupIndex = groups.indexOfLast { !isWhitespaceGroup(it) }
                if (lastContentGroupIndex < 0) continue

                val contentAdvance = groups[lastContentGroupIndex].rect.bottom
                val extraSpace = (height - contentAdvance).coerceAtLeast(0f)
                if (extraSpace <= 0f) continue

                val allGapIndices = if (lastContentGroupIndex <= 0) {
                    emptyList()
                } else {
                    (0 until lastContentGroupIndex).toList()
                }

                val avgAdvance = (column.usedAdvance / groups.size).coerceAtLeast(1f)
                val gapAlloc = DoubleArray(allGapIndices.size)
                val gapCaps = DoubleArray(allGapIndices.size)
                val gapWeights = DoubleArray(allGapIndices.size)

                for ((k, gapIndex) in allGapIndices.withIndex()) {
                    val leftChar = text[groups[gapIndex].lastIndex]
                    val rightChar = text[groups[gapIndex + 1].firstIndex]
                    val hasWhitespace =
                        isJustifyWhitespace(leftChar) || isJustifyWhitespace(rightChar)
                    val hasPunctuation = isPunctuation(leftChar) || isPunctuation(rightChar)

                    gapWeights[k] = when {
                        hasWhitespace -> 2.4
                        hasPunctuation -> 0.55
                        else -> 1.0
                    }

                    gapCaps[k] = when {
                        hasWhitespace -> (avgAdvance * 2.4f).toDouble()
                        hasPunctuation -> (avgAdvance * 0.8f).toDouble()
                        else -> (avgAdvance * 1.4f).toDouble()
                    }
                }

                val shouldDistributeGaps = allGapIndices.isNotEmpty()

                if (shouldDistributeGaps) {
                    var remaining = extraSpace.toDouble()
                    val active =
                        allGapIndices.indices.filter { gapWeights[it] > 0.0 }.toMutableSet()

                    // First pass: weighted distribution with soft caps.
                    while (remaining > 0.01 && active.isNotEmpty()) {
                        val weightSum = active.sumOf { gapWeights[it] }
                        if (weightSum <= 0.0) break

                        var distributed = 0.0
                        val saturated = mutableListOf<Int>()
                        for (i in active) {
                            val quota = remaining * (gapWeights[i] / weightSum)
                            val room = (gapCaps[i] - gapAlloc[i]).coerceAtLeast(0.0)
                            val delta = minOf(quota, room)
                            gapAlloc[i] += delta
                            distributed += delta
                            if (room - delta <= 0.01) {
                                saturated += i
                            }
                        }
                        remaining -= distributed
                        for (i in saturated) {
                            active.remove(i)
                        }
                        if (distributed <= 0.0) break
                    }

                    // Second pass: if all caps are hit, spread remainder evenly.
                    if (remaining > 0.01) {
                        val even = remaining / allGapIndices.size.toDouble()
                        for (i in allGapIndices.indices) {
                            gapAlloc[i] += even
                        }
                    }
                }

                val groupShifts = DoubleArray(groups.size)
                var shift = 0.0
                groups.forEachIndexed { visualIndex, group ->
                    if (visualIndex > 0 && visualIndex - 1 < gapAlloc.size) {
                        shift += gapAlloc[visualIndex - 1]
                    }
                    groupShifts[visualIndex] = if (visualIndex <= lastContentGroupIndex) {
                        shift
                    } else {
                        extraSpace.toDouble()
                    }
                }

                groups.forEachIndexed { visualIndex, group ->
                    val adjustedRect =
                        if (visualIndex > lastContentGroupIndex && isWhitespaceGroup(group)) {
                            Rect(
                                left = group.rect.left,
                                top = (height - 1f).coerceAtLeast(0f),
                                right = group.rect.right,
                                bottom = height,
                            )
                        } else {
                            val dy = groupShifts[visualIndex].toFloat()
                            Rect(
                                left = group.rect.left,
                                top = group.rect.top + dy,
                                right = group.rect.right,
                                bottom = group.rect.bottom + dy,
                            )
                        }
                    for (index in group.indices) {
                        glyphBoxesByIndex[index] = adjustedRect
                    }
                }

                // Final normalize: force the last visible content glyph in this column
                // to sit exactly on the bottom edge.
                val contentBottom =
                    glyphBoxesByIndex[groups[lastContentGroupIndex].lastIndex]?.bottom ?: continue
                val normalizeDy = height - contentBottom
                if (abs(normalizeDy) > 0.01f) {
                    for (visualIndex in 0..lastContentGroupIndex) {
                        for (index in groups[visualIndex].indices) {
                            val rect = glyphBoxesByIndex[index] ?: continue
                            glyphBoxesByIndex[index] = Rect(
                                left = rect.left,
                                top = rect.top + normalizeDy,
                                right = rect.right,
                                bottom = rect.bottom + normalizeDy,
                            )
                        }
                    }
                }

                column.usedAdvance = height
            }
        }

        // Apply alignment to rendered glyph boxes so visual output and hit-testing
        // use the same coordinate space.
        for (column in columns) {
            val dy = alignmentOffsetForColumn(column)
            if (abs(dy) <= 0.01f || column.glyphIndices.isEmpty()) continue
            for (index in column.glyphIndices) {
                val rect = glyphBoxesByIndex[index] ?: continue
                glyphBoxesByIndex[index] = Rect(
                    left = rect.left,
                    top = rect.top + dy,
                    right = rect.right,
                    bottom = rect.bottom + dy,
                )
            }
        }

        didExceedMaxLines = exceeded

        width = columns.sumOf { it.maxCrossAxis.toDouble() }.toFloat()
        longestLine = columns.maxOfOrNull { it.usedAdvance } ?: 0f
        minIntrinsicHeight =
            glyphMetricsByIndex.maxOfOrNull { it?.advance ?: 0f }?.takeIf { it > 0f }
                ?: glyphAdvancePx
        maxIntrinsicHeight = availableHeight
    }

    private fun isEdgeWhitespace(ch: Char): Boolean {
        return ch.isWhitespace() || ch == '\u180E' || ch == '\u202F'
    }

    private fun contentBoundsForColumn(column: LayoutColumn): ColumnContentBounds? {
        if (column.glyphIndices.isEmpty()) return null

        val firstContentIndex = column.glyphIndices.firstOrNull { idx ->
            idx in text.indices && !isEdgeWhitespace(text[idx])
        } ?: return null

        // Keep trailing whitespace in the alignment height computation.
        val lastLayoutIndex = column.glyphIndices.lastOrNull { idx ->
            idx in text.indices
        } ?: return null

        val firstRect = glyphBoxesByIndex[firstContentIndex] ?: return null
        val lastRect = glyphBoxesByIndex[lastLayoutIndex] ?: return null
        return ColumnContentBounds(
            top = firstRect.top,
            bottom = lastRect.bottom,
        )
    }

    private fun alignmentOffsetForColumn(column: LayoutColumn): Float {
        if (textAlign == MongolTextAlign.JUSTIFY) return 0f

        val contentBounds = contentBoundsForColumn(column)
            ?: return 0f

        val contentHeight = (contentBounds.bottom - contentBounds.top).coerceAtLeast(0f)
        val base = when (textAlign) {
            MongolTextAlign.TOP -> 0f
            MongolTextAlign.CENTER -> ((height - contentHeight) / 2f).coerceAtLeast(0f)
            MongolTextAlign.BOTTOM -> (height - contentHeight).coerceAtLeast(0f)
            MongolTextAlign.JUSTIFY -> 0f
        }
        return base - contentBounds.top
    }

    override fun getBoxesForRange(start: Int, end: Int): List<Rect> {
        check(!disposed) { "MongolParagraph is disposed." }
        if (start < 0 || end < 0 || start > text.length || end > text.length || start >= end) {
            return emptyList()
        }
        val boxes = ArrayList<Rect>(end - start)
        for (index in start until end) {
            val box = glyphBoxesByIndex[index] ?: continue
            if (boxes.lastOrNull() != box) {
                boxes += box
            }
        }
        return boxes
    }

    fun requiresClusterDrawing(start: Int, end: Int): Boolean {
        check(!disposed) { "MongolParagraph is disposed." }
        return forcedBreakRanges.contains(TextRange(start, end))
    }

    fun getPositionForOffset(offset: Offset): TextPosition {
        check(!disposed) { "MongolParagraph is disposed." }
        if (glyphBoxesByIndex.isEmpty()) {
            return TextPosition(offset = 0)
        }

        // 1. Find the column that contains offset.x, or the closest column.
        val bestColumn = columns.minByOrNull { column ->
            val colLeft = column.left
            val colRight = colLeft + column.maxCrossAxis
            if (offset.x >= colLeft && offset.x <= colRight) {
                0f
            } else {
                minOf(abs(offset.x - colLeft), abs(offset.x - colRight))
            }
        } ?: return TextPosition(offset = 0)

        // 2. Find the glyph in this column that contains offset.y or is vertically closest.
        var bestIndexInColumn = -1
        var minDistanceY = Float.POSITIVE_INFINITY

        for (index in bestColumn.glyphIndices) {
            val rect = glyphBoxesByIndex[index] ?: continue
            if (offset.y >= rect.top && offset.y <= rect.bottom) {
                bestIndexInColumn = index
                break
            }
            val dist = minOf(abs(offset.y - rect.top), abs(offset.y - rect.bottom))
            if (dist < minDistanceY) {
                minDistanceY = dist
                bestIndexInColumn = index
            }
        }

        if (bestIndexInColumn == -1) return TextPosition(0)

        val rect = glyphBoxesByIndex[bestIndexInColumn]!!
        val graphemeRange = MongolTextTools.getGraphemeRangeAt(text, bestIndexInColumn)
        
        // Midpoint logic: if tap is in the lower half of the grapheme, move to its end.
        val midY = (rect.top + rect.bottom) / 2f
        val resolvedOffset = if (offset.y > midY) {
            graphemeRange.end
        } else {
            graphemeRange.start
        }

        return TextPosition(offset = resolvedOffset)
    }

    fun getOffsetForCaret(position: TextPosition): Offset {
        check(!disposed) { "MongolParagraph is disposed." }
        if (text.isEmpty() || glyphBoxesByIndex.isEmpty()) {
            return Offset(0f, 0f)
        }

        val clamped = position.offset.coerceIn(0, text.length)
        val normalized = when {
            clamped == text.length -> clamped
            clamped in 0 until text.length -> MongolTextTools.getGraphemeRangeAt(
                text,
                clamped
            ).start

            else -> 0
        }

        if (normalized == text.length) {
            for (index in (text.length - 1) downTo 0) {
                val rect = glyphBoxesByIndex[index] ?: continue
                return Offset(rect.left, rect.bottom)
            }
            return Offset(0f, 0f)
        }

        val exact = glyphBoxesByIndex[normalized]
        if (exact != null) {
            return Offset(exact.left, exact.top)
        }

        val prev = glyphBoxesByIndex[(normalized - 1).coerceAtLeast(0)]
        return if (prev != null) {
            Offset(prev.left, prev.bottom)
        } else {
            Offset(0f, 0f)
        }
    }

    fun getWordBoundary(position: TextPosition): TextRange {
        check(!disposed) { "MongolParagraph is disposed." }
        if (text.isEmpty()) return TextRange(0, 0)

        val pivot = position.offset.coerceIn(0, text.length - 1)
        if (!text[pivot].isLetterOrDigit()) {
            return MongolTextTools.getGraphemeRangeAt(text, pivot)
        }

        var start = pivot
        var end = pivot

        fun isWordChar(ch: Char): Boolean {
            return ch.isLetterOrDigit()
        }

        while (start > 0 && isWordChar(text[start - 1])) {
            start -= 1
        }
        while (end < text.length && isWordChar(text[end])) {
            end += 1
        }

        return TextRange(start = start, end = end)
    }

    fun getLineBoundary(position: TextPosition): TextRange {
        check(!disposed) { "MongolParagraph is disposed." }
        if (text.isEmpty()) return TextRange.EMPTY

        val target = position.offset.coerceIn(0, text.length)
        if (target == text.length) {
            val last = columns.lastOrNull { it.glyphIndices.isNotEmpty() } ?: return TextRange(
                text.length,
                text.length
            )
            val start = last.glyphIndices.first()
            val end = last.glyphIndices.last() + 1
            return TextRange(start, end)
        }

        for (column in columns) {
            if (column.glyphIndices.isEmpty()) continue
            val start = column.glyphIndices.first()
            val end = column.glyphIndices.last() + 1
            val endWithOptionalNewline =
                if (end < text.length && text[end] == '\n') end + 1 else end
            if (target in start until endWithOptionalNewline) {
                return TextRange(start, end)
            }
        }

        return TextRange.EMPTY
    }

    fun computeLineMetrics(): List<MongolLineMetrics> {
        check(!disposed) { "MongolParagraph is disposed." }
        if (columns.isEmpty()) return emptyList()

        val metrics = ArrayList<MongolLineMetrics>(columns.size)
        var baseline = 0f

        for ((lineNumber, column) in columns.withIndex()) {
            val visualHeight = column.usedAdvance
            val start = column.glyphIndices.firstOrNull()
            val endExclusive = column.glyphIndices.lastOrNull()?.plus(1)
            val hardBreak = when {
                start == null || endExclusive == null -> true
                endExclusive < text.length && text[endExclusive] == '\n' -> true
                else -> false
            }

            val top = alignmentOffsetForColumn(column)

            val lineMetric = MongolLineMetrics(
                hardBreak = hardBreak,
                ascent = column.maxAscent,
                descent = column.maxDescent,
                unscaledAscent = column.maxAscent,
                height = visualHeight,
                width = if (column.maxCrossAxis > 0f) column.maxCrossAxis else columnWidthPx,
                top = top,
                baseline = baseline,
                lineNumber = lineNumber,
            )
            metrics += lineMetric
            baseline += column.maxAscent + column.maxDescent
        }

        return metrics
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        columns.clear()
        glyphBoxesByIndex.fill(null)
        glyphMetricsByIndex.fill(null)
        forcedBreakRanges.clear()
        lastLayoutSignatureHash = null
        width = 0f
        height = 0f
        longestLine = 0f
        minIntrinsicHeight = 0f
        maxIntrinsicHeight = Float.POSITIVE_INFINITY
        didExceedMaxLines = false
    }
}
