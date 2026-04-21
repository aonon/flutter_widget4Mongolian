package mongol.compose.core

/**
 * Centralized code-point lists for vertical glyph placement special cases.
 *
 * Add newly discovered edge-case code points here to keep policy logic simple.
 */
object CodePointLists {
    data class ShiftAdjustment(
        val dxFactor: Float,
        val dyFactor: Float,
    )

    private data class CodePointRule(
        val range: IntRange,
        val entersRotatedRun: Boolean = false,
        val shiftAdjustment: ShiftAdjustment? = null,
        val excludedFromRotate: Boolean = false,
        val noRotation: Boolean = false,
        val emoji: Boolean = false,
    )

    private val rules = listOf(
        CodePointRule(
            range = 0x1800..0x1FFF,
            noRotation = true,
        ),
        CodePointRule(
            range = 0x21..0x1099,
            noRotation = true,
        ),
        CodePointRule(
            range = 0x2048..0x2049,
            noRotation = true,
        ),
        CodePointRule(
            range = 0x3007..0x301C,
            excludedFromRotate = true,
        ),
        CodePointRule(
            range = 0x2030..0x2031, // per mille and per ten thousand
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0xFE15..0xFE16,
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = -0.2f, dyFactor = 0.2f),
        ),
        CodePointRule(
            range = 0xFF01..0xFF01,
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = 0.2f, dyFactor = 0.08f),
        ),
        CodePointRule(
            range = 0xFF1B..0xFF1B,
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = 0.25f, dyFactor = 0.08f),
        ),
        CodePointRule(
            range = 0xFF1F..0xFF1F,
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = 0.2f, dyFactor = 0.08f),
        ),
        CodePointRule(
            range = 0xFF1A..0xFF1A, // full-width colon
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = 0.2f, dyFactor = 0.08f),
        ),
        CodePointRule(
            range = 0xFF0C..0xFF0C, // full-width comma
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = 0.25f, dyFactor = 0.15f),
        ),
        CodePointRule(
            range = 0xFF0E..0xFF0F, // full-width full stop and solidus
            entersRotatedRun = true,
            shiftAdjustment = ShiftAdjustment(dxFactor = 0.25f, dyFactor = 0.15f),
        ),
        CodePointRule(
            range = 0x2460..0x24FF,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0x3251..0x325F,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0x32B1..0x32BF,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0xFE30..0xFE4F,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0x1100..0x11FF,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0xFF3E..0xFF40,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0xFF5B..0xFF65,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0x2E80..0x9FFF,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0xAC00..0xD7FF,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0xF900..0xFAFF,
            entersRotatedRun = true,
        ),
        CodePointRule(
            range = 0x1F000..0x1FAFF,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x2600..0x27BF,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x00A9..0x00A9,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x00AE..0x00AE,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x203C..0x203C,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x2122..0x2122,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x2139..0x2139,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x3030..0x3030,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x303D..0x303D,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x3297..0x3297,
            entersRotatedRun = true,
            emoji = true,
        ),
        CodePointRule(
            range = 0x3299..0x3299,
            entersRotatedRun = true,
            emoji = true,
        ),
    )

    private fun matchingRules(codePoint: Int): List<CodePointRule> {
        return rules.filter { codePoint in it.range }
    }

    fun isExcludedFromRotate(codePoint: Int): Boolean {
        return matchingRules(codePoint).any { it.excludedFromRotate }
    }

    fun isEmoji(codePoint: Int): Boolean {
        return matchingRules(codePoint).any { it.emoji }
    }

    fun shiftAdjustment(codePoint: Int): ShiftAdjustment? {
        return matchingRules(codePoint).firstNotNullOfOrNull { it.shiftAdjustment }
    }

    fun isNoRotation(codePoint: Int): Boolean {
        return matchingRules(codePoint).any { it.noRotation }
    }

    fun isRotatedRunCodePoint(codePoint: Int): Boolean {
        if (isNoRotation(codePoint)) return false
        if (isExcludedFromRotate(codePoint)) return false
        return matchingRules(codePoint).any { it.entersRotatedRun }
    }

}
