package mongol.compose

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.input.InputTransformation
import androidx.compose.foundation.text.input.TextFieldBuffer
import androidx.compose.foundation.text.input.TextFieldLineLimits
import androidx.compose.foundation.text.input.maxLength
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldLabelPosition
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mongol.compose.core.MongolTextAlign
import mongol.compose.editing.MongolBasicTextField
import mongol.compose.editing.MongolEditableState
import mongol.compose.editing.MongolOutlinedTextField
import mongol.compose.editing.MongolTextField
import mongol.compose.editing.MongolTextFieldLabelPosition
import mongol.compose.selectable.MongolSelectableText
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
                    contentWindowInsets = androidx.compose.foundation.layout.WindowInsets(0, 0, 0, 0)
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
                            "\u300Aᠨᠢᠭᠡ\u300B\u3008ᠪᠠᠰᠠ ᠨᠢᠭᠡ\u3009 \uFF3Bᠬᠣᠶᠠᠷ\uFF3D ᠭᠣᠷᠪᠠ\uFF1B ᠳᠥᠷᠪᠡ \uFF08ᠲᠠᠪᠤ\uFF09 ᠵᠢᠷᠭᠤᠭ᠎ᠠ\u2048\u2049 ᠬᠣᠷᠢᠨ ᠬᠣᠶᠠᠷ\uFF01\uFF0D\uFF1F  ᠬᠣᠷᠢᠨ ᠭᠣᠷᠪᠠ one two three four five six seven eight nine ten 👨‍👩‍👧👋🏿🇭🇺一二三四五六C:\\Users\\itegel\\StudioProjects\\compose\\.idea\\misc.xml七八九十\uD83D\uDE03\uD83D\uDE0A\uD83D\uDE1C\uD83D\uDE01\uD83D\uDE2C\uD83D\uDE2E\uD83D\uDC34\uD83D\uDC02\uD83D\uDC2B\uD83D\uDC11\uD83D\uDC10①②③㉑㊿〖汉字〗한국어モンゴル語English? ︽ᠮᠣᠩᠭᠣᠯ︖︾".repeat(2)
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

                        Text("Use Compose MongolSelectableText:")
                        MongolBasicTextField(
                            text = t,
                            onValueChange = {},
                            rotateCjk = true,
                            style = TextStyle(fontFamily = font),
                            textAlign = textAlign,
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .border(1.dp, Color.Red)
                        )
                        /*MongolText(
                            text = t,
                            rotateCjk = true,
                            style = TextStyle(fontFamily = font),
                            textAlign = textAlign,
                            horizontalScrollEnabled = true,
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .border(1.dp, Color.Red)
                        )
                        MongolBasicTextField(
                            text = t,
                            onValueChange = {},
                            rotateCjk = true,
                            style = TextStyle(fontFamily = font),
                            textAlign = textAlign,
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .border(1.dp, Color.Red)
                        )
                        MongolSelectableText(
                            text = t,
                            style = TextStyle(fontFamily = font),
                            modifier = Modifier
                                .padding(10.dp)
                                .height(200.dp)
                                .border(1.dp, Color.Red)
                        )*/

                        val textFieldState = rememberTextFieldState()
                        var mongolTextFieldValue by remember { mutableStateOf("1") }
                        var mongolTextFieldValue2 by remember { mutableStateOf("12") }
                        var mongolOutlinedFieldValue by remember { mutableStateOf("") }

                        Text("Use Compose TextField / MongolTextField / MongolOutlinedTextField:")
                        TextField(
                            state = textFieldState,
                            inputTransformation = InputTransformation { }.maxLength(280),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                            labelPosition = TextFieldLabelPosition.Above(),
                            label = { Text("金额") },
                            placeholder = { Text("Placeholder") },
                            prefix = {
                                Text(
                                    text = "₮",
                                    style = TextStyle(fontFamily = font),
                                )
                            },
                            suffix = {
                                Text(
                                    text = ".00",
                                    style = TextStyle(fontFamily = font),
                                )
                            },
                            enabled = true,
                            readOnly = false,
                            modifier = Modifier
                                .padding(8.dp)
                                .fillMaxWidth()
                        )
                        OutlinedTextField(
                            state = textFieldState,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                            labelPosition = TextFieldLabelPosition.Above(),
                            label = { Text("电话号码：") },
                            placeholder = { Text("Standard Outlined Placeholder") },
                            modifier = Modifier
                                .padding(8.dp)
                        )
                        Row(
                            Modifier
                                .height(320.dp)
                                .horizontalScroll(rememberScrollState())
                                .border(1.dp, Color.Red)
                        ) {
                            MongolBasicTextField(
                                text = "ABCD",
                                onValueChange = {},
                                rotateCjk = true,
                                style = TextStyle(fontFamily = font),
                                textAlign = textAlign,
                                modifier = Modifier
                                    .padding(10.dp)
                                    .height(200.dp)
                                    .border(1.dp, Color.Red)
                            )
                            MongolTextField(
                                value = mongolTextFieldValue,
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Filled.Info,
                                        contentDescription = null
                                    )
                                },
                                trailingIcon = {
                                    Icon(
                                        imageVector = Icons.Filled.Add,
                                        contentDescription = null
                                    )
                                },
                                singleLine = true,
                                onValueChange = { mongolTextFieldValue = it },
                                inputTransformation = InputTransformation.maxLength(180),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text,
                                    imeAction = ImeAction.Next),
                                style = TextStyle(fontFamily = font),
                                label = {
                                    MongolText(
                                        "姓名",
                                        style = TextStyle(fontFamily = font, fontSize = 8.sp),
                                        textAlign = MongolTextAlign.JUSTIFY
                                    )
                                },
                                labelPosition = MongolTextFieldLabelPosition.Above,
                                placeholder = {
                                    MongolText(
                                        text = "ᠴᠢ ᠭᠡᠨ ᠪᠤᠢ ᠴᠢ ᠭᠡᠨ ᠪᠤᠢ ᠴᠢ ᠭᠡᠨ ",
                                        style = TextStyle(fontFamily = font, color = Color.Red),
                                    )
                                },
                                prefix = {
                                    MongolText(
                                        text = "ᠨᠡᠷ᠎ᠡ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                suffix = {
                                    MongolText(
                                        text = "ᠲᠡᠭᠦᠰ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                supportingText = {
                                    MongolText("Supports text")
                                },
                                modifier = Modifier
                                    .padding(8.dp).fillMaxHeight()
                            )
                            //
                            MongolTextField(
                                value = mongolTextFieldValue2,
                                onValueChange = { mongolTextFieldValue2 = it },
                                inputTransformation = InputTransformation.maxLength(180),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number,
                                    imeAction = ImeAction.Next),
                                style = TextStyle(fontFamily = font),
                                label = {
                                    MongolText(
                                        "年龄",
                                        style = TextStyle(fontFamily = font, fontSize = 8.sp),
                                        textAlign = MongolTextAlign.JUSTIFY
                                    )
                                },
                                labelPosition = MongolTextFieldLabelPosition.Attached,
                                placeholder = {
                                    MongolText(
                                        text = "ᠴᠢ ᠭᠡᠨ ᠪᠤᠢ",
                                        style = TextStyle(fontFamily = font, color = Color.Red),
                                    )
                                },
                                prefix = {
                                    MongolText(
                                        text = "₮",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                suffix = {
                                    MongolText(
                                        text = ".00",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                supportingText = {
                                    MongolText("Supports text")
                                },
                                modifier = Modifier
                                    .padding(8.dp).fillMaxHeight()
                            )
                            /*class DigitOnlyTransformation : InputTransformation {
                                override fun TextFieldBuffer.transformInput() {
                                    if (!asCharSequence().all { it.isDigit() }) {
                                        revertAllChanges()
                                    }
                                }
                            }*/
                            MongolOutlinedTextField(
                                value = mongolOutlinedFieldValue,
                                onValueChange = { mongolOutlinedFieldValue = it },
//                                inputTransformation = DigitOnlyTransformation().maxLength(195),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone,
                                    imeAction = ImeAction.Search),
                                style = TextStyle(fontFamily = font),
                                label = {
                                    MongolText(
                                        "电话",
                                        style = TextStyle(fontFamily = font),
                                        modifier = Modifier.fillMaxHeight(1f),
                                        textAlign = MongolTextAlign.CENTER
                                    )
                                },
                                labelPosition = MongolTextFieldLabelPosition.Above,
                                placeholder = {
                                    MongolText(
                                        text = "ᠪᠢᠴᠢᠪᠦᠷᠢ ᠣᠷᠣᠨ᠎ᠠ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                prefix = {
                                    MongolText(
                                        text = "ᠦᠵᠡᠭ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                suffix = {
                                    MongolText(
                                        text = "ᠬᠡᠰᠡᠭ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                supportingText = { MongolText("Outlined style comparison") },
                                modifier = Modifier
                                    .padding(8.dp)
                            )
                            MongolOutlinedTextField(
                                value = mongolOutlinedFieldValue,
                                onValueChange = { mongolOutlinedFieldValue = it },
//                                inputTransformation = DigitOnlyTransformation().maxLength(195),
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                                style = TextStyle(fontFamily = font),
                                label = {
                                    MongolText(
                                        "地址",
                                        style = TextStyle(fontFamily = font),
                                        modifier = Modifier.fillMaxHeight(1f),
                                        textAlign = MongolTextAlign.CENTER
                                    )
                                },
                                labelPosition = MongolTextFieldLabelPosition.Attached,
                                placeholder = {
                                    MongolText(
                                        text = "ᠪᠢᠴᠢᠪᠦᠷᠢ ᠣᠷᠣᠨ᠎ᠠ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                prefix = {
                                    MongolText(
                                        text = "ᠦᠵᠡᠭ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                suffix = {
                                    MongolText(
                                        text = "ᠬᠡᠰᠡᠭ",
                                        style = TextStyle(fontFamily = font),
                                    )
                                },
                                supportingText = { MongolText("Outlined style comparison") },
                                modifier = Modifier
                                    .padding(8.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}