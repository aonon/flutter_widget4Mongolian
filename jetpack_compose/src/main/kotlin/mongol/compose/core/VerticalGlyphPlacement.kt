package mongol.compose.core

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.drawText

/**
 * 竖排运行中单个字形的共享摆放策略。
 */
data class VerticalGlyphPlacement(
    val dx: Float,
    val dy: Float,
    val rotationDegrees: Float = 0f,
)

object VerticalGlyphPlacementPolicy {
    private fun centerOffset(boxExtent: Float, glyphExtent: Float): Float {
        return (boxExtent - glyphExtent) / 2f
    }

    /**
     * 查找前一个非空白码点，让 ASCII 标点能够利用前文脚本环境判断，
     * 同时不受空格影响。
     */
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
        // 先按未旋转状态居中。若后续需要旋转，则统一绕字形框中心旋转。
        // 先基于未旋转边界做居中，可以保证字形中心锁定在同一个枢轴上，
        // 避免旋转后出现向右或向下的漂移。
        var dx = centerOffset(boxWidth, glyphWidth)
        var dy = centerOffset(boxHeight, glyphHeight)

        val shiftAdjustment = CodePointLists.shiftAdjustment(codePoint)

        // rotateShift 现在只负责偏移量配置，不再决定是否旋转。
        // 偏移值使用 -1..1 的归一化比例，并按当前字形框尺寸换算。
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

        // 需要时，围绕当前字形框中心施加本地修正旋转。
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
