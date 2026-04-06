# 蒙古文垂直排版 → Jetpack Compose 移植计划

**来源项目**：flutter_widget4Mongolian (Dart/Flutter)  
**目标平台**：Android Jetpack Compose (Kotlin)  
**创建日期**：2026-04-06

---

## 核心思路：旋转策略（Rotation Strategy）

Flutter 库的核心思路是 **"水平布局 + 旋转 90°"**：
1. 使用平台文本引擎（Flutter ui.Paragraph）做横排布局
2. 在绘制时将 Canvas 顺时针旋转 90° 将横排变竖排
3. CJK（中日韩）字符再额外旋转 90°（使其在竖列中保持正向）

这一策略在 Jetpack Compose 中完全可以复现：
- 用 TextMeasurer.measure() 替代 Flutter ui.Paragraph
- 用 DrawScope.rotate(90f) / graphicsLayer { rotationZ = 90f } 替代 Canvas 旋转
- 布局测量时交换 width/height

---

## 项目结构建议（Compose 侧）

```text
mongol-compose/
├── core/          ← 对应 Flutter base/
│   ├── MongolParagraph.kt
│   ├── MongolTextPainter.kt
│   ├── MongolTextAlign.kt
│   ├── MongolLineMetrics.kt
│   ├── MongolTextMetrics.kt
│   └── MongolTextTools.kt
├── text/          ← 对应 Flutter text/
│   ├── MongolText.kt
│   └── MongolRichText.kt
└── editing/       ← 对应 Flutter editing/
    ├── MongolTextField.kt
    ├── MongolEditableText.kt
    └── MongolRenderEditable.kt
```

---

## 第一阶段：core（对应 base）

### 1.1 MongolTextAlign.kt
```kotlin
enum class MongolTextAlign { TOP, BOTTOM, CENTER, JUSTIFY }
```

### 1.2 MongolLineMetrics.kt
```kotlin
data class MongolLineMetrics(
    val hardBreak: Boolean,
    val ascent: Float,
    val descent: Float,
    val unscaledAscent: Float,
    val height: Float,
    val width: Float,
    val top: Float,
    val baseline: Float,
    val lineNumber: Int,
)
```

### 1.3 MongolTextTools.kt
移植 MongolTextTools 的静态工具函数：
- UTF-16 代码单元检查（isUTF16, isHighSurrogate, isLowSurrogate）
- 坐标变换（将横排坐标系映射到竖排坐标系）
- 光标导航辅助

### 1.4 MongolTextMetrics.kt（CaretMetrics）
```kotlin
sealed class CaretMetrics
data class LineCaretMetrics(val offset: Offset, val fullWidth: Float) : CaretMetrics()
data class EmptyLineCaretMetrics(val lineHorizontalOffset: Float) : CaretMetrics()
```

### 1.5 MongolParagraph.kt（核心）
核心布局算法：
1. 接受高度约束（MongolParagraphConstraints）
2. 用 TextMeasurer 对每个 TextRun 做横排布局
3. 按高度约束断行，形成多列
4. 计算 width（所有列宽之和）、height、longestLine 等

Compose TextMeasurer 用法：
```kotlin
val measurer = rememberTextMeasurer()
val result: TextLayoutResult = measurer.measure(
    text = AnnotatedString(runText),
    style = textStyle,
    constraints = Constraints(maxWidth = constraintHeight.toInt()),
)
```

### 1.6 MongolTextPainter.kt
封装 MongolParagraph，提供：
- layout(minHeight, maxHeight)
- paint(drawScope, offset)
- getPositionForOffset(offset)
- getOffsetForCaret(position, caretPrototype)
- getWordBoundary(position)

---

## 第二阶段：text（对应 Flutter text）

### 2.1 MongolText.kt
```kotlin
@Composable
fun MongolText(
    text: String,
    modifier: Modifier = Modifier,
    style: TextStyle = LocalTextStyle.current,
    textAlign: MongolTextAlign = MongolTextAlign.TOP,
    overflow: TextOverflow = TextOverflow.Clip,
    softWrap: Boolean = true,
    maxLines: Int = Int.MAX_VALUE,
    rotateCjk: Boolean = true,
)
```

### 2.2 MongolRichText.kt
用自定义 Layout + Canvas 实现，Layout 高度约束传给 painter.layout，宽度由布局结果决定。

---

## 第三阶段：editing（对应 Flutter editing）

推荐方案：完全自定义（不依赖 BasicTextField 横排选区模型）

### 3.1 MongolRenderEditable.kt
负责：
- 光标矩形
- 选区高亮
- 文本命中测试
- 滚动偏移

### 3.2 MongolEditableText.kt
负责：
- TextFieldState/控制器
- IME 连接
- 焦点管理
- onChanged/onSubmitted 等回调

### 3.3 MongolTextField.kt
负责高层装饰：label/hint/prefix/suffix 等。

---

## 难点与风险

1. TextMeasurer 在非 Composable 中不可直接创建，需要在 Composable 层创建后注入。
2. CJK 字符识别与旋转要复用 Unicode 范围判断。
3. 旋转后触摸坐标需逆变换映射到文本偏移。
4. IME 竖向输入与选区手柄是 editing 阶段最复杂部分。

---

## 实施顺序（推荐）

```text
[1] MongolTextAlign.kt
[2] MongolLineMetrics.kt
[3] MongolTextTools.kt
[4] MongolTextMetrics.kt
[5] MongolParagraph.kt
[6] MongolTextPainter.kt
[7] MongolRichText.kt
[8] MongolText.kt
--- base + text 可运行 ---
[9] MongolRenderEditable.kt
[10] MongolEditableText.kt
[11] MongolTextField.kt
--- editing 完成 ---
```

---

## Flutter → Compose API 对照（精简）

- ui.Paragraph / ui.ParagraphBuilder → TextMeasurer.measure() / TextLayoutResult
- Canvas.rotate() → DrawScope.rotate()
- RenderBox → 自定义 Layout composable
- TextSpan → AnnotatedString + SpanStyle
- TextEditingController → TextFieldState 或 MutableState<TextFieldValue>
- FocusNode → FocusRequester
- ViewportOffset → ScrollState

---

## 参考资源

- 本库源码：lib/src/base/, lib/src/text/, lib/src/editing/
- https://developer.android.com/jetpack/compose/text/fonts
- https://developer.android.com/jetpack/compose/graphics/draw/overview
- https://developer.android.com/reference/kotlin/androidx/compose/foundation/text/package-summary
