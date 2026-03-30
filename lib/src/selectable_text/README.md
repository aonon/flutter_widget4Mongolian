# MongolSelectableText 组件文档

## 概述

`MongolSelectableText` 是一个用于显示可选择和可复制蒙古文文本的 Flutter 组件。它基于只读 `MongolTextField` 实现，复用系统文本选择与上下文菜单。支持 Web、桌面（Windows/macOS/Linux）和移动平台。

## 特性

- ✅ **垂直蒙古文显示** — 完整支持蒙古文垂直方向书写
- ✅ **文本选择** — 支持长按选择、拖动扩展选择范围
- ✅ **复制功能** — 选中文本可复制到剪切板
- ✅ **富文本支持** — 支持 `TextSpan` 实现混合样式文本
- ✅ **上下文菜单** — 选中文本后自动弹出"全选"和"复制"菜单，支持自定义菜单构建器
- ✅ **自定义样式** — 支持文本样式、对齐、溢出处理等参数
- ✅ **选区高亮** — 支持自定义选区高亮颜色
- ✅ **桌面平台支持** — 鼠标指针为竖排文本光标、选择手柄可鼠标拖动、右键弹出上下文菜单
- ✅ **Web 平台支持** — 浏览器右键菜单已禁用以避免冲突，使用自定义上下文菜单
- ✅ **多实例互斥选区** — 同一页面多个 `MongolSelectableText` 实例时，新选区自动取消旧选区

## 架构

### 核心组件

1. **MongolSelectableText** (`StatefulWidget`)
   - 有状态 Widget，管理选区状态和焦点
   - 通过 `TextEditingController` 跟踪选区变化
   - 使用静态 `ValueNotifier` 实现多实例间选区互斥
   - 内部构建只读 `MongolTextField`

2. **MongolTextField**（底层组件）
   - 以 `readOnly: true`、`showCursor: false` 配置为只读模式
   - 提供手势识别、选择手柄、上下文菜单等交互能力
   - 通过 `MongolEditableText` → `MongolRenderEditable` 完成文本布局和绘制

## 基础用法

### 简单文本

```dart
import 'package:mongol/mongol.dart';

MongolSelectableText(
  '你好，世界！',
  style: TextStyle(fontSize: 18),
)
```

### 富文本

```dart
MongolSelectableText.rich(
  TextSpan(
    text: '蒙古文',
    style: TextStyle(fontWeight: FontWeight.bold),
    children: [
      TextSpan(text: '是一种美丽的语言'),
    ],
  ),
)
```

## 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `data` | `String?` | null | 显示的简单文本 |
| `textSpan` | `TextSpan?` | null | 显示的富文本 |
| `style` | `TextStyle?` | null | 文本样式 |
| `textAlign` | `MongolTextAlign` | `MongolTextAlign.top` | 垂直对齐方式 |
| `textScaleFactor` | `double` | 1.0 | 文本缩放因子 |
| `maxLines` | `int?` | null | 最大行数（null=无限制） |
| `softWrap` | `bool` | true | 是否在软换行处换行 |
| `overflow` | `TextOverflow` | `TextOverflow.clip` | 溢出处理方式 |
| `rotateCJK` | `bool` | true | CJK字符是否旋转90度 |
| `selectionColor` | `Color` | 蓝色(64%) | 选区高亮颜色 |
| `controller` | `TextEditingController?` | null | 外部文本控制器 |
| `onSelectionChanged` | `SelectionChangedCallback?` | null | 选择改变时的回调 |
| `contextMenuBuilder` | `MongolEditableTextContextMenuBuilder?` | null | 自定义上下文菜单构建器 |

## 高级用法

### 自定义选区颜色

```dart
MongolSelectableText(
  '自定义选区颜色的文本',
  selectionColor: Colors.green.withOpacity(0.4),
)
```

### 选择变化回调

```dart
MongolSelectableText(
  '响应选择变化',
  onSelectionChanged: (selection, cause) {
    print('选中范围：${selection.start}-${selection.end}');
    print('原因：$cause');
  },
)
```

### 自定义上下文菜单

```dart
MongolSelectableText(
  '自定义菜单的文本',
  contextMenuBuilder: (context, editableTextState) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: '复制',
          onPressed: () {
            editableTextState.copySelection(SelectionChangedCause.toolbar);
          },
        ),
      ],
    );
  },
)
```

### 自定义样式组合

```dart
MongolSelectableText.rich(
  TextSpan(
    children: [
      TextSpan(
        text: '蒙古文',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      TextSpan(
        text: '文本库',
        style: TextStyle(
          fontSize: 18,
          color: Colors.red,
        ),
      ),
    ],
  ),
  textAlign: MongolTextAlign.center,
  maxLines: 5,
)
```

## 交互流程

### 移动端（Android / iOS）
```
长按文本 → 选择单词 → 显示上下文菜单（复制、全选）
拖动选择手柄 → 扩展选择范围
单击其他位置 → 取消选择
```
### Web
```
鼠标悬停 → 显示竖排文本光标
点击拖动 → 选择文本范围 → 自动弹出上下文菜单
右键点击 → 弹出上下文菜单（复制、全选）
拖动选择手柄 → 扩展选择范围（支持鼠标拖动）
Ctrl+C → 复制选中文本
Ctrl+A → 全选
浏览器默认右键菜单已自动禁用
```
### 桌面端（Windows / macOS / Linux）
```
交互行为与移动端一致

```

## 与现有组件的对比

| 特性 | MongolText | MongolRichText | MongolSelectableText | MongolTextField |
|------|-----------|---------------|---------------------|-----------------|
| 显示文本 | ✅ | ✅ | ✅ | ✅ |
| 只读 | ✅ | ✅ | ✅ | 可配置 |
| 可选择 | ❌ | ❌ | ✅ | ✅ |
| 可复制 | ❌ | ❌ | ✅ | ✅ |
| 可编辑 | ❌ | ❌ | ❌ | ✅ |
| 富文本 | ❌ | ✅ | ✅ | ❌ |
| 上下文菜单 | ❌ | ❌ | ✅ | ✅ |

## 依赖关系

```
MongolSelectableText (StatefulWidget)
├── MongolTextField (readOnly: true)
│   ├── MongolEditableText
│   │   └── MongolRenderEditable
│   │       └── MongolTextPainter
│   │           ├── MongolParagraph
│   │           └── MongolTextTools
│   └── MongolTextSelectionGestureDetectorBuilder
│       └── 选择手柄 / 上下文菜单
├── TextEditingController (Flutter)
├── FocusNode (Flutter)
└── ValueNotifier (多实例选区互斥)
```

## 已知限制

1. 暂不支持系统级快捷菜单集成（如 macOS 的查词、翻译等）
2. 极长文本的选择性能需要进一步测试验证

## 示例代码

完整的示例应用请参考：`example/lib/selectable_text_demo.dart`

运行示例：
```bash
cd example
flutter run -t lib/selectable_text_demo.dart
```

## 未来计划

- [ ] 支持系统级上下文菜单集成（macOS 查词、翻译等）
- [ ] 支持拖放操作
- [ ] 支持辅助功能（可访问性）增强

## 反馈和贡献

欢迎提出问题或贡献改进意见！
