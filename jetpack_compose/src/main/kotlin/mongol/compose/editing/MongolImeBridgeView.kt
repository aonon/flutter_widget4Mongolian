package mongol.compose.editing

import android.content.Context
import android.text.InputType
import android.os.Build
import android.util.AttributeSet
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager

/**
 * Hidden Android View that exposes a real InputConnection to system IME,
 * similar to how native text editors integrate with InputMethodManager.
 */
internal class MongolImeBridgeView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    var session: MongolInputSession? = null

    init {
        isFocusable = true
        isFocusableInTouchMode = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO
        }
    }

    override fun onCheckIsTextEditor(): Boolean = true

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection? {
        val currentSession = session ?: return null
        outAttrs.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_FULLSCREEN
        outAttrs.initialSelStart = currentSession.snapshot().selectionStart
        outAttrs.initialSelEnd = currentSession.snapshot().selectionEnd
        return MongolInputConnection(this, currentSession)
    }

    fun showIme() {
        if (!hasFocus()) {
            requestFocus()
        }
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT)
    }

    fun hideIme() {
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(windowToken, 0)
    }

    fun syncSelection() {
        val currentSession = session ?: return
        val snapshot = currentSession.snapshot()
        val composingStart = snapshot.composingStart ?: -1
        val composingEnd = snapshot.composingEnd ?: -1
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.updateSelection(
            this,
            snapshot.selectionStart,
            snapshot.selectionEnd,
            composingStart,
            composingEnd,
        )
    }
}
