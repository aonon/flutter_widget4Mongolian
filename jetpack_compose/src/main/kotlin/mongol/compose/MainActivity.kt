package mongol.compose

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import mongol.compose.core.MongolTextAlign
import mongol.compose.editing.MongolBasicTextField
import mongol.compose.editing.MongolTextField
import mongol.compose.text.MongolText
import mongol.compose.ui.theme.Test_composeTheme

class MainActivity : ComponentActivity() {
    val font = FontFamily(Font(R.font.moskwa))

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            Test_composeTheme {
                val scrollState = rememberScrollState()

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    contentWindowInsets = WindowInsets(0, 0, 0, 0)
                ) { innerPadding ->
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .fillMaxWidth()
                            .padding(innerPadding)
                            .imePadding()
                            .verticalScroll(scrollState)

                    ) {
                        val t =
                            "ᠨᠢᠭᠡ ᠬᠣᠶᠠᠷ ! ᠭᠣᠷᠪᠠ? \u2460\u24fe ᠳᠥᠷᠪᠡ 四 ᠲᠠᠪᠤ ᠵᠢᠷᠭᠤᠭ᠎ᠠ ᠳᠣᠯᠣᠭ᠎ᠠ ᠨᠠᠢᠮᠠ ᠶᠢᠰᠦ ᠠᠷᠪᠠ ♥\uD83D\uDE42 ᠬᠣᠷᠢᠨ ᠨᠢᠭᠡ ᠬᠣᠷᠢᠨ ᠬᠣᠶᠠᠷ ᠬᠣᠷᠢᠨ ᠭᠣᠷᠪᠠ one two three four five six seven eight nine ten 👨‍👩‍👧👋🏿🇭🇺一二三四五六七八九十\uD83D\uDE03\uD83D\uDE0A\uD83D\uDE1C\uD83D\uDE01\uD83D\uDE2C\uD83D\uDE2E\uD83D\uDC34\uD83D\uDC02\uD83D\uDC2B\uD83D\uDC11\uD83D\uDC10①②③㉑㊿〖汉字〗한국어モンゴル語English? ︽ᠮᠣᠩᠭᠣᠯ︖︾"

                        var textAlign by remember { mutableStateOf(MongolTextAlign.TOP) }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            MongolTextAlign.entries.forEach { align ->
                                RadioButton(
                                    selected = textAlign == align,
                                    onClick = { textAlign = align }
                                )
                                Text(align.name)
                            }
                        }

                        Text("Use Compose MongolText:")
                        MongolText(
                            text = t,
                            rotateCjk = true,
                            style = TextStyle(fontFamily = font),
                            textAlign = textAlign,
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .border(1.dp, Color.Red)
                        )
                        MongolBasicTextField(
                                value = t,
                                onValueChange = {},
                                textStyle = TextStyle(fontFamily = font),
                            textAlign = textAlign,
                                readOnly = true,
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .border(1.dp, Color.Red)
                        )

                        var text by remember { mutableStateOf("") }

                        Text("Use Compose MongolTextField:")
                        MongolTextField(
                            value = text,
                            onValueChange = { text = it },
                            style = TextStyle(fontFamily = font),
                            label = "Mongol Input",
                            placeholder = "请输入蒙古文或混排文本",
                            supportingText = "Supports multi-line, selection, and IME candidate commit",
                            maxLength = 280,
                            prefixContent = {
                                MongolText(
                                    text = "ᠡᠮᠦᠨ᠎ᠡ ᠪᠢᠴᠢᠯᠭᠡ᠄",
                                    style = TextStyle(
                                        fontFamily = font,
                                        color = Color(0xFF2E7D32)
                                    ),
                                )
                            },
                            suffixContent = {
                                MongolText(
                                    text = "ᠠᠷᠤ ᠳᠠᠭᠠᠯᠳᠠ",
                                    style = TextStyle(
                                        fontFamily = font,
                                        color = Color(0xFF2E7D32)
                                    )
                                )
                            },
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .defaultMinSize(minWidth = 100.dp)
                                .border(1.dp, Color.Blue)
                        )
                    }
                }
            }
        }
    }
}