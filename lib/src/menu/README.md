# Menu 组件使用指南

这份文档帮助你快速理解：

---

## 一、这个目录有什么

`lib/src/menu` 主要包含三部分能力：

1. `mongol_popup_menu.dart`
   - 蒙古文方向的弹出菜单体系
   - 包含按钮、菜单项、分隔线、复选菜单项、路由与定位逻辑

2. `mongol_tooltip.dart`
   - 蒙古文提示组件（Tooltip）
   - 支持长按与鼠标悬停触发

3. `mongol_intrinsic_height.dart`
   - 菜单内部使用的布局辅助组件
   - 一般作为实现细节，不建议业务代码直接依赖

---

## 二、先用哪个组件

大部分业务场景，优先从下面两个入口开始：

1. `MongolPopupMenuButton<T>`
   - 最常用
   - 适合放在按钮、更多操作图标旁边

2. `MongolTooltip`
   - 给图标或操作按钮增加说明文本
   - 桌面端悬停可见，移动端长按可见

如果你需要精确控制弹出位置（不是跟随按钮），可以使用 `showMongolMenu<T>()`。

---

## 三、快速上手示例

### 1) 弹出菜单按钮

```dart
enum MenuAction { copy, share, delete }

MongolPopupMenuButton<MenuAction>(
  tooltip: '更多操作',
  onSelected: (value) {
    switch (value) {
      case MenuAction.copy:
        // TODO: copy
        break;
      case MenuAction.share:
        // TODO: share
        break;
      case MenuAction.delete:
        // TODO: delete
        break;
    }
  },
  itemBuilder: (context) => const [
    MongolPopupMenuItem(
      value: MenuAction.copy,
      child: MongolText('复制'),
    ),
    MongolPopupMenuItem(
      value: MenuAction.share,
      child: MongolText('分享'),
    ),
    MongolPopupMenuDivider(),
    MongolPopupMenuItem(
      value: MenuAction.delete,
      child: MongolText('删除'),
    ),
  ],
)
```

### 2) 带勾选状态的菜单项

```dart
MongolCheckedPopupMenuItem<Mode>(
  value: Mode.vertical,
  checked: currentMode == Mode.vertical,
  child: const MongolText('纵向模式'),
)
```

### 3) Tooltip

```dart
const MongolTooltip(
  message: '打开菜单',
  child: Icon(Icons.more_horiz),
)
```

---

## 四、核心 API 速览

### `MongolPopupMenuButton<T>`

- `itemBuilder`：返回菜单条目列表（必填）
- `onSelected`：用户选择后回调
- `onCanceled`：菜单关闭但未选择时回调
- `initialValue`：菜单打开时高亮指定值
- `enabled`：是否可交互

### `MongolPopupMenuItem<T>`

- `value`：选中后返回值
- `enabled`：是否禁用
- `child`：显示内容（常用 `MongolText`）

### `MongolTooltip`

- `message`：提示文案（必填）
- `waitDuration`：悬停多久后显示
- `showDuration`：长按释放后继续显示多久
- `preferRight`：优先显示在目标右侧
- `horizontalOffset`：提示与目标的横向间距

---

## 五、常见用法建议

1. 菜单值类型统一
   - 一个菜单里建议只使用一种泛型类型 `T`（比如统一用 enum）。

2. 菜单文案尽量短
   - 弹出菜单更适合短操作词，过长文案会影响可读性和布局稳定性。

3. 优先使用 `MongolText`
   - 在蒙古文场景中，菜单项文本优先使用 `MongolText`，保持排版一致。

4. Tooltip 文案偏说明，不放业务信息
   - Tooltip 适合“这个按钮做什么”，不适合承载复杂说明。

---

## 六、你可以参考的 Demo

在示例工程中可直接查看：

- `example/lib/demos/popup_menu_demo.dart`

如果你从 `example/lib/main.dart` 进入，列表中的 `Popup Menu` 就是对应入口。

---

## 七、何时用 `showMongolMenu<T>()`

当你遇到以下情况时，建议改用 `showMongolMenu<T>()`：

1. 菜单触发点不是一个标准按钮
2. 需要你自己控制弹出位置
3. 需要在手势事件里按坐标打开菜单

否则，默认使用 `MongolPopupMenuButton<T>` 会更简单。
