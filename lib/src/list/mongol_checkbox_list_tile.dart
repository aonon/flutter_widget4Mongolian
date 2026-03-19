// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoCheckbox;

import 'mongol_list_tile.dart';
import 'mongol_radio_list_tile.dart';
import 'mongol_switch_list_tile.dart';
import '../text/mongol_text.dart';
import '../text/mongol_rich_text.dart';

// Examples can assume:
// late bool? _throwShotAway;
// void setState(VoidCallback fn) { }

/// 复选框类型枚举
///
/// material：使用 Material 风格的复选框
/// adaptive：使用平台自适应的复选框（iOS 上使用 CupertinoCheckbox）
enum _CheckboxType { material, adaptive }

/// 带有 [Checkbox] 的 [MongolListTile]。换句话说，就是带有标签的复选框。
///
/// 整个列表 tile 是可交互的：点击 tile 中的任何位置都会切换复选框状态。
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=RkSqPAn9szs}
///
/// 此小部件的 [value]、[onChanged]、[activeColor] 和 [checkColor] 属性与
/// [Checkbox] 小部件上的同名属性相同。
///
/// [title]、[subtitle]、[isThreeLine]、[dense] 和 [contentPadding] 属性与
/// [MongolListTile] 上的同名属性类似。
///
/// 此小部件上的 [selected] 属性与 [MongolListTile.selected] 属性类似。
/// 此 tile 的 [activeColor] 用于选中项的文本颜色，或者如果 [activeColor] 为 null，
/// 则使用主题的 [CheckboxThemeData.overlayColor]。
///
/// 此小部件不协调 [selected] 状态和 [value] 状态；要使列表 tile 在复选框选中时显示为选中状态，
/// 请将相同的值传递给两者。
///
/// 复选框显示在底部（即 trailing 边缘）。这可以通过 [controlAffinity] 更改。
/// [secondary] 小部件放置在相反的一侧。这映射到 [MongolListTile] 的
/// [MongolListTile.leading] 和 [MongolListTile.trailing] 属性。
///
/// 此小部件需要树中的 [Material] 小部件祖先来绘制自身，这通常由应用的 [Scaffold] 提供。
/// [tileColor] 和 [selectedTileColor] 不是由 [MongolCheckboxListTile] 本身绘制的，
/// 而是由 [Material] 小部件祖先绘制的。
/// 在这种情况下，可以在 [MongolCheckboxListTile] 周围包装一个 [Material] 小部件，例如：
///
/// {@tool snippet}
/// ```dart
/// ColoredBox(
///   color: Colors.green,
///   child: Material(
///     child: MongolCheckboxListTile(
///       tileColor: Colors.red,
///       title: const Text('MongolCheckboxListTile with red background'),
///       value: true,
///       onChanged:(bool? value) { },
///     ),
///   ),
/// )
/// ```
/// {@end-tool}
///
/// ## 用 [Material] 包装 [MongolCheckboxListTile] 时的性能考虑
///
/// 单独用 [Material] 包装大量 [MongolCheckboxListTile] 是昂贵的。
/// 考虑只包装需要它的 [MongolCheckboxListTile]，或者在可能的情况下包含一个共同的 [Material] 祖先。
///
/// 要将 [CheckboxListTile] 显示为禁用状态，请将 [onChanged] 回调传递为 null。
///
/// {@tool dartpad}
/// ![MongolCheckboxListTile sample](https://raw.githubusercontent.com/suragch/mongol/master/example/supplemental/checkbox_list_tile.png)
///
/// 此小部件显示一个复选框，当选中时，会减慢所有动画（包括复选框本身被选中的动画！）。
///
/// 此示例要求您还导入 'package:flutter/scheduler.dart'，以便您可以引用 [timeDilation]。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:flutter/scheduler.dart' show timeDilation;
/// 
/// /// Flutter code sample for [CheckboxListTile].
/// 
/// void main() => runApp(const CheckboxListTileApp());
/// 
/// class CheckboxListTileApp extends StatelessWidget {
///   const CheckboxListTileApp({super.key});
/// 
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       theme: ThemeData(useMaterial3: true),
///       home: const CheckboxListTileExample(),
///     );
///   }
/// }
/// 
/// class CheckboxListTileExample extends StatefulWidget {
///   const CheckboxListTileExample({super.key});
/// 
///   @override
///   State<CheckboxListTileExample> createState() =>
///       _CheckboxListTileExampleState();
/// }
/// 
/// class _CheckboxListTileExampleState extends State<CheckboxListTileExample> {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: const Text('CheckboxListTile Sample')),
///       body: Center(
///        child: MongolCheckboxListTile(
///           title: const MongolText('Animate Slowly'),
///           value: timeDilation != 1.0,
///           onChanged: (bool? value) {
///             setState(() {
///               timeDilation = value! ? 10.0 : 1.0;
///             });
///           },
///           secondary: const Icon(Icons.hourglass_empty),
///         ),
///       ),
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// {@tool dartpad}
/// ```dart
/// This sample demonstrates how [MongolCheckboxListTile] positions the checkbox widget
/// relative to the text in different configurations.
/// import 'package:flutter/material.dart';
///
/// /// Flutter code sample for [CheckboxListTile].
/// 
/// void main() => runApp(const CheckboxListTileApp());
/// 
/// class CheckboxListTileApp extends StatelessWidget {
///   const CheckboxListTileApp({super.key});
/// 
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       theme: ThemeData(useMaterial3: true),
///       home: const CheckboxListTileExample(),
///     );
///   }
/// }
/// 
/// class CheckboxListTileExample extends StatefulWidget {
///   const CheckboxListTileExample({super.key});
/// 
///   @override
///   State<CheckboxListTileExample> createState() =>
///       _CheckboxListTileExampleState();
/// }
/// 
/// class _CheckboxListTileExampleState extends State<CheckboxListTileExample> {
///   bool checkboxValue1 = true;
///   bool checkboxValue2 = true;
///   bool checkboxValue3 = true;
/// 
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: const Text('CheckboxListTile Sample')),
///       body: Column(
///         children: <Widget>[
///           MongolCheckboxListTile(
///             value: checkboxValue1,
///             onChanged: (bool? value) {
///               setState(() {
///                 checkboxValue1 = value!;
///               });
///             },
///             title: const MongolText('Headline'),
///             subtitle: const MongolText('Supporting text'),
///           ),
///           const Divider(height: 0),
///           MongolCheckboxListTile(
///             value: checkboxValue2,
///             onChanged: (bool? value) {
///               setState(() {
///                 checkboxValue2 = value!;
///               });
///             },
///             title: const MongolText('Headline'),
///             subtitle: const MongolText(
///                 'Longer supporting text to demonstrate how the text wraps and the checkbox is centered vertically with the text.'),
///           ),
///           const Divider(height: 0),
///           MongolCheckboxListTile(
///             value: checkboxValue3,
///             onChanged: (bool? value) {
///               setState(() {
///                 checkboxValue3 = value!;
///               });
///             },
///             title: const MongolText('Headline'),
///             subtitle: const MongolText(
///                 "Longer supporting text to demonstrate how the text wraps and how setting 'CheckboxListTile.isThreeLine = true' aligns the checkbox to the top vertically with the text."),
///             isThreeLine: true,
///           ),
///           const Divider(height: 0),
///         ],
///       ),
///     );
///   }
/// }
/// ```dart
/// {@end-tool}
///
/// ## MongolCheckboxListTile 中的语义
///
/// 由于整个 MongolCheckboxListTile 是可交互的，它应该将自己表示为单个交互实体。
///
/// 为此，MongolCheckboxListTile 小部件用 [MergeSemantics] 小部件包装其子级。
/// [MergeSemantics] 将尝试将其后代 [Semantics] 节点合并到语义树中的一个节点中。
/// 因此，如果任何子级需要自己的 [Semantics] 节点，MongolCheckboxListTile 会抛出错误。
///
/// 例如，您不能将 [RichText] 小部件嵌套为 MongolCheckboxListTile 的后代。
/// [RichText] 有一个嵌入的手势识别器，需要自己的 [Semantics] 节点，
/// 这直接与 MongolCheckboxListTile 将所有后代语义节点合并为一个的愿望冲突。
/// 因此，可能需要创建自定义单选 tile 小部件来适应类似的用例。
///
/// {@tool dartpad}
/// ![Checkbox list tile semantics sample](https://raw.githubusercontent.com/suragch/mongol/master/example/supplemental/checkbox_list_tile_semantics.png)
///
/// 这是一个自定义标签复选框小部件的示例，称为 LinkedLabelCheckbox，
/// 它包含一个处理点击手势的交互式 [MongolRichText] 小部件。
///
/// ```dart
/// import 'package:flutter/gestures.dart';
/// import 'package:flutter/material.dart';
/// 
/// /// Flutter code sample for custom labeled checkbox.
/// 
/// void main() => runApp(const LabeledCheckboxApp());
/// 
/// class LabeledCheckboxApp extends StatelessWidget {
///   const LabeledCheckboxApp({super.key});
/// 
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       theme: ThemeData(useMaterial3: true),
///       home: const LabeledCheckboxExample(),
///     );
///   }
/// }
/// 
/// class LinkedLabelCheckbox extends StatelessWidget {
///   const LinkedLabelCheckbox({
///     super.key,
///     required this.label,
///     required this.padding,
///     required this.value,
///     required this.onChanged,
///   });
/// 
///   final String label;
///   final EdgeInsets padding;
///   final bool value;
///   final ValueChanged<bool> onChanged;
/// 
///   @override
///   Widget build(BuildContext context) {
///     return Padding(
///       padding: padding,
///       child: Column(
///         children: <Widget>[
///           Expanded(
///             child: MongolRichText(
///               text: MongolTextSpan(
///                 text: label,
///                 style: const TextStyle(
///                   color: Colors.blueAccent,
///                   decoration: TextDecoration.underline,
///                 ),
///                 recognizer: TapGestureRecognizer()
///                   ..onTap = () {
///                     debugPrint('Label has been tapped.');
///                   },
///               ),
///             ),
///           ),
///           Checkbox(
///             value: value,
///             onChanged: (bool? newValue) {
///               onChanged(newValue!);
///             },
///           ),
///         ],
///       ),
///     );
///   }
/// }
///
/// class LabeledCheckboxExample extends StatefulWidget {
///   const LabeledCheckboxExample({super.key});
///
///   @override
///   State<LabeledCheckboxExample> createState() => _LabeledCheckboxExampleState();
/// }
///
/// class _LabeledCheckboxExampleState extends State<LabeledCheckboxExample> {
///   bool _isSelected = false;
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: const Text('Custom Labeled Checkbox Sample')),
///       body: Center(
///         child: LinkedLabelCheckbox(
///           label: 'Linked, tappable label text',
///           padding: const EdgeInsets.symmetric(horizontal: 20.0),
///           value: _isSelected,
///           onChanged: (bool newValue) {
///             setState(() {
///               _isSelected = newValue;
///             });
///           },
///         ),
///       ),
///     );
///  }
/// }
/// ```
/// {@end-tool}
///
/// ## MongolCheckboxListTile 不完全符合我的需求
///
/// 如果 MongolCheckboxListTile 填充和定位其元素的方式不完全符合您的要求，
/// 您可以通过将 [Checkbox] 与其他小部件（如 [MongolText]、[Padding] 和 [InkWell]）组合来创建自定义标签复选框小部件。
///
/// {@tool dartpad}
/// ![Custom checkbox list tile sample](https://raw.githubusercontent.com/suragch/mongol/master/example/supplemental/checkbox_list_tile_custom.png)
///
/// 这是一个自定义 LabeledCheckbox 小部件的示例，但您可以轻松创建自己的可配置小部件。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// 
/// Flutter code sample for custom labeled checkbox.
/// 
/// void main() => runApp(const LabeledCheckboxApp());
/// 
/// class LabeledCheckboxApp extends StatelessWidget {
///   const LabeledCheckboxApp({super.key});
/// 
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       theme: ThemeData(useMaterial3: true),
///       home: const LabeledCheckboxExample(),
///     );
///   }
/// }
/// 
/// class LabeledCheckbox extends StatelessWidget {
///   const LabeledCheckbox({
///     super.key,
///     required this.label,
///     required this.padding,
///     required this.value,
///     required this.onChanged,
///   });
/// 
///   final String label;
///   final EdgeInsets padding;
///   final bool value;
///   final ValueChanged<bool> onChanged;
/// 
///   @override
///   Widget build(BuildContext context) {
///     return InkWell(
///       onTap: () {
///         onChanged(!value);
///       },
///       child: Padding(
///         padding: padding,
///         child: Column(
///           children: <Widget>[
///             Expanded(child: MongolText(label)),
///             Checkbox(
///               value: value,
///               onChanged: (bool? newValue) {
///                 onChanged(newValue!);
///               },
///             ),
///           ],
///         ),
///       ),
///     );
///   }
/// }
/// 
/// class LabeledCheckboxExample extends StatefulWidget {
///   const LabeledCheckboxExample({super.key});
/// 
///   @override
///   State<LabeledCheckboxExample> createState() => _LabeledCheckboxExampleState();
/// }
/// 
/// class _LabeledCheckboxExampleState extends State<LabeledCheckboxExample> {
///   bool _isSelected = false;
/// 
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: const Text('Custom Labeled Checkbox Sample')),
///       body: Center(
///         child: LabeledCheckbox(
///           label: 'This is the label text',
///           padding: const EdgeInsets.symmetric(horizontal: 20.0),
///           value: _isSelected,
///           onChanged: (bool newValue) {
///             setState(() {
///               _isSelected = newValue;
///             });
///           },
///         ),
///       ),
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// 另请参阅：
///
///  * [MongolListTileTheme]，可用于影响列表 tile 的样式，包括复选框列表 tile。
///  * [MongolRadioListTile]，用于单选按钮的类似小部件。
///  * [MongolSwitchListTile]，用于开关的类似小部件。
///  * [MongolListTile] 和 [Checkbox]，此小部件由这些小部件组成。
class MongolCheckboxListTile extends StatelessWidget {
  /// 创建一个列表 tile 和复选框的组合。
  ///
  /// 复选框 tile 本身不维护任何状态。相反，当复选框的状态更改时，
  /// 小部件会调用 [onChanged] 回调。大多数使用复选框的小部件会监听 [onChanged] 回调，
  /// 并使用新的 [value] 重建复选框 tile 以更新复选框的视觉外观。
  ///
  /// 以下参数是必需的：
  ///
  /// * [value]，确定复选框是否被选中。只有当 [tristate] 为 true 时，[value] 才能为 null。
  /// * [onChanged]，当复选框的值应该更改时调用。可以将其设置为 null 以禁用复选框。
  const MongolCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.mouseCursor,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.shape,
    this.side,
    this.isError = false,
    this.enabled,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.tristate = false,
    this.checkboxShape,
    this.selectedTileColor,
    this.onFocusChange,
    this.enableFeedback,
    this.checkboxSemanticLabel,
  })  : _checkboxType = _CheckboxType.material,
        assert(tristate || value != null),
        assert(!isThreeLine || subtitle != null);

  /// 创建一个列表 tile 和平台自适应复选框的组合。
  ///
  /// 复选框使用 [Checkbox.adaptive] 为 iOS 平台显示 [CupertinoCheckbox]，
  /// 或为所有其他平台显示 [Checkbox]。
  ///
  /// 所有其他属性与 [CheckboxListTile] 相同。
  const MongolCheckboxListTile.adaptive({
    super.key,
    required this.value,
    required this.onChanged,
    this.mouseCursor,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.shape,
    this.side,
    this.isError = false,
    this.enabled,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.tristate = false,
    this.checkboxShape,
    this.selectedTileColor,
    this.onFocusChange,
    this.enableFeedback,
    this.checkboxSemanticLabel,
  })  : _checkboxType = _CheckboxType.adaptive,
        assert(tristate || value != null),
        assert(!isThreeLine || subtitle != null);

  /// Whether this checkbox is checked.
  final bool? value;

  /// Called when the value of the checkbox should change.
  ///
  /// The checkbox passes the new value to the callback but does not actually
  /// change state until the parent widget rebuilds the checkbox tile with the
  /// new value.
  ///
  /// If null, the checkbox will be displayed as disabled.
  ///
  /// {@tool snippet}
  ///
  /// The callback provided to [onChanged] should update the state of the parent
  /// [StatefulWidget] using the [State.setState] method, so that the parent
  /// gets rebuilt; for example:
  ///
  /// ```dart
  /// CheckboxListTile(
  ///   value: _throwShotAway,
  ///   onChanged: (bool? newValue) {
  ///     setState(() {
  ///       _throwShotAway = newValue;
  ///     });
  ///   },
  ///   title: const Text('Throw away your shot'),
  /// )
  /// ```
  /// {@end-tool}
  final ValueChanged<bool?>? onChanged;

  /// The cursor for a mouse pointer when it enters or is hovering over the
  /// widget.
  ///
  /// If [mouseCursor] is a [MaterialStateProperty<MouseCursor>],
  /// [WidgetStateProperty.resolve] is used for the following [WidgetState]s:
  ///
  ///  * [WidgetState.selected].
  ///  * [WidgetState.hovered].
  ///  * [WidgetState.disabled].
  ///
  /// If null, then the value of [CheckboxThemeData.mouseCursor] is used. If
  /// that is also null, then [WidgetStateMouseCursor.clickable] is used.
  final MouseCursor? mouseCursor;

  /// The color to use when this checkbox is checked.
  ///
  /// Defaults to [ColorScheme.secondary] of the current [Theme].
  final Color? activeColor;

  /// The color that fills the checkbox.
  ///
  /// Resolves in the following states:
  ///  * [WidgetState.selected].
  ///  * [WidgetState.hovered].
  ///  * [WidgetState.disabled].
  ///
  /// If null, then the value of [activeColor] is used in the selected
  /// state. If that is also null, the value of [CheckboxThemeData.fillColor]
  /// is used. If that is also null, then the default value is used.
  final WidgetStateProperty<Color?>? fillColor;

  /// The color to use for the check icon when this checkbox is checked.
  ///
  /// Defaults to Color(0xFFFFFFFF).
  final Color? checkColor;

  /// {@macro flutter.material.checkbox.hoverColor}
  final Color? hoverColor;

  /// The color for the checkbox's [Material].
  ///
  /// Resolves in the following states:
  ///  * [WidgetState.pressed].
  ///  * [WidgetState.selected].
  ///  * [WidgetState.hovered].
  ///
  /// If null, then the value of [activeColor] with alpha [kRadialReactionAlpha]
  /// and [hoverColor] is used in the pressed and hovered state. If that is also null,
  /// the value of [CheckboxThemeData.overlayColor] is used. If that is also null,
  /// then the default value is used in the pressed and hovered state.
  final WidgetStateProperty<Color?>? overlayColor;

  /// {@macro flutter.material.checkbox.splashRadius}
  ///
  /// If null, then the value of [CheckboxThemeData.splashRadius] is used. If
  /// that is also null, then [kRadialReactionRadius] is used.
  final double? splashRadius;

  /// {@macro flutter.material.checkbox.materialTapTargetSize}
  ///
  /// Defaults to [MaterialTapTargetSize.shrinkWrap].
  final MaterialTapTargetSize? materialTapTargetSize;

  /// Defines how compact the list tile's layout will be.
  ///
  /// {@macro flutter.material.themedata.visualDensity}
  final VisualDensity? visualDensity;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// {@macro flutter.material.ListTile.shape}
  final ShapeBorder? shape;

  /// {@macro flutter.material.checkbox.side}
  ///
  /// The given value is passed directly to [Checkbox.side].
  ///
  /// If this property is null, then [CheckboxThemeData.side] of
  /// [ThemeData.checkboxTheme] is used. If that is also null, then the side
  /// will be width 2.
  final BorderSide? side;

  /// {@macro flutter.material.checkbox.isError}
  ///
  /// Defaults to false.
  final bool isError;

  /// {@macro flutter.material.ListTile.tileColor}
  final Color? tileColor;

  /// The primary content of the list tile.
  ///
  /// Typically a [Text] widget.
  final Widget? title;

  /// Additional content displayed below the title.
  ///
  /// Typically a [Text] widget.
  final Widget? subtitle;

  /// A widget to display on the opposite side of the tile from the checkbox.
  ///
  /// Typically an [Icon] widget.
  final Widget? secondary;

  /// Whether this list tile is intended to display three lines of text.
  ///
  /// If false, the list tile is treated as having one line if the subtitle is
  /// null and treated as having two lines if the subtitle is non-null.
  final bool isThreeLine;

  /// Whether this list tile is part of a vertically dense list.
  ///
  /// If this property is null then its value is based on [ListTileThemeData.dense].
  final bool? dense;

  /// Whether to render icons and text in the [activeColor].
  ///
  /// No effort is made to automatically coordinate the [selected] state and the
  /// [value] state. To have the list tile appear selected when the checkbox is
  /// checked, pass the same value to both.
  ///
  /// Normally, this property is left to its default value, false.
  final bool selected;

  /// Where to place the control relative to the text.
  final ListTileControlAffinity controlAffinity;

  /// Defines insets surrounding the tile's contents.
  ///
  /// This value will surround the [Checkbox], [title], [subtitle], and [secondary]
  /// widgets in [CheckboxListTile].
  ///
  /// When the value is null, the [contentPadding] is `EdgeInsets.symmetric(horizontal: 16.0)`.
  final EdgeInsetsGeometry? contentPadding;

  /// If true the checkbox's [value] can be true, false, or null.
  ///
  /// Checkbox displays a dash when its value is null.
  ///
  /// When a tri-state checkbox ([tristate] is true) is tapped, its [onChanged]
  /// callback will be applied to true if the current value is false, to null if
  /// value is true, and to false if value is null (i.e. it cycles through false
  /// => true => null => false when tapped).
  ///
  /// If tristate is false (the default), [value] must not be null.
  final bool tristate;

  /// {@macro flutter.material.checkbox.shape}
  ///
  /// If this property is null then [CheckboxThemeData.shape] of [ThemeData.checkboxTheme]
  /// is used. If that's null then the shape will be a [RoundedRectangleBorder]
  /// with a circular corner radius of 1.0.
  final OutlinedBorder? checkboxShape;

  /// If non-null, defines the background color when [CheckboxListTile.selected] is true.
  final Color? selectedTileColor;

  /// {@macro flutter.material.inkwell.onFocusChange}
  final ValueChanged<bool>? onFocusChange;

  /// {@macro flutter.material.ListTile.enableFeedback}
  ///
  /// See also:
  ///
  ///  * [Feedback] for providing platform-specific feedback to certain actions.
  final bool? enableFeedback;

  /// Whether the CheckboxListTile is interactive.
  ///
  /// If false, this list tile is styled with the disabled color from the
  /// current [Theme] and the [ListTile.onTap] callback is
  /// inoperative.
  final bool? enabled;

  /// {@macro flutter.material.checkbox.semanticLabel}
  final String? checkboxSemanticLabel;

  final _CheckboxType _checkboxType;

  /// 处理值的更改
  ///
  /// 根据当前值和 tristate 设置计算新值并调用 onChanged 回调
  void _handleValueChange() {
    assert(onChanged != null);
    switch (value) {
      case false:
        onChanged!(true);
      case true:
        onChanged!(tristate ? null : false);
      case null:
        onChanged!(false);
    }
  }

  /// 构建小部件
  ///
  /// 根据 checkboxType 创建相应的复选框控件，并将其与 MongolListTile 组合
  @override
  Widget build(BuildContext context) {
    final Widget control;

    switch (_checkboxType) {
      case _CheckboxType.material:
        control = Checkbox(
          value: value,
          onChanged: enabled ?? true ? onChanged : null,
          mouseCursor: mouseCursor,
          activeColor: activeColor,
          fillColor: fillColor,
          checkColor: checkColor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          materialTapTargetSize:
              materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          autofocus: autofocus,
          tristate: tristate,
          shape: checkboxShape,
          side: side,
          isError: isError,
          semanticLabel: checkboxSemanticLabel,
        );
      case _CheckboxType.adaptive:
        control = Checkbox.adaptive(
          value: value,
          onChanged: enabled ?? true ? onChanged : null,
          mouseCursor: mouseCursor,
          activeColor: activeColor,
          fillColor: fillColor,
          checkColor: checkColor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          materialTapTargetSize:
              materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          autofocus: autofocus,
          tristate: tristate,
          shape: checkboxShape,
          side: side,
          isError: isError,
          semanticLabel: checkboxSemanticLabel,
        );
    }

    Widget? leading, trailing;
    switch (controlAffinity) {
      case ListTileControlAffinity.leading:
        leading = control;
        trailing = secondary;
      case ListTileControlAffinity.trailing:
      case ListTileControlAffinity.platform:
        leading = secondary;
        trailing = control;
    }
    final ThemeData theme = Theme.of(context);
    final CheckboxThemeData checkboxTheme = CheckboxTheme.of(context);
    final Set<WidgetState> states = <WidgetState>{
      if (selected) WidgetState.selected,
    };
    final Color effectiveActiveColor = activeColor ??
        checkboxTheme.fillColor?.resolve(states) ??
        theme.colorScheme.secondary;
    return MergeSemantics(
      child: MongolListTile(
        selectedColor: effectiveActiveColor,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        isThreeLine: isThreeLine,
        dense: dense,
        enabled: enabled ?? onChanged != null,
        onTap: onChanged != null ? _handleValueChange : null,
        selected: selected,
        autofocus: autofocus,
        contentPadding: contentPadding,
        shape: shape,
        selectedTileColor: selectedTileColor,
        tileColor: tileColor,
        visualDensity: visualDensity,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        enableFeedback: enableFeedback,
      ),
    );
  }
}
