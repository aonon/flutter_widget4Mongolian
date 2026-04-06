package mongol.compose.editing

import androidx.compose.ui.Modifier
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.platform.InspectorInfo

/**
 * Compatibility-safe IME modifier hook.
 *
 * Some Compose versions expose different platform text-input node APIs.
 * To keep this project compiling across versions, this modifier stores the
 * [MongolInputSession] in a node without directly depending on unstable or
 * version-specific text-input interfaces.
 */
fun Modifier.mongolImeSession(session: MongolInputSession): Modifier =
    this then MongolImeSessionElement(session)

// -------------------------------------------------------------------------- //
// Internal Modifier plumbing
// -------------------------------------------------------------------------- //

private data class MongolImeSessionElement(
    val session: MongolInputSession,
) : ModifierNodeElement<MongolImeSessionNode>() {

    override fun create(): MongolImeSessionNode = MongolImeSessionNode(session)

    override fun update(node: MongolImeSessionNode) {
        node.session = session
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "mongolImeSession"
    }
}

// -------------------------------------------------------------------------- //
// Node
// -------------------------------------------------------------------------- //

internal class MongolImeSessionNode(
    var session: MongolInputSession,
) : Modifier.Node()
