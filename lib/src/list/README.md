# Mongol List Components

本目录提供蒙古文竖排场景下的 ListTile 组件族，基于 Flutter Material 组件行为实现，并适配竖排布局。

## 目录结构

- `mongol_list_tile.dart`：基础列表项组件与布局/渲染实现。
- `mongol_checkbox_list_tile.dart`：带复选框的列表项。
- `mongol_radio_list_tile.dart`：带单选按钮的列表项。
- `mongol_switch_list_tile.dart`：带开关的列表项。

## 何时使用

- 使用 `MongolListTile`：仅需要标题/副标题 + 前后置内容的通用列表项。
- 使用 `MongolCheckboxListTile`：多选场景。
- 使用 `MongolRadioListTile<T>`：单选分组场景。
- 使用 `MongolSwitchListTile`：开关布尔状态场景。

## 快速示例

### 1) 基础列表项

```dart
MongolListTile(
  title: const MongolText('基础项'),
  subtitle: const MongolText('支持副标题'),
  leading: const Icon(Icons.label_outline),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {},
)
```

### 2) 复选框列表项

```dart
bool checked = true;

MongolCheckboxListTile(
  value: checked,
  onChanged: (bool? value) {
    checked = value ?? false;
  },
  title: const MongolText('接收通知'),
)
```

### 3) 单选列表项

```dart
enum FontSizeOption { small, medium, large }

FontSizeOption selected = FontSizeOption.medium;

MongolRadioListTile<FontSizeOption>(
  value: FontSizeOption.large,
  groupValue: selected,
  onChanged: (FontSizeOption? value) {
    if (value != null) selected = value;
  },
  title: const MongolText('大号字体'),
)
```

### 4) 开关列表项

```dart
bool enabled = false;

MongolSwitchListTile(
  value: enabled,
  onChanged: (bool value) {
    enabled = value;
  },
  title: const MongolText('启用实验特性'),
)
```

## 通用参数说明

- `title` / `subtitle`：主要文本与补充文本。
- `secondary`：与控制器相对一侧的组件（通常是图标）。
- `controlAffinity`：控制器放在前侧或后侧。
- `isThreeLine`：三行模式（`subtitle` 需非空）。
- `dense` / `visualDensity`：控制布局紧凑度。
- `contentPadding`：内容内边距。
- `selected`：是否以选中样式渲染文本与图标。
- `tileColor` / `selectedTileColor`：背景颜色。
- `onChanged`：交互回调；为 `null` 时显示禁用态。

## 使用建议

- 将状态保存在父组件中，通过 `onChanged` 更新，再触发重建。
- 若需要背景色生效，确保上层有 `Material`（通常由 `Scaffold` 提供）。
- 大量列表项尽量共享 `Material` 祖先，避免逐项包裹造成额外开销。
- 含可点击富文本等复杂语义需求时，可自定义组合组件以避免语义合并冲突。

## 主题与样式

- 通过 `MongolListTileTheme` / `MongolListTileThemeData` 统一配置样式。
- `MongolListTile` 内部根据 Material 2 / Material 3 选择默认值。
- 交互状态颜色按 `WidgetState` 解析，支持 selected/disabled 等状态。

## 与 menu/text 组件联动示例

下面示例演示三个组件如何联动：

- `MongolPopupMenuButton`：用于切换文本大小与行数模式。
- `MongolText`：作为列表标题和副标题文本组件。
- `MongolListTile`：根据 menu 选择结果实时刷新展示。

```dart
import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart';

enum TextScalePreset { small, medium, large }

class ListMenuTextDemo extends StatefulWidget {
  const ListMenuTextDemo({super.key});

  @override
  State<ListMenuTextDemo> createState() => _ListMenuTextDemoState();
}

class _ListMenuTextDemoState extends State<ListMenuTextDemo> {
  TextScalePreset _preset = TextScalePreset.medium;
  bool _threeLine = false;

  double get _titleSize {
    switch (_preset) {
      case TextScalePreset.small:
        return 14;
      case TextScalePreset.medium:
        return 16;
      case TextScalePreset.large:
        return 18;
    }
  }

  double get _subtitleSize {
    switch (_preset) {
      case TextScalePreset.small:
        return 12;
      case TextScalePreset.medium:
        return 14;
      case TextScalePreset.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List + Menu + Text Demo'),
        actions: <Widget>[
          MongolPopupMenuButton<String>(
            onSelected: (String action) {
              setState(() {
                if (action == 'small') _preset = TextScalePreset.small;
                if (action == 'medium') _preset = TextScalePreset.medium;
                if (action == 'large') _preset = TextScalePreset.large;
                if (action == 'toggle-lines') _threeLine = !_threeLine;
              });
            },
            itemBuilder: (BuildContext context) => <MongolPopupMenuEntry<String>>[
              const MongolPopupMenuItem<String>(
                value: 'small',
                child: MongolText('小字'),
              ),
              const MongolPopupMenuItem<String>(
                value: 'medium',
                child: MongolText('中字'),
              ),
              const MongolPopupMenuItem<String>(
                value: 'large',
                child: MongolText('大字'),
              ),
              const MongolPopupMenuDivider(),
              MongolPopupMenuItem<String>(
                value: 'toggle-lines',
                child: MongolText(_threeLine ? '切换为两行' : '切换为三行'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          MongolListTile(
            title: MongolText(
              '标题文本',
              style: TextStyle(fontSize: _titleSize),
            ),
            subtitle: MongolText(
              '副标题会跟随菜单设置更新字号和行数展示。',
              style: TextStyle(fontSize: _subtitleSize),
              maxLines: _threeLine ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: _threeLine,
            leading: const Icon(Icons.text_fields),
            trailing: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}
```

联动要点：

- menu 回调里只更新状态，不直接操作子组件。
- text 样式通过状态派生，避免在 build 中写分散分支。
- list 只消费最终状态（字号、行数模式），结构更清晰、易维护。

## 相关组件

- **[MongolText](../text/README.md)**：具有纵向布局的文本渲染
- **[MongolTextFormField](../editing/README.md)**：用于对话框表单的文本输入
- **[MongolList](../list/README.md)**：用于创建对话框列表
- **[MongolButton](../button/README.md)**：对话框操作的标准按钮