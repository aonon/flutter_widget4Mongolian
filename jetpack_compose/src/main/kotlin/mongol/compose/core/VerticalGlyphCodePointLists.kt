package mongol.compose.core

/**
 * Centralized code-point lists for vertical glyph placement special cases.
 *
 * Add newly discovered edge-case code points here to keep policy logic simple.
 */
object VerticalGlyphCodePointLists {
    // FE15/FE16 are vertical forms; include ASCII !/? for consistent compensation behavior.
    val verticalQuestionExclamationForms: Set<Int> = setOf(
        0xFE15,
        0xFE16,
        0x0021,
        0x003F,
    )
}
