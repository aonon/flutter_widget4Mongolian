# 垂直蒙古文按钮组件

## 概述

`lib/src/button/` 目录包含了一系列符合 Material Design 规范的垂直方向按钮组件。这些组件主要用于在垂直蒙古文布局中提供一致的交互体验。这些类分别对应 Flutter 框架中的 `ElevatedButton`、`FilledButton`、`OutlinedButton`、`TextButton` 和 `IconButton`，但针对垂直布局进行了优化。

## 特性

- ✅ **垂直布局优化** — 按钮内容（图标和标签）垂直堆叠排列。
- ✅ **Material 3 支持** — 默认支持最新的 Material 3 设计语言，包括 `Filled` 和 `Filled Tonal` 变体。
- ✅ **智能 VisualDensity** — 针对蒙古文垂直排版调整了 `VisualDensity` 逻辑（防止因密度调整导致上下间距过度压缩）。
- ✅ **丰富的变体支持** — 提供 `Elevated`、`Filled`、`Outlined` 和 `Text` 四种基础风格。
- ✅ **垂直 Tooltip** — `MongolIconButton` 自动集成了支持垂直文本显示的 `MongolTooltip`。
- ✅ **高度可定制** — 所有按钮均支持通过 `ButtonStyle` 或便捷的 `styleFrom` 静态方法进行自定义。

## 架构

### 组件层次

```
MongolButtonStyleButton (StatefulWidget)
  ├── MongolElevatedButton
  ├── MongolFilledButton
  ├── MongolOutlinedButton
  └── MongolTextButton

IconButton (Flutter 原生)
  └── MongolIconButton (内置 MongolTooltip 支持)
```

### 与 Flutter 框架对应关系

| 本库组件 | Flutter 对应 | 基类 |
|---------|-------------|------|
| `MongolButtonStyleButton` | `ButtonStyleButton` | `StatefulWidget` |
| `MongolElevatedButton` | `ElevatedButton` | `MongolButtonStyleButton` |
| `MongolFilledButton` | `FilledButton` | `MongolButtonStyleButton` |
| `MongolOutlinedButton` | `OutlinedButton` | `MongolButtonStyleButton` |
| `MongolTextButton` | `TextButton` | `MongolButtonStyleButton` |
| `MongolIconButton` | `IconButton` | `IconButton` |

## 文件说明

1. **mongol_button_style_button.dart**
   - 所有样式按钮的抽象基类。
   - 核心逻辑：在渲染时调整了 `VisualDensity` 的应用方式，确保在垂直布局下按钮的上下内边距不会被错误地缩小。

2. **mongol_elevated_button.dart**
   - 垂直方向的“凸起按钮”。
   - 适用于需要强调操作深度和层次感的场景。
   - 提供 `MongolElevatedButton.icon()` 构造函数。

3. **mongol_filled_button.dart**
   - 垂直方向的“填充按钮”。
   - 包含标准填充（`Filled`）和色调填充（`Tonal`）两种变体。
   - 提供最强的视觉冲击力，适用于“保存”、“确认”等核心操作。

4. **mongol_outlined_button.dart**
   - 垂直方向的“轮廓按钮”。
   - 带有边框但通常无背景填充，提供中等程度的强调。

5. **mongol_text_button.dart**
   - 垂直方向的“文本按钮”。
   - 无边框和背景填充，适用于对话框操作、工具栏等低强调场景。

6. **mongol_icon_button.dart**
   - 针对垂直布局优化的图标按钮。
   - 内部集成了 `MongolTooltip`，确保在长按或鼠标悬停时显示的提示信息符合蒙古文垂直阅读习惯。

## 常用属性

| 属性 | 说明 |
|------|------|
| `onPressed` | 按钮点击回调。为 null 时按钮处于禁用状态。 |
| `onLongPress` | 按钮长按回调。 |
| `style` | 自定义按钮样式。推荐使用 `ButtonClassName.styleFrom()` 构建。 |
| `child` | 按钮的内容小部件（通常是 `MongolText` 或包含图标的容器）。 |
| `statesController` | 控制和监听按钮交互状态（如按下、悬停、禁用）。 |

## 基础用法

### 简单文本按钮

```dart
MongolTextButton(
  onPressed: () { /* 点击逻辑 */ },
  child: MongolText('ᠮᠣᠩᠭᠣᠯ'),
)
```

### 填充按钮及其样式自定义

```dart
MongolFilledButton(
  onPressed: () {},
  style: MongolFilledButton.styleFrom(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  child: MongolText('ᠪᠠᠲᠤᠯᠠᠬᠤ'), // 确认
)
```

### 带图标的凸起按钮

```dart
MongolElevatedButton.icon(
  onPressed: () {},
  icon: Icon(Icons.add),
  label: MongolText('ᠨᠡᠮᠡᠬᠦ'), // 添加
)
```

### 图标按钮带提示

```dart
MongolIconButton(
  icon: Icon(Icons.settings),
  tooltip: 'ᠲᠣᠬᠢᠷᠠᠭᠤᠯᠭᠤ', // 设置
  onPressed: () {},
)
```

## 依赖关系

本目录组件可能依赖于以下内部模块：

- `lib/src/text/mongol_text.dart` — 常用于按钮的标签内容。
- `lib/src/menu/mongol_tooltip.dart` — 用于 `MongolIconButton` 的提示。

## 测试

相关测试文件（建议查阅以获取更多使用细节）：

- `test/button/mongol_elevated_button_test.dart`
- `test/button/mongol_filled_button_test.dart`
- `test/button/mongol_outlined_button_test.dart`
- `test/button/mongol_text_button_test.dart`
- `test/button/mongol_icon_button_test.dart`

## 相关组件

- **[MongolText](../text/README.md)**：垂直文本渲染的基础组件。
- **[MongolTooltip](../menu/README.md)**：支持垂直文本的工具提示。
- **[MongolInputDecorator](../editing/README.md)**：用于输入框的装饰组件，常与按钮配合使用。
