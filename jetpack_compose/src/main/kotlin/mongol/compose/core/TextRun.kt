package mongol.compose.core

/**
 * Run-level text segment metadata for MongolParagraph.
 *
 * This is intentionally style-agnostic for now. The Compose-specific layout
 * payload will be added when TextMeasurer integration is wired.
 */
data class TextRun(
    val start: Int,
    val end: Int,
    val isRotated: Boolean,
    val runId: Int = 0,
)
