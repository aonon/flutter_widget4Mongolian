# editing 模块文档

## 概述

`lib/src/editing` 是蒙古文垂直文本输入系统的核心模块，提供了从底层渲染到高层 Material 组件的完整垂直文本编辑能力。最顶层的 `MongolTextField` 是面向用户的主入口，其内部由 `MongolInputDecorator`、`MongolEditableText`、`MongolRenderEditable` 四层架构依次协作完成文本输入的全流程。

## 特性

- ✅ **垂直蒙古文输入** — 完整支持蒙古文垂直方向书写和编辑
- ✅ **Material 风格装饰** — 支持标签、占位符、错误提示、计数器、前缀/后缀图标
- ✅ **多种边框样式** — 内置 `SidelineInputBorder`（右侧竖线）与 `MongolOutlineInputBorder`（圆角矩形）
- ✅ **光标与选区** — 可定制光标颜色、宽度、高度，支持选区高亮
- ✅ **密码输入** — `obscureText` 支持内容遮盖
- ✅ **只读模式** — `readOnly` 支持只读展示
- ✅ **输入校验与格式化** — 支持 `TextInputFormatter` 列表
- ✅ **字符计数** — 内置 `maxLength` 计数器，支持自定义计数构建器
- ✅ **键盘快捷键** — 上下键字符导航、左右键行间导航，支持 Shift/Alt/Ctrl 修饰键选区扩展
- ✅ **上下文菜单** — 支持剪切、复制、粘贴、全选，支持自定义菜单构建器
- ✅ **桌面与移动平台** — 适配鼠标指针、右键菜单、触摸选择手柄
- ✅ **水平对齐** — `TextAlignHorizontal` 控制文本在输入区域内的横向位置

## 架构

### 层级结构

```
MongolTextField          ← 高层 Material 组件（面向用户）
    └── MongolInputDecorator  ← 装饰层（标签/边框/图标）
            └── MongolEditableText  ← 核心编辑层（光标/选区/键盘）
                    └── MongolRenderEditable  ← 渲染层（绘制文本/光标/高亮）
```

### 支撑模块

| 模块 | 说明 |
|------|------|
| `input_border.dart` | 自定义边框：`SidelineInputBorder`、`MongolOutlineInputBorder` |
| `alignment.dart` | `TextAlignHorizontal`：输入区域横向对齐 |
| `mongol_text_editing_shortcuts.dart` | 键盘快捷键绑定 Widget |
| `mongol_text_editing_intents.dart` | 选区操作的 Intent 类 |
| `mongol_toolbar_options.dart` | 上下文工具栏选项配置 |
| `text_editing_controller_extension.dart` | `TextEditingController` 工具扩展 |
| `platform_utils.dart` | 平台检测工具函数 |
| `text_selection/` | 选择手柄、工具栏、布局代理 |
| `mongol_mouse_cursors*.dart` | 垂直文本鼠标指针 |

## 基础用法

### 简单输入框

```dart
import 'package:mongol/mongol.dart';

MongolTextField(
  decoration: InputDecoration(
    labelText: '请输入',
    hintText: '蒙古文...',
  ),
  onChanged: (value) {
    print('输入内容：$value');
  },
)
```

### 带控制器

```dart
final controller = TextEditingController();

MongolTextField(
  controller: controller,
  style: TextStyle(fontSize: 18),
  maxLines: 5,
)
```

### 密码输入

```dart
MongolTextField(
  obscureText: true,
  decoration: InputDecoration(labelText: '密码'),
)
```

### 只读模式

```dart
MongolTextField(
  readOnly: true,
  controller: TextEditingController(text: '只读文本'),
)
```

## 属性

### MongolTextField 主要属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `controller` | `TextEditingController?` | null（自动创建） | 控制文本内容和选区 |
| `focusNode` | `FocusNode?` | null（自动创建） | 管理键盘焦点 |
| `decoration` | `InputDecoration?` | 默认装饰 | 标签、提示、图标、边框等装饰 |
| `style` | `TextStyle?` | null | 文本样式 |
| `textAlign` | `MongolTextAlign` | `MongolTextAlign.top` | 垂直对齐方式 |
| `textAlignHorizontal` | `TextAlignHorizontal?` | null | 文本在输入区域内的横向对齐 |
| `maxLines` | `int?` | 1 | 最大行数（null=无限制） |
| `minLines` | `int?` | null | 最小行数 |
| `maxLength` | `int?` | null | 最大字符数（显示计数器） |
| `obscureText` | `bool` | false | 是否隐藏输入内容（密码框） |
| `readOnly` | `bool` | false | 是否只读 |
| `enabled` | `bool?` | null | 是否启用输入框 |
| `cursorColor` | `Color?` | null | 光标颜色 |
| `cursorHeight` | `double?` | null | 光标高度 |
| `cursorWidth` | `double` | 2.0 | 光标宽度 |
| `inputFormatters` | `List<TextInputFormatter>?` | null | 输入格式化/校验器列表 |
| `onChanged` | `ValueChanged<String>?` | null | 文本变化回调 |
| `onEditingComplete` | `VoidCallback?` | null | 编辑完成回调 |
| `onSubmitted` | `ValueChanged<String>?` | null | 提交（回车）回调 |
| `buildCounter` | `InputCounterWidgetBuilder?` | null | 自定义字符计数器构建器 |
| `toolbarOptions` | `MongolToolbarOptions?` | null | 上下文菜单选项配置 |
| `contextMenuBuilder` | `EditableTextContextMenuBuilder?` | null | 自定义上下文菜单构建器 |

## 输入框装饰

`MongolTextField` 使用标准 Flutter `InputDecoration`，通过 `MongolInputDecorator` 渲染装饰内容。

```dart
MongolTextField(
  decoration: InputDecoration(
    labelText: '姓名',
    hintText: '请输入蒙古文姓名',
    errorText: '不能为空',
    prefixIcon: Icon(Icons.person),
    suffixIcon: Icon(Icons.check),
    counterText: '0/20',
    border: InputBorder.none,
  ),
)
```

## 边框

### SidelineInputBorder（右侧竖线）

适用于简洁的下划线风格（垂直布局下为右侧线）。

```dart
MongolTextField(
  decoration: InputDecoration(
    border: SidelineInputBorder(
      borderSide: BorderSide(color: Colors.blue, width: 2),
    ),
  ),
)
```

### MongolOutlineInputBorder（圆角矩形）

适用于有边框的输入框。

```dart
MongolTextField(
  decoration: InputDecoration(
    border: MongolOutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey),
    ),
  ),
)
```

## 键盘快捷键

用 `MongolTextEditingShortcuts` 包裹 `MaterialApp`，为应用内所有蒙古文输入框启用正确的键盘导航：

```dart
MongolTextEditingShortcuts(
  child: MaterialApp(
    home: MyHomePage(),
  ),
)
```

### 快捷键映射

| 按键 | 行为 |
|------|------|
| ↑ / ↓ | 按字符向前/后移动光标 |
| ← / → | 跨行移动光标 |
| Shift + 方向键 | 扩展选区 |
| Alt + ↑/↓ | 按词移动 |
| Ctrl/Cmd + ↑/↓ | 移动至行首/行尾 |
| Ctrl/Cmd + ←/→ | 移动至文档首/尾 |

## 工具栏选项

`MongolToolbarOptions` 控制上下文菜单中显示哪些操作：

```dart
MongolTextField(
  toolbarOptions: MongolToolbarOptions(
    copy: true,
    cut: true,
    paste: true,
    selectAll: true,
  ),
)
```

预定义常量：

| 常量 | 说明 |
|------|------|
| `kMongolToolbarReadOnly` | 只读模式：仅复制、全选 |
| `kMongolToolbarEditableObscure` | 密码模式：仅粘贴、全选 |
| `kMongolToolbarEditableAll` | 可编辑模式：全部操作 |

## 扩展与工具

### TextAlignHorizontal

控制文本在输入区域内的横向位置：

```dart
MongolTextField(
  textAlignHorizontal: TextAlignHorizontal.center, // -1.0=左, 0.0=中, 1.0=右
)
```

### TextEditingControllerExtension

验证选区是否在文本范围内：

```dart
final isValid = controller.isSelectionWithinTextBounds(selection);
```

### platform_utils

内部平台检测函数，供平台差异化行为使用：

```dart
isDesktopPlatform(platform); // macOS / Linux / Windows → true
isApplePlatform(platform);   // iOS / macOS → true
```

## 目录结构

```
lib/src/editing/
├── mongol_text_field.dart               # 高层 Material 输入组件
├── mongol_text_field/
│   ├── widget.dart                      # MongolTextField StatefulWidget
│   ├── state.dart                       # MongolTextField State
│   └── selection_gesture_detector_builder.dart
├── mongol_input_decorator.dart          # 输入框装饰层
├── mongol_input_decorator/
│   ├── widget.dart                      # MongolInputDecorator
│   ├── render_decoration.dart           # 装饰渲染对象
│   ├── border_and_helper_widgets.dart   # 边框与 helper 文字组件
│   └── defaults.dart                    # 默认样式常量
├── mongol_editable_text.dart            # 核心编辑 Widget
├── mongol_editable_text/
│   ├── widget.dart                      # MongolEditableText
│   ├── state.dart                       # MongolEditableTextState
│   ├── actions.dart                     # 文本编辑 Action 处理
│   ├── history.dart                     # 撤销/重做历史
│   ├── render_widget.dart               # 渲染 Widget 构建
│   ├── text_boundaries.dart             # 文本边界计算
│   └── types_and_simulation.dart        # 类型定义与模拟
├── mongol_render_editable.dart          # 渲染层入口
├── mongol_render_editable/
│   ├── render_editable.dart             # MongolRenderEditable
│   ├── caret_painter.dart               # 光标绘制
│   ├── text_highlight_painter.dart      # 选区高亮绘制
│   ├── composite_painter.dart           # 合成绘制器
│   ├── custom_paint_render_box.dart     # 自定义绘制容器
│   └── horizontal_caret_movement_run.dart
├── input_border.dart                    # SidelineInputBorder / MongolOutlineInputBorder
├── alignment.dart                       # TextAlignHorizontal
├── mongol_text_editing_shortcuts.dart   # 键盘快捷键 Widget
├── mongol_text_editing_intents.dart     # 选区操作 Intent 类
├── mongol_toolbar_options.dart          # 上下文工具栏配置
├── text_editing_controller_extension.dart  # TextEditingController 扩展
├── platform_utils.dart                  # 平台检测工具
├── mongol_mouse_cursors.dart            # 鼠标指针（统一入口）
├── mongol_mouse_cursors_native.dart     # 原生平台鼠标指针
├── mongol_mouse_cursors_web.dart        # Web 平台鼠标指针
├── web_text_cursor_helper.dart          # Web 文本光标辅助（统一入口）
├── web_text_cursor_helper_stub.dart     # 非 Web 平台桩实现
├── web_text_cursor_helper_web.dart      # Web 平台实现
└── text_selection/
    ├── mongol_text_selection.dart                   # 选择控制器
    ├── mongol_text_selection_controls.dart          # 选择手柄与工具栏控制
    ├── mongol_text_selection_toolbar.dart           # 工具栏 Widget
    ├── mongol_text_selection_toolbar_button.dart    # 工具栏按钮
    ├── mongol_text_selection_toolbar_layout_delegate.dart  # 工具栏布局代理
    └── mongol_text_selection/                       # 选择内部实现
```
## 相关组件

- **[MongolText](../text/README.md)**：具有纵向布局的文本渲染
- **[MongolTextFormField](../editing/README.md)**：用于对话框表单的文本输入
- **[MongolList](../list/README.md)**：用于创建对话框列表
- **[MongolButton](../button/README.md)**：对话框操作的标准按钮