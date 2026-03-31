# 垂直蒙古文文本显示组件

## 概述

`lib/src/text/` 目录包含用于显示垂直蒙古文文本的核心组件。这三个类分别对应 Flutter 框架中的 `Text`、`RichText` 和 `RenderParagraph`，但将文本方向从水平改为垂直，以适应传统蒙古文的书写方向。

## 特性

- ✅ **垂直文本布局** — 文本从上到下书写，多行时从左到右排列
- ✅ **自动换行** — 支持在约束高度内自动换行
- ✅ **富文本** — 通过 `TextSpan` 树支持混合样式文本
- ✅ **CJK 字符旋转** — 中日韩字符可旋转 90° 以直立显示（`rotateCJK`）
- ✅ **文本缩放** — 支持 `TextScaler` 非线性文本缩放策略（已弃用 `textScaleFactor`）
- ✅ **溢出处理** — 支持 clip、ellipsis、fade、visible 四种溢出模式
- ✅ **DefaultTextStyle 继承** — `MongolText` 自动继承祖先的 `DefaultTextStyle`
- ✅ **辅助功能 (Semantics)** — `MongolText` 支持 `semanticsLabel`
- ✅ **手势识别** — `MongolRenderParagraph` 支持 `TextSpan` 上的 `GestureRecognizer`

## 架构

### 组件层次

```
MongolText (StatelessWidget)
  └── MongolRichText (LeafRenderObjectWidget)
        └── MongolRenderParagraph (RenderBox)
              └── MongolTextPainter (base/)
                    ├── MongolParagraph
                    └── MongolTextTools
```

### 与 Flutter 框架对应关系

| 本库组件 | Flutter 对应 | 基类 |
|---------|-------------|------|
| `MongolText` | `Text` | `StatelessWidget` |
| `MongolRichText` | `RichText` | `LeafRenderObjectWidget` |
| `MongolRenderParagraph` | `RenderParagraph` | `RenderBox` + mixins |

### 文件说明

1. **mongol_text.dart** — `MongolText`
   - 最常用的文本组件，等价于 Flutter 的 `Text`
   - 提供 `MongolText(data)` 和 `MongolText.rich(textSpan)` 两个构造函数
   - 自动合并 `DefaultTextStyle`、`MediaQuery.boldTextOf`，通过 `mapHorizontalToMongolTextAlign` 将水平对齐映射为垂直对齐
   - 解析 `textScaler` / `textScaleFactor`（已弃用）并传递给 `MongolRichText`

2. **mongol_rich_text.dart** — `MongolRichText`
   - 底层富文本组件，等价于 Flutter 的 `RichText`
   - `LeafRenderObjectWidget`，直接创建和更新 `MongolRenderParagraph` 渲染对象
   - 接收已解析好的 `TextSpan`、`TextScaler` 等参数

3. **mongol_render_paragraph.dart** — `MongolRenderParagraph`
   - 渲染层实现，等价于 Flutter 的 `RenderParagraph`
   - 混入 `ContainerRenderObjectMixin`、`RenderInlineChildrenContainerDefaults`、`RelayoutWhenSystemFontsChangeMixin`
   - 内部使用 `MongolTextPainter` 执行实际的文本布局和绘制
   - 处理溢出效果（clip / ellipsis / fade / visible）
   - 支持 `TextSpan.recognizer` 手势识别

## 属性一览

### MongolText

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `data` | `String?` | — | 要显示的纯文本（与 `textSpan` 互斥） |
| `textSpan` | `TextSpan?` | — | 要显示的富文本（与 `data` 互斥） |
| `style` | `TextStyle?` | null | 文本样式，若 `inherit` 为 true 则合并 `DefaultTextStyle` |
| `textAlign` | `MongolTextAlign?` | null | 垂直对齐方式，null 时继承 `DefaultTextStyle` |
| `softWrap` | `bool?` | null | 是否在软换行处换行，null 时继承 `DefaultTextStyle` |
| `overflow` | `TextOverflow?` | null | 溢出处理，null 时继承 `DefaultTextStyle` |
| `textScaler` | `TextScaler?` | null | 文本缩放策略，null 时取 `MediaQuery.textScalerOf` |
| `textScaleFactor` | `double?` | null | ⚠️ 已弃用，请用 `textScaler` |
| `maxLines` | `int?` | null | 最大行数，null 时继承 `DefaultTextStyle` |
| `semanticsLabel` | `String?` | null | 辅助功能语义标签 |
| `rotateCJK` | `bool` | true | CJK 字符是否旋转 90° |

### MongolRichText

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `text` | `TextSpan` | **必填** | 富文本内容 |
| `textAlign` | `MongolTextAlign` | `top` | 垂直对齐方式 |
| `softWrap` | `bool` | true | 是否在软换行处换行 |
| `overflow` | `TextOverflow` | `clip` | 溢出处理方式 |
| `textScaler` | `TextScaler` | `noScaling` | 文本缩放策略 |
| `textScaleFactor` | `double` | 1.0 | ⚠️ 已弃用，请用 `textScaler` |
| `maxLines` | `int?` | null | 最大行数 |
| `rotateCJK` | `bool` | true | CJK 字符是否旋转 90° |

### MongolRenderParagraph

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `text` | `TextSpan` | **必填** | 文本内容 |
| `textAlign` | `MongolTextAlign` | `top` | 垂直对齐方式 |
| `softWrap` | `bool` | true | 是否在软换行处换行 |
| `overflow` | `TextOverflow` | `clip` | 溢出处理方式 |
| `textScaler` | `TextScaler` | `noScaling` | 文本缩放策略 |
| `textScaleFactor` | `double` | 1.0 | ⚠️ 已弃用，请用 `textScaler` |
| `maxLines` | `int?` | null | 最大行数 |
| `rotateCJK` | `bool` | true | CJK 字符是否旋转 90° |

## 基础用法

### 简单文本

```dart
MongolText(
  'ᠮᠣᠩᠭᠣᠯ',
  style: TextStyle(fontSize: 24),
)
```

### 带对齐和溢出

```dart
MongolText(
  '很长的蒙古文文本...',
  textAlign: MongolTextAlign.center,
  overflow: TextOverflow.ellipsis,
  maxLines: 3,
  style: TextStyle(fontWeight: FontWeight.bold),
)
```

### 富文本

```dart
MongolText.rich(
  TextSpan(
    text: 'Hello ',
    children: [
      TextSpan(text: 'bold', style: TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: ' world!'),
    ],
  ),
)
```

### 使用 TextScaler

```dart
MongolText(
  '缩放文本',
  textScaler: TextScaler.linear(1.5),
)
```

### 直接使用 MongolRichText

```dart
MongolRichText(
  text: TextSpan(
    text: '蒙古文',
    style: TextStyle(fontSize: 20, color: Colors.blue),
    children: [
      TextSpan(text: ' 文本库', style: TextStyle(color: Colors.red)),
    ],
  ),
  textAlign: MongolTextAlign.center,
  softWrap: true,
)
```

## 被引用情况

`MongolText` 和 `MongolRichText` 被以下组件使用：

| 文件 | 引用 |
|------|------|
| `button/mongol_filled_button.dart` | `MongolText` |
| `editing/mongol_input_decorator.dart` | `MongolText` |
| `menu/mongol_tooltip.dart` | `MongolText` |
| `list/mongol_switch_list_tile.dart` | `MongolText` + `MongolRichText` |
| `list/mongol_radio_list_tile.dart` | `MongolText` + `MongolRichText` |
| `list/mongol_checkbox_list_tile.dart` | `MongolText` + `MongolRichText` |

## 依赖关系

本目录依赖 `base/` 中的底层组件：

- `MongolTextPainter` — 文本布局和绘制引擎
- `MongolTextAlign` — 垂直对齐枚举（`top`、`center`、`bottom`、`justify`）
- `mapHorizontalToMongolTextAlign()` — 将 Flutter `TextAlign` 映射为 `MongolTextAlign`

## 与可选择文本的对比

| 特性 | MongolText | MongolRichText | MongolSelectableText |
|------|-----------|---------------|---------------------|
| 显示文本 | ✅ | ✅ | ✅ |
| 只读 | ✅ | ✅ | ✅ |
| 可选择 | ❌ | ❌ | ✅ |
| 可复制 | ❌ | ❌ | ✅ |
| 富文本 | ✅（.rich） | ✅ | ✅ |
| DefaultTextStyle 继承 | ✅ | ❌ | ✅ |
| 上下文菜单 | ❌ | ❌ | ✅ |

## 测试

相关测试文件：

- `test/mongol_text_widget_test.dart` — MongolText 组件测试
- `test/mongol_rich_text_widget_test.dart` — MongolRichText 组件测试（文本内容、尺寸、换行行为）

## 相关组件

- **[MongolText](../text/README.md)**：具有纵向布局的文本渲染
- **[MongolTextFormField](../editing/README.md)**：用于对话框表单的文本输入
- **[MongolList](../list/README.md)**：用于创建对话框列表
- **[MongolButton](../button/README.md)**：对话框操作的标准按钮