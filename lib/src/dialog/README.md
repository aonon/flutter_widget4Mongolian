# 对话框组件

用于在垂直蒙古文文本布局中显示模态内容的对话框组件。这些组件为针对垂直文本呈现进行调整的警告、确认和自定义模态交互界面提供了基础。

## 组件概述

### MongolDialog
一个基础对话框容器，具有可自定义的样式。作为其他对话框类型的基础，也可直接用于自定义模态内容。

**主要特性：**
- 可配置的背景颜色和阴影高度
- 支持自定义曲线的动画插入
- 支持自定义形状和布局
- 通过 `DialogTheme` 实现主题感知样式

**使用场景：** 需要一个空白模态容器来构建自定义对话框，或需要更多控制对话框外观时。

### MongolAlertDialog
标准警告对话框，包含标题、内容和操作按钮。遵循沿用于纵向布局的 Material Design 约正。

**主要特性：**
- 有可选内边距和文本样式的标题部分
- 具有灵活布局的内容区域
- 通过 `MongolButtonBar` 排列的操作按钮
- 基于内容的自动布局适配
- 主题感知文本样式

**使用场景：** 需要显示警告、确认，或待有标题、消息和操作按钮的简单对话框时。

### MongolButtonBar
纵向按钮栏，在列中排列按钮，当空间不足时自动回退到水平布局。

**主要特性：**
- 支持 MainAxisAlignment 选项的纵向按钮排列
- 自动处理水平溢出
- 可配置的按钮样式和间距
- 可自定义的布局行为（填充 vs 受限）
- 主题感知按钮大小

**使用场景：** 需要纵向排列多个操作按钮，特别是在对话框下部时。

## 快速开始

### 基础警告对话框

```dart
showDialog(
  context: context,
  builder: (context) => MongolAlertDialog(
    title: MongolText('确认'),
    content: MongolText('你确定吗？'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: MongolText('取消'),
      ),
      TextButton(
        onPressed: () {
          // 处理操作
          Navigator.pop(context);
        },
        child: MongolText('确定'),
      ),
    ],
  ),
);
```

### 使用 MongolDialog 的自定义对话框

```dart
showDialog(
  context: context,
  builder: (context) => MongolDialog(
    backgroundColor: Colors.white,
    child: Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MongolText('自定义内容'),
          SizedBox(height: 24.0),
          MongolButtonBar(
            children: [
              TextButton(child: MongolText('关闭'), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    ),
  ),
);
```

## 接口参考

### MongolDialog
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `key` | Key? | null | 组件键 |
| `backgroundColor` | Color? | 主题默认 | 对话框背景颜色 |
| `elevation` | double? | 24.0 | 阴影高度 |
| `insetAnimationDuration` | Duration | 100ms | 插入动画持续时间 |
| `insetAnimationCurve` | Curve | Curves.decelerate | 插入动画曲线 |
| `shape` | ShapeBorder? | RoundedRectangle(2.0) | 对话框边框形状 |
| `child` | Widget? | null | 对话框内容组件 |

### MongolAlertDialog
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `key` | Key? | null | 组件键 |
| `title` | Widget? | null | 标题组件（通常为 MongolText） |
| `titlePadding` | EdgeInsetsGeometry? | 24,24,24,0/20 | 标题内边距（取决于上下文） |
| `titleTextStyle` | TextStyle? | 主题默认 | 标题文本样式 |
| `content` | Widget? | null | 内容组件 |
| `contentPadding` | EdgeInsetsGeometry | 24,20,24,24 | 内容内边距 |
| `contentTextStyle` | TextStyle? | 主题默认 | 内容文本样式 |
| `actions` | List<Widget>? | null | 操作按钮 |
| `actionsPadding` | EdgeInsetsGeometry | EdgeInsets.zero | 操作部分内边距 |
| `actionsOverflowDirection` | VerticalDirection? | null | 按钮溢出方向提示 |
| `buttonPadding` | EdgeInsetsGeometry? | null | 单个按钮内边距 |
| `backgroundColor` | Color? | null | 对话框背景颜色 |
| `elevation` | double? | null | 阴影高度 |
| `shape` | ShapeBorder? | null | 对话框边框形状 |

### MongolButtonBar
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `key` | Key? | null | 组件键 |
| `alignment` | MainAxisAlignment? | MainAxisAlignment.end | 按钮对齐（end = 右/下校准） |
| `mainAxisSize` | MainAxisSize? | MainAxisSize.max | 可用空间处理 |
| `buttonTextTheme` | ButtonTextTheme? | ButtonTextTheme.primary | 按钮文本主题 |
| `buttonMinWidth` | double? | 36.0 | 最小按钮宽度 |
| `buttonHeight` | double? | 64.0 | 按钮高度 |
| `buttonPadding` | EdgeInsetsGeometry? | 8.0 纵向 | 按钮内边距 |
| `layoutBehavior` | ButtonBarLayoutBehavior? | ButtonBarLayoutBehavior.padded | 布局模式（填充或受限） |
| `children` | List<Widget> | [] | 要排列的按钮 |

## 常见模式

### 带描述的确认对话框

```dart
MongolAlertDialog(
  title: MongolText('删除项目'),
  content: MongolText('此操作无法撒销。继续吗？'),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: MongolText('取消'),
    ),
    TextButton(
      onPressed: () {
        // 删除项目
        Navigator.pop(context);
      },
      child: MongolText('删除'),
    ),
  ],
)
```

### 表单对话框

```dart
MongolAlertDialog(
  title: MongolText('设置'),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MongolTextFormField(
        label: '名称',
        controller: nameController,
      ),
      SizedBox(height: 16.0),
      MongolTextFormField(
        label: '邮箱',
        controller: emailController,
      ),
    ],
  ),
  actions: [
    TextButton(child: MongolText('取消'), onPressed: () => Navigator.pop(context)),
    TextButton(child: MongolText('保存'), onPressed: () => _saveSettings()),
  ],
)
```

### 多选操作对话框

```dart
MongolAlertDialog(
  title: MongolText('选择操作'),
  content: MongolText('你想做什么？'),
  actions: [
    TextButton(child: MongolText('选项 A'), onPressed: () => _handleA()),
    TextButton(child: MongolText('选项 B'), onPressed: () => _handleB()),
    TextButton(child: MongolText('选项 C'), onPressed: () => _handleC()),
    TextButton(child: MongolText('取消'), onPressed: () => Navigator.pop(context)),
  ],
)
```

## 与文本组件的相互揲推

### 与 MongolTextFormField 配合使用

对话框通常包裹文本输入字段以收集用户数据。对话框的纵向布局自然適应堆叠表单字段：

```dart
showDialog(
  context: context,
  builder: (context) => MongolAlertDialog(
    title: MongolText('个人资料更新'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MongolTextFormField(label: '名称', controller: nameCtrl),
        SizedBox(height: 16),
        MongolTextFormField(label: '个人简介', controller: bioCtrl, maxLines: 3),
      ],
    ),
    actions: [
      TextButton(child: MongolText('取消'), onPressed: () => Navigator.pop(context)),
      TextButton(child: MongolText('更新'), onPressed: () => _updateProfile()),
    ],
  ),
);
```

## 样式与主题

### 自定义主题

```dart
MongolAlertDialog(
  backgroundColor: Colors.grey[50],
  elevation: 16,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  contentTextStyle: TextStyle(fontSize: 16),
  contentPadding: EdgeInsets.all(24),
  title: MongolText('自定义样式对话框'),
  content: MongolText('此对话框使用自定义主题。'),
  actions: [
    TextButton(child: MongolText('确定'), onPressed: () => Navigator.pop(context)),
  ],
)
```

### 全局对话框主题

通过 `ThemeData` 全局应用对话框样式：

```dart
MaterialApp(
  theme: ThemeData(
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      elevation: 24,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  home: MyApp(),
)
```

## 最佳实践

1. **始终提供操作按钮**：用户应该有清晰的方式决刉对话框（取消、关闽、确定按钮）
2. **保持内容简洁**：对话框内容应该简短易扫描
3. **使用描述性标题**：使对话框的目的立即明确
4. **处理关闽操作**：始终为 `Navigator.pop()` 操作加入逻辑
5. **不过度嵌套**：不要过度打开对话框内的对话框
6. **尊重屏幕空间**：对于透简的内容，使用可滚动内容或分解为上值批次对话框
7. **测试不同屏幕尺寸**：确保对话框在各种设备尺寸上正常渲染

## 相关组件

- **[MongolText](../text/README.md)**：具有纵向布局的文本渲染
- **[MongolTextFormField](../editing/README.md)**：用于对话框表单的文本输入
- **[MongolList](../list/README.md)**：用于创建对话框列表
- **[MongolButton](../button/README.md)**：对话框操作的标准按钮
