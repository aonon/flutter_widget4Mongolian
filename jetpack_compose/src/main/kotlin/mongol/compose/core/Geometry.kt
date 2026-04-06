package mongol.compose.core

/**
 * Lightweight geometry primitives for core text logic.
 *
 * Keeping these in core avoids taking a direct Compose UI dependency while we
 * migrate algorithmic text code first.
 */
data class Offset(
    val x: Float,
    val y: Float,
)

data class Rect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
)
