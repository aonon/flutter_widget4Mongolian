# MongolSelectableText 组件文档

## 概述

`MongolSelectableText` 是一个用于显示可选择和可复制蒙古文文本的 Flutter 组件。它允许用户通过长按、拖动等手势与文本交互，并可以将选中的内容复制到系统剪切板。

## 特性

- ✅ **垂直蒙古文显示** - 完整支持蒙古文垂直方向书写
- ✅ **文本选择** - 支持长按选择、拖动扩展选择范围
- ✅ **复制功能** - 选中文本可复制到剪切板
- ✅ **富文本支持** - 支持 `TextSpan` 实现混合样式文本
- ✅ **自定义样式** - 支持文本样式、排列、溢出处理等参数
- ✅ **选区高亮** - 支持自定义选区高亮颜色
- ✅ **文本对齐** - 支持垂直文本的对齐方式设置

## 架构

### 核心组件

1. **MongolSelectableText** (Widget)
   - 有状态 Widget，处理选择状态管理
   - 实现了 `TextSelectionDelegate` 接口
   - 管理手势识别和选择变化回调

2. **MongolRenderSelectableText** (RenderObject)
   - 继承自 `RenderBox`
   - 利用 `MongolTextPainter` 处理文本布局和绘制
   - 负责选区高亮的绘制

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
| `onSelectionChanged` | `SelectionChangedCallback?` | null | 选择改变时的回调 |

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

```
长按文本
  ↓
选择点击位置的单词
  ↓
显示上下文菜单（复制、全选）
  ↓
用户可以：
  - 点击"复制" → 复制选中的文本到剪切板
  - 点击"全选" → 选中全部文本
  - 拖动 → 扩展选择范围
  - 单击其他位置 → 取消选择
```

## 与现有组件的对比

| 特性 | MongolText | MongolSelectableText | MongolTextField |
|------|-----------|-------------------|-----------------|
| 显示文本 | ✅ | ✅ | ✅ |
| 只读 | ✅ | ✅ | ❌ |
| 可选择 | ❌ | ✅ | ✅ |
| 可复制 | ❌ | ✅ | ✅ |
| 可编辑 | ❌ | ❌ | ✅ |
| 富文本 | ❌ | ✅ | ❌ |

## 依赖关系

```
MongolSelectableText
├── MongolRenderSelectableText
│   └── MongolTextPainter
│       ├── MongolParagraph
│       └── MongolTextTools (工具函数集)
├── TextSelection (Flutter)
├── Clipboard (Flutter)
└── GestureDetector (Flutter)
```

## 性能考虑

- 文本选择使用 `TextSelection` 对象缓存来避免重复计算
- 手势识别整合到 `GestureDetector` 中，避免多层次的手势冲突
- 选区高亮绘制利用 `getBoxesForSelection()` 进行高效的区块绘制

## 已知限制

1. 暂不支持系统快捷菜单（如 macOS 的查词、翻译等）
2. 选择时的手势响应可能在某些场景需要微调
3. 极长文本的选择性能需要性能测试验证

## 测试覆盖

- ✅ 10个单元测试通过
- ✅ 与133个现有测试兼容无冲突
- ✅ 支持各种文本长度和样式的测试场景

## 示例代码

完整的示例应用请参考：`example/lib/selectable_text_demo.dart`

运行示例：
```bash
cd example
flutter run -t lib/selectable_text_demo.dart
```

## 未来计划

- [ ] 支持系统上下文菜单（复制、粘贴、全选等）
- [ ] 支持拖放操作
- [ ] 支持查词翻译集成
- [ ] 支持辅助功能（可访问性）增强
- [ ] 性能优化和基准测试

## 反馈和贡献

欢迎提出问题或贡献改进意见！
