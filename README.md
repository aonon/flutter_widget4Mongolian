# mongol

这个库是一个 Flutter 小部件集合，用于显示传统蒙古文垂直文本。它提供了一系列专门为蒙古文垂直排版设计的小部件，使开发者能够轻松地在 Flutter 应用中实现蒙古文的正确显示和交互。

## 功能特点

- 支持传统蒙古文的垂直排版
- 提供与 Flutter 原生小部件对应的蒙古文版本
- 支持表情符号和 CJK 字符的正确旋转
- 跨平台兼容（移动、Web、桌面）
- 富文本样式和编辑功能
- 支持水平列表和菜单

## 主要小部件

- `MongolText`：`Text` 的垂直版本
- `MongolTextField`：`TextField` 的垂直版本
- `MongolListTile`：`ListTile` 的垂直版本，用于水平列表视图和菜单
- `MongolPopupMenuButton`：`PopupMenuButton` 的垂直版本，用于显示菜单
- `MongolAlertDialog`：`AlertDialog` 的垂直版本
- `MongolTextButton`、`MongolOutlinedButton`、`MongolElevatedButton` 等按钮组件
- `MongolCheckboxListTile`、`MongolRadioListTile`、`MongolSwitchListTile` 等列表组件

## 安装指南

### 从 Pub.dev 安装

要在您的 Flutter 项目中使用 mongol 库，请在 `pubspec.yaml` 文件中添加以下依赖：

```yaml
dependencies:
  mongol: ^9.2.1
```

然后运行 `flutter pub get` 来安装依赖。

### 作为本地库使用

如果您想将 mongol 库作为本地库使用，以便进行修改或调试，可以按照以下步骤操作：

1. **克隆仓库**：将 mongol 库克隆到您的本地机器上
   ```bash
   git clone https://github.com/suragch/mongol.git
   ```

2. **在您的项目中添加本地依赖**：在您的 Flutter 项目的 `pubspec.yaml` 文件中，使用 `path` 依赖指向本地克隆的 mongol 库
   ```yaml
   dependencies:
     mongol:
       path: /path/to/mongol
   ```
   请将 `/path/to/mongol` 替换为您本地 mongol 库的实际路径。

3. **运行 flutter pub get**：在您的项目目录中运行
   ```bash
   flutter pub get
   ```

4. **开始使用**：现在您可以像使用普通依赖一样使用 mongol 库，并且可以直接修改本地克隆的代码进行调试和开发。

这种方法特别适合需要对库进行自定义修改或贡献代码的情况。

### 本地库文件说明

#### 必要文件

当将 mongol 库作为本地库使用时，以下文件是必要的：

- **lib/ 目录**：包含库的所有源代码，特别是：
  - `mongol.dart`：库的主入口文件
  - `src/` 目录：包含所有具体实现的源代码
- **pubspec.yaml**：依赖配置文件，定义了库的名称、版本和依赖关系
- **LICENSE**：许可证文件，确保您合法使用库

## 快速开始

### 显示垂直文本

`MongolText` 是 Flutter `Text` 小部件的垂直文本版本。支持从左到右的换行。

```dart
MongolText("ᠨᠢᠭᠡ ᠬᠣᠶᠠᠷ ᠭᠤᠷᠪᠠ ᠳᠦᠷᠪᠡ ᠲᠠᠪᠤ ᠵᠢᠷᠭᠤᠭ᠎ᠠ ᠳᠣᠯᠣᠭ᠎ᠠ ᠨᠠᠢᠮᠠ ᠶᠢᠰᠦ ᠠᠷᠪᠠ"),
```

该库支持移动、Web 和桌面平台。

![](./example/supplemental/mongol_text.gif)

### 表情符号和 CJK 字符

该库会旋转表情符号和 CJK（中文、日文和韩文）字符以获得正确的方向。

![](./example/supplemental/emoji_cjk.png)

### 富文本

您可以使用 `TextSpan` 和/或 `TextStyle` 添加样式，就像使用 `Text` 小部件一样。

```dart
MongolText.rich(
  textSpan,
  textScaleFactor: 2.5,
),
```

其中 `textSpan` 定义如下：

```dart
const textSpan = TextSpan(
  style: TextStyle(fontSize: 30, color: Colors.black),
  children: [
    TextSpan(text: 'ᠨᠢᠭᠡ\n', style: TextStyle(fontSize: 40)),
    TextSpan(text: 'ᠬᠣᠶᠠᠷ', style: TextStyle(backgroundColor: Colors.yellow)),
    TextSpan(
      text: ' ᠭᠤᠷᠪᠠ ',
      style: TextStyle(shadows: [
        Shadow(
          blurRadius: 3.0,
          color: Colors.lightGreen,
          offset: Offset(3.0, -3.0),
        ),
      ]),
    ),
    TextSpan(text: 'ᠳᠦᠷ'),
    TextSpan(text: 'ᠪᠡ ᠲᠠᠪᠤ ᠵᠢᠷᠭᠤ', style: TextStyle(color: Colors.blue)),
    TextSpan(text: 'ᠭ᠎ᠠ ᠨᠠᠢᠮᠠ '),
    TextSpan(text: 'ᠶᠢᠰᠦ ', style: TextStyle(fontSize: 20)),
    TextSpan(
        text: 'ᠠᠷᠪᠠ',
        style:
            TextStyle(fontFamily: 'MenksoftAmuguleng', color: Colors.purple)),
  ],
);
```

![](./example/supplemental/mongol_rich_text.png)

这一切都假设您已经向应用程序资产添加了一种或多种蒙古文字体。

## 添加蒙古文字体

该库不包含蒙古文字体。这使得库更小，也让开发者可以自由选择他们喜欢的任何蒙古文字体。

由于您的一些用户的设备可能没有安装蒙古文字体，您应该在项目中至少包含一种蒙古文字体。您需要做以下操作：

### 1. 获取字体

您可以从以下来源找到字体：

- [Menksoft](https://www.mklai.cn/download-font?productId=a0ec7735b5714334934ff3c094ca0a5e)
- [MongolFont](http://www.mongolfont.com/en/font/index.html)
- [BolorSoft](https://www.mngl.net/#download)
- [Z Mongol Code](https://install.zcodetech.com/)
- [CMs font](https://phabricator.wikimedia.org/T130502)

### 2. 将字体添加到您的项目

您可以在[这里](https://medium.com/@suragch/how-to-use-a-custom-font-in-a-flutter-app-911763c162f5)和[这里](https://flutter.dev/docs/cookbook/design/fonts)获取有关如何执行此操作的说明。

基本上，您只需要为它创建一个 **assets/fonts** 文件夹，然后在 **pubspec.yaml** 中声明字体，如下所示：

```yaml
flutter:
  fonts:
    - family: MenksoftQagan
      fonts:
        - asset: assets/fonts/MQG8F02.ttf
```

您可以将族名称称为任何您想要的名称，但这个字符串是您将在下一步中使用的。

### 3. 为您的应用设置默认蒙古文字体

在您的 `main.dart` 文件中，为应用主题设置 `fontFamily`。

```dart
MaterialApp(
  theme: ThemeData(fontFamily: 'MenksoftQagan'),
  // ...
);
```

现在您不必为每个蒙古文文本小部件手动设置字体。不过，如果您想为某些小部件使用不同的字体，您仍然可以像通常在 `TextStyle` 中那样设置 `fontFamily`。

您还可以考虑将 [mongol_code](https://pub.dev/packages/mongol_code) 与 Menksoft 字体一起使用，如果您的用户的设备不支持 OpenType Unicode 字体渲染。`mongol_code` 将 Unicode 转换为 Menksoft 代码，Menksoft 字体可以显示而不需要任何特殊的渲染要求。

## 编辑垂直文本

您可以使用 `MongolTextField` 从系统键盘接收和编辑文本。这个小部件包含标准 Flutter `TextField` 小部件的大部分功能。

![](./example/supplemental/mongol_text_field.gif)

这是它在 iOS 和 Android 上与系统键盘交互的样子：

![](./example/supplemental/mongol_text_field_large.gif)

如果您想使用带有标签的轮廓文本字段，请使用 `MongolOutlineInputBorder`：

![](./example/supplemental/mongol_outline_input_border.png)

> **注意**：`MongolTextField` 目前在 `maxLines: null` 方面存在 [bug](https://github.com/suragch/mongol/issues/39)。欢迎提交 PR！

```dart
MongolTextField(
  decoration: InputDecoration(
    border: MongolOutlineInputBorder(),
    labelText: 'ᠨᠢᠭᠡ ᠬᠣᠶᠠᠷ ᠭᠤᠷᠪᠠ',
  ),
),
```

为了在 Web 和桌面（或连接到移动应用的物理键盘）上正确处理右/左和上/下键，您需要从小部件树顶部的 `MaterialApp`（或 `CupertinoApp` 或 `WidgetsApp`）的 `builder` 方法返回 `MongolTextEditingShortcuts` 小部件：

```dart
MaterialApp(
  builder: (context, child) => MongolTextEditingShortcuts(child: child),
  // ...
)
```

## 水平列表

您可以使用标准的 `ListView` 小部件显示水平滚动列表。您只需要将滚动方向设置为水平。

```dart
ListView(
  scrollDirection: Axis.horizontal,
  children: [
    MongolText('ᠨᠢᠭᠡ'),
    MongolText('ᠬᠣᠶᠠᠷ'),
    MongolText('ᠭᠤᠷᠪᠠ'),
  ],
),
```

对于更高级的内容，您也可以像使用 `ListTile` 一样使用 `MongolListTile` 小部件。以下是示例项目中的一个示例：

```dart
Card(
  child: MongolListTile(
    leading: FlutterLogo(size: 56.0),
    title: MongolText('ᠨᠢᠭᠡ ᠬᠣᠶᠠᠷ ᠭᠤᠷᠪᠠ'),
    subtitle: MongolText('ᠳᠦᠷᠪᠡ ᠲᠠᠪᠤ ᠵᠢᠷᠭᠤᠭ᠎ᠠ ᠳᠣᠯᠣᠭ᠎ᠠ ᠨᠠᠢᠮᠠ'),
    trailing: Icon(Icons.more_vert),
  ),
),
```

![](./example/supplemental/mongol_list_tile.gif)

如上图所示，除了 `MongolListTile` 之外，还有：

- `MongolCheckboxListTile`
- `MongolRadioListTile`
- `MongolSwitchListTile`

## 菜单

要添加带有水平项目的弹出菜单，您可以使用 `MongolPopupMenuButton`。它在所有标准 `PopupMenuButton` 的可自定义方式上都是可自定义的。

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('MongolPopupMenuButton'),
    actions: [
      MongolPopupMenuButton(
        itemBuilder: (context) => const [
          MongolPopupMenuItem(child: MongolText('ᠨᠢᠭᠡ'), value: 1),
          MongolPopupMenuItem(child: MongolText('ᠬᠣᠶᠠᠷ'), value: 2),
          MongolPopupMenuItem(child: MongolText('ᠭᠤᠷᠪᠠ'), value: 3),
        ],
        tooltip: 'vertical tooltip text',
        onSelected: (value) => print(value),
      ),
    ],
  ),
  body: Container(),
);
```

![](./example/supplemental/mongol_popup_menu_button.gif)

## 按钮

所有 Flutter 按钮都有蒙古文等效项：

- `MongolTextButton`
- `MongolOutlinedButton`
- `MongolElevatedButton`
- `MongolFilledButton`
- `MongolFilledButton.tonal`
- `MongolTextButton.icon`
- `MongolOutlinedButton.icon`
- `MongolElevatedButton.icon`
- `MongolFilledButton.icon`
- `MongolFilledButton.tonalIcon`
- `MongolIconButton`
- `MongolIconButton.filled`
- `MongolIconButton.filledTonal`
- `MongolIconButton.outlined`

![](./example/supplemental/buttons.png)

蒙古文图标按钮的原因是提供一个垂直工具提示，该提示会在移动设备上长按和在桌面和 Web 上鼠标悬停时出现。

## 其他小部件

### MongolAlertDialog

这个警报对话框的工作原理与 Flutter `AlertDialog` 大致相同。

![](./example/supplemental/mongol_alert_dialog.png)

## 运行示例应用

要运行示例应用，请克隆仓库并执行以下命令：

```bash
cd example
flutter run
```

示例应用展示了库中所有小部件的使用方法和效果。


## 问题和反馈

如果您遇到任何问题或有任何反馈，请在 [GitHub Issues](https://github.com/suragch/mongol/issues) 中提出。

## 许可证

本项目采用 MIT 许可证 - 详情请参阅 [LICENSE](LICENSE) 文件。

## 版本历史

有关版本更新的详细信息，请参阅 [CHANGELOG.md](CHANGELOG.md) 文件。

## 待办事项

- 改进键盘（这可能作为一个单独的包更好）
- 各种其他基于文本的小部件
- 支持 `WidgetSpan`
- 添加更多测试
- 对于 `MongolTextAlign.bottom`，不要计算行高的最终空间
- 添加 `MongolSelectableText` 小部件