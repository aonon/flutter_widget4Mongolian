package mongol.compose.core

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.drawText

/**
 * Shared placement policy for glyphs rendered in vertical runs.
 */
data class VerticalGlyphPlacement(
    val dx: Float,
    val dy: Float,
    val rotationDegrees: Float = 0f,
)

object VerticalGlyphPlacementPolicy {
    private const val MONGOLIAN_START = 0x1800
    private const val MONGOLIAN_END_EXCLUSIVE = 0x2060
    private const val KOREAN_JAMO_START = 0x1100
    private const val KOREAN_JAMO_END = 0x11FF
    private const val CJK_RADICAL_SUPPLEMENT_START = 0x2E80
    private const val CJK_SYMBOLS_AND_PUNCTUATION_END = 0x303F
    private const val CJK_SYMBOLS_AND_PUNCTUATION_START = 0x3000
    private const val CJK_SYMBOLS_AND_PUNCTUATION_MENKSOFT_END = 0x301C
    private const val FULLWIDTH_PUNCTUATION_START = 0xFF01
    private const val FULLWIDTH_PUNCTUATION_END = 0xFF65
    private const val VERTICAL_FORMS_START = 0xFE10
    private const val VERTICAL_FORMS_END = 0xFE1F
    private const val CJK_COMPATIBILITY_FORMS_START = 0xFE30
    private const val CJK_COMPATIBILITY_FORMS_END = 0xFE4F
    private const val CIRCLE_NUMBER_01 = 0x2460
    private const val CIRCLE_NUMBER_NEGATIVE_0 = 0x24FF
    private const val CIRCLE_NUMBER_21 = 0x3251
    private const val CIRCLE_NUMBER_35 = 0x325F
    private const val CIRCLE_NUMBER_36 = 0x32B1
    private const val CIRCLE_NUMBER_50 = 0x32BF
    private const val CJK_UNIFIED_IDEOGRAPHS_END = 0x9FFF
    private const val HANGUL_SYLLABLES_START = 0xAC00
    private const val HANGUL_JAMO_EXTENDED_B_END = 0xD7FF
    private const val CJK_COMPATIBILITY_IDEOGRAPHS_START = 0xF900
    private const val CJK_COMPATIBILITY_IDEOGRAPHS_END = 0xFAFF
    private const val UNICODE_EMOJI_START = 0x1F000
    private const val UNICODE_EMOJI_END = 0x1FAFF
    private const val BMP_EMOJI_AND_DINGBAT_START = 0x2600
    private const val BMP_EMOJI_AND_DINGBAT_END = 0x27BF
    private const val ASCII_PRINTABLE_START = 0x21
    private const val ASCII_PRINTABLE_END = 0x7E
    private const val VERTICAL_PUNCT_SHIFT_DIVISOR = 5f
    private const val QUARTER_TURN_DEGREES = -90f

    private fun isQuarterTurnCircledNumber(codePoint: Int): Boolean {
        return codePoint in CIRCLE_NUMBER_01..CIRCLE_NUMBER_NEGATIVE_0
    }

    private fun isUprightCircledNumber(codePoint: Int): Boolean {
        return codePoint in CIRCLE_NUMBER_21..CIRCLE_NUMBER_35 ||
            codePoint in CIRCLE_NUMBER_36..CIRCLE_NUMBER_50
    }

    private fun isCircledNumber(codePoint: Int): Boolean {
        return isQuarterTurnCircledNumber(codePoint) || isUprightCircledNumber(codePoint)
    }

    private fun isMongolian(codePoint: Int): Boolean {
        return codePoint in MONGOLIAN_START until MONGOLIAN_END_EXCLUSIVE
    }

    private fun isEmoji(codePoint: Int): Boolean {
        if (codePoint in UNICODE_EMOJI_START..UNICODE_EMOJI_END) return true
        if (codePoint in BMP_EMOJI_AND_DINGBAT_START..BMP_EMOJI_AND_DINGBAT_END) return true
        if (codePoint == 0x00A9 || codePoint == 0x00AE) return true
        if (codePoint == 0x203C || codePoint == 0x2049) return true
        if (codePoint == 0x2122 || codePoint == 0x2139) return true
        if (codePoint == 0x3030 || codePoint == 0x303D) return true
        if (codePoint == 0x3297 || codePoint == 0x3299) return true
        return false
    }

    private fun isVerticalPresentationForm(codePoint: Int): Boolean {
        return codePoint in VERTICAL_FORMS_START..VERTICAL_FORMS_END
    }

    private fun isCjkCompatibilityForm(codePoint: Int): Boolean {
        return codePoint in CJK_COMPATIBILITY_FORMS_START..CJK_COMPATIBILITY_FORMS_END
    }

    private fun isVerticalQuestionExclamationForm(codePoint: Int): Boolean {
        return codePoint in VerticalGlyphCodePointLists.verticalQuestionExclamationForms
    }

    private fun isCjkPunctuation(codePoint: Int): Boolean {
        if (codePoint in CJK_SYMBOLS_AND_PUNCTUATION_START..CJK_SYMBOLS_AND_PUNCTUATION_END) return true
        if (codePoint in FULLWIDTH_PUNCTUATION_START..FULLWIDTH_PUNCTUATION_END) return true
        if (isVerticalPresentationForm(codePoint)) return true
        if (isCjkCompatibilityForm(codePoint)) return true
        return false
    }

    private fun isAsciiPunctuation(codePoint: Int): Boolean {
        if (codePoint < ASCII_PRINTABLE_START || codePoint > ASCII_PRINTABLE_END) return false
        val ch = codePoint.toChar()
        return !ch.isLetterOrDigit()
    }

    private fun centerOffset(boxExtent: Float, glyphExtent: Float): Float {
        return (boxExtent - glyphExtent) / 2f
    }

    private fun isCjkLike(codePoint: Int): Boolean {
        if (codePoint in KOREAN_JAMO_START..KOREAN_JAMO_END) return true
        if (codePoint in CJK_RADICAL_SUPPLEMENT_START..CJK_UNIFIED_IDEOGRAPHS_END) return true
        if (codePoint in HANGUL_SYLLABLES_START..HANGUL_JAMO_EXTENDED_B_END) return true
        if (codePoint in CJK_COMPATIBILITY_IDEOGRAPHS_START..CJK_COMPATIBILITY_IDEOGRAPHS_END) return true
        if (isEmoji(codePoint)) return true
        return false
    }

    private fun shouldVerticalizePunctuation(
        codePoint: Int,
        previousCodePoint: Int?,
    ): Boolean {
        if (isCjkPunctuation(codePoint)) return true
        if (!isAsciiPunctuation(codePoint)) return false

        val prev = previousCodePoint ?: return false
        return isMongolian(prev) || isCjkLike(prev)
    }

    fun previousVisibleCodePoint(text: String, fromCodeUnitIndex: Int): Int? {
        var i = fromCodeUnitIndex - 1
        while (i >= 0) {
            val cp = Character.codePointBefore(text, i + 1)
            val charCount = Character.charCount(cp)
            if (!Character.isWhitespace(cp)) {
                return cp
            }
            i -= charCount
        }
        return null
    }

    private fun shouldQuarterTurnInVertical(codePoint: Int): Boolean {
        // Keep this predicate aligned with Flutter's LineBreaker._isRotatable.
        if (codePoint >= MONGOLIAN_START && codePoint < MONGOLIAN_END_EXCLUSIVE) {
            return false
        }

        if (codePoint < KOREAN_JAMO_START) return false
        if (codePoint <= KOREAN_JAMO_END) return true
        if (isQuarterTurnCircledNumber(codePoint)) return true

        if (codePoint in CJK_RADICAL_SUPPLEMENT_START..CJK_UNIFIED_IDEOGRAPHS_END) {
            if (codePoint in CJK_SYMBOLS_AND_PUNCTUATION_START..CJK_SYMBOLS_AND_PUNCTUATION_MENKSOFT_END) {
                return false
            }
            if (isCircledNumber(codePoint)) return false
            return true
        }

        if (codePoint in HANGUL_SYLLABLES_START..HANGUL_JAMO_EXTENDED_B_END) {
            return true
        }

        if (codePoint in CJK_COMPATIBILITY_IDEOGRAPHS_START..CJK_COMPATIBILITY_IDEOGRAPHS_END) {
            return true
        }

        return false
    }

    fun placeInVerticalBox(
        codePoint: Int,
        previousCodePoint: Int? = null,
        boxWidth: Float,
        boxHeight: Float,
        glyphWidth: Float,
        glyphHeight: Float,
    ): VerticalGlyphPlacement {
        val circledNumber = isCircledNumber(codePoint)
        val quarterTurn = shouldQuarterTurnInVertical(codePoint)
        val contextPunctuationVertical = shouldVerticalizePunctuation(codePoint, previousCodePoint)
        val questionExclamationForm = isVerticalQuestionExclamationForm(codePoint)
        val verticalized = quarterTurn || contextPunctuationVertical || circledNumber || questionExclamationForm
        if (!verticalized) {
            // Keep English-context punctuation and other glyphs in original orientation/placement.
            return VerticalGlyphPlacement(dx = 0f, dy = 0f, rotationDegrees = 0f)
        }

        val needsRotation = (contextPunctuationVertical &&
                !isCjkPunctuation(codePoint) &&
                !questionExclamationForm)

        // Center by unrotated bounds first. When rotation is applied around the box center,
        // this keeps the glyph center locked to the same pivot and avoids right/down drift.
        var dx = centerOffset(boxWidth, glyphWidth)
        var dy = centerOffset(boxHeight, glyphHeight)

        if (questionExclamationForm) {
            dx -= boxWidth / VERTICAL_PUNCT_SHIFT_DIVISOR
            dy += boxHeight / VERTICAL_PUNCT_SHIFT_DIVISOR
        }

        return VerticalGlyphPlacement(
            dx = dx,
            dy = dy,
            // Rotate only correction classes and context-forced ASCII punctuation.
            rotationDegrees = if (needsRotation) QUARTER_TURN_DEGREES else 0f,
        )
    }

    fun DrawScope.drawGlyphInVerticalBox(
        codePoint: Int,
        previousCodePoint: Int? = null,
        box: Rect,
        glyphLayout: TextLayoutResult,
    ) {
        val placement = placeInVerticalBox(
            codePoint = codePoint,
            previousCodePoint = previousCodePoint,
            boxWidth = box.right - box.left,
            boxHeight = box.bottom - box.top,
            glyphWidth = glyphLayout.size.width.toFloat(),
            glyphHeight = glyphLayout.size.height.toFloat(),
        )
        val topLeft = Offset(
            box.left + placement.dx,
            box.top + placement.dy,
        )

        if (placement.rotationDegrees != 0f) {
            val pivot = Offset(
                x = box.left + (box.right - box.left) / 2f,
                y = box.top + (box.bottom - box.top) / 2f,
            )
            withTransform({
                rotate(degrees = placement.rotationDegrees, pivot = pivot)
            }) {
                drawText(
                    textLayoutResult = glyphLayout,
                    topLeft = topLeft,
                )
            }
        } else {
            drawText(
                textLayoutResult = glyphLayout,
                topLeft = topLeft,
            )
        }
    }
}
