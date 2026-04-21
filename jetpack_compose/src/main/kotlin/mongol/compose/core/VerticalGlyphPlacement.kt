package mongol.compose.core

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.drawText

data class VerticalGlyphPlacement(
    val dx: Float,
    val dy: Float,
    val rotationDegrees: Float = 0f,
)

object VerticalGlyphPlacementPolicy {
    private fun centerOffset(boxExtent: Float, glyphExtent: Float): Float {
        return (boxExtent - glyphExtent) / 2f
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

    fun placeInVerticalBox(
        codePoint: Int,
        previousCodePoint: Int? = null,
        boxWidth: Float,
        boxHeight: Float,
        glyphWidth: Float,
        glyphHeight: Float,
    ): VerticalGlyphPlacement {
        var dx = centerOffset(boxWidth, glyphWidth)
        var dy = centerOffset(boxHeight, glyphHeight)

        val shiftAdjustment = CodePointLists.shiftAdjustment(codePoint)

        if (shiftAdjustment != null) {
            dx += boxWidth * shiftAdjustment.dxFactor
            dy += boxHeight * shiftAdjustment.dyFactor
        }

        return VerticalGlyphPlacement(
            dx = dx,
            dy = dy,
            // CJK characters in vertical Mongolian need to be rotated -90 degrees
            // to align with the vertical column.
            rotationDegrees = 0f,
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
