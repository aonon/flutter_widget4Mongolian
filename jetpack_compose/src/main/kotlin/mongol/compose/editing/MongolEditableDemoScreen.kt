package mongol.compose.editing

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text as M3Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Minimal demo screen for validating MongolEditableText migration behavior.
 */
@Composable
fun MongolEditableDemoScreen(
    modifier: Modifier = Modifier,
) {
    val state = rememberMongolEditableState(
        initialText = "ᠮᠣᠩᠭᠤᠯ\nMongol Compose\nDouble click word, triple click line",
    )
    var handleState by remember {
        mutableStateOf(MongolSelectionHandlesState(handles = emptyList(), activeHandle = null))
    }

    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Button(onClick = { state.undo() }, enabled = state.canUndo) {
                M3Text("Undo")
            }
            Button(onClick = { state.redo() }, enabled = state.canRedo) {
                M3Text("Redo")
            }
            Button(onClick = { state.selectAll() }) {
                M3Text("Select All")
            }
        }

        mongol.compose.editing.MongolTextField(
            state = state,
            modifier = Modifier
                .fillMaxWidth()
                .height(320.dp),
            onSelectionHandlesChanged = { handleState = it },
        )

        M3Text(
            text = "Selection: ${state.selection.start}..${state.selection.end} | Active handle: ${handleState.activeHandle ?: "none"}",
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
