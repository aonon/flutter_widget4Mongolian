// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// TODO: MongolMenuAnchor is not implemented yet.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        Brightness,
        ColorScheme,
        IconButton,
        Icons,
        InkWell,
        Material,
        MaterialLocalizations,
        WidgetState,
        WidgetStateMouseCursor,
        WidgetStateProperty,
        MaterialType,
        PopupMenuTheme,
        PopupMenuThemeData,
        TextTheme,
        Theme,
        ThemeData,
        VerticalDivider,
        debugCheckHasMaterialLocalizations,
        kMinInteractiveDimension,
        kThemeChangeDuration;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mongol/mongol.dart';

import 'mongol_intrinsic_height.dart';

const Duration _kMenuDuration = Duration(milliseconds: 300);
const double _kMenuCloseIntervalEnd = 2.0 / 3.0;
const double _kMenuHorizontalPadding = 8.0;
const double _kMenuDividerWidth = 16.0;
const double _kMenuMaxHeight = 5.0 * _kMenuHeightStep;
const double _kMenuMinHeight = 2.0 * _kMenuHeightStep;
const double _kMenuHeightStep = 56.0;
const double _kMenuScreenPadding = 8.0;

PopupMenuThemeData _menuDefaults(BuildContext context, ThemeData theme) {
  return theme.useMaterial3
      ? _PopupMenuDefaultsM3(context)
      : _PopupMenuDefaultsM2(context);
}

EdgeInsets _menuVerticalPadding(bool useMaterial3) {
  return useMaterial3
      ? _PopupMenuDefaultsM3.menuVerticalPadding
      : _PopupMenuDefaultsM2.menuVerticalPadding;
}

/// 材料设计弹出菜单中条目的基类。
///
/// 弹出菜单小部件使用此接口与菜单项进行交互。
/// 要显示弹出菜单，请使用 [showMongolMenu] 函数。要创建一个显示弹出菜单的按钮，
/// 考虑使用 [MongolPopupMenuButton]。
///
/// 类型 `T` 是条目表示的值的类型。给定菜单中的所有条目必须表示具有一致类型的值。
///
/// [MongolPopupMenuEntry] 可以表示多个值，例如带有几个图标的列，
/// 或单个条目，例如带有图标的菜单项（请参阅 [MongolPopupMenuItem]），
/// 或根本没有值（例如，[MongolPopupMenuDivider]）。
///
/// 另请参阅：
///
///  * [MongolPopupMenuItem]，单个值的弹出菜单项。
///  * [MongolPopupMenuDivider]，只是一条垂直线的弹出菜单项。
///  * [MongolCheckedPopupMenuItem]，带有复选标记的弹出菜单项。
///  * [showMongolMenu]，在给定位置动态显示弹出菜单的方法。
///  * [MongolPopupMenuButton]，一个在点击时自动显示菜单的 [IconButton]。
abstract class MongolPopupMenuEntry<T> extends StatefulWidget {
  /// 抽象常量构造函数。此构造函数使子类能够提供常量构造函数，
  /// 以便它们可以在常量表达式中使用。
  const MongolPopupMenuEntry({super.key});

  /// 此条目占用的水平空间量。
  ///
  /// 如果提供了 `initialValue` 参数，此值在调用 [showMongolMenu] 方法时使用，
  /// 以确定在将所选条目对齐到给定 `position` 时此条目的位置。
  /// 否则，它将被忽略。
  double get width;

  /// 此条目是否表示特定值。
  ///
  /// 此方法由 [showMongolMenu] 在调用时使用，以将表示 `initialValue`（如果有）的条目
  /// 对齐到给定的 `position`，然后稍后在每个条目上调用以确定它是否应该被高亮显示
  /// （如果方法返回 true，则条目的背景颜色将设置为环境 [ThemeData.highlightColor]）。
  /// 如果 `initialValue` 为 null，则不调用此方法。
  ///
  /// 如果 [MongolPopupMenuEntry] 表示单个值，则如果参数与该值匹配，应返回 true。
  /// 如果它表示多个值，则如果参数与其中任何一个匹配，应返回 true。
  bool represents(T? value);
}

/// 材料设计弹出菜单中的垂直分隔线。
///
/// 此小部件使 [Divider] 适用于弹出菜单。
///
/// 另请参阅：
///
///  * [MongolPopupMenuItem]，此类部件分隔的项目类型。
///  * [showMongolMenu]，在给定位置动态显示弹出菜单的方法。
///  * [MongolPopupMenuButton]，一个在点击时自动显示菜单的 [IconButton]。
class MongolPopupMenuDivider extends MongolPopupMenuEntry<Never> {
  /// 为弹出菜单创建一个垂直分隔线。
  ///
  /// 默认情况下，分隔线的宽度为 16 逻辑像素。
  const MongolPopupMenuDivider({super.key, this.width = _kMenuDividerWidth});

  /// 分隔线条目的宽度。
  ///
  /// 默认为 16 像素。
  @override
  final double width;

  @override
  bool represents(void value) => false;

  @override
  State<MongolPopupMenuDivider> createState() => _MongolPopupMenuDividerState();
}

class _MongolPopupMenuDividerState extends State<MongolPopupMenuDivider> {
  @override
  Widget build(BuildContext context) => VerticalDivider(width: widget.width);
}

// Stores each menu item's laid out size for route positioning.
class _MenuItem extends SingleChildRenderObjectWidget {
  const _MenuItem({
    required this.onLayout,
    required super.child,
  });

  final ValueChanged<Size> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMenuItem(onLayout);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderMenuItem renderObject) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderMenuItem extends RenderShiftedBox {
  _RenderMenuItem(this.onLayout, [RenderBox? child]) : super(child);

  ValueChanged<Size> onLayout;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) {
      return Size.zero;
    }
    return child!.getDryLayout(constraints);
  }

  @override
  void performLayout() {
    if (child == null) {
      size = Size.zero;
    } else {
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      childParentData.offset = Offset.zero;
    }
    onLayout(size);
  }
}

/// 蒙古文材料设计弹出菜单中的一个项目。
///
/// 要显示弹出菜单，请使用 [showMongolMenu] 函数。要创建一个显示弹出菜单的按钮，
/// 考虑使用 [MongolPopupMenuButton]。
///
/// 要在弹出菜单项旁边显示复选标记，考虑使用 [MongolCheckedPopupMenuItem]。
///
/// 通常，[MongolPopupMenuItem] 的 [child] 是一个 [MongolText] 小部件。
/// 带有图标的更复杂菜单可以使用 [MongolListTile]。默认情况下，
/// [MongolPopupMenuItem] 的宽度为 [kMinInteractiveDimension] 像素。
/// 如果您使用不同宽度的小部件，则必须在 [width] 属性中指定。
///
/// 示例：
///
/// 这里，一个 [MongolText] 小部件与一个弹出菜单项一起使用。
/// `WhyFarther` 类型是一个枚举，这里未显示。
///
/// ```dart
/// const MongolPopupMenuItem<WhyFarther>(
///   value: WhyFarther.harder,
///   child: MongolText('Working a lot harder'),
/// )
/// ```
///
/// 有关如何在完整菜单中使用此示例，请参阅 [MongolPopupMenuButton] 中的示例，
/// 有关如何使使用 [MongolText] 小部件作为 [child] 的 [MongolPopupMenuItem] 的文本
/// 与 [MongolCheckedPopupMenuItem] 的文本或使用 [MongolListTile] 作为 [child] 的
/// [MongolPopupMenuItem] 的文本对齐的一种方法，请参阅 [MongolCheckedPopupMenuItem] 中的示例。
///
/// 另请参阅：
///
///  * [MongolPopupMenuDivider]，可用于将项目彼此分开。
///  * [MongolCheckedPopupMenuItem]，带有复选标记的 [MongolPopupMenuItem] 变体。
///  * [showMongolMenu]，在给定位置动态显示弹出菜单的方法。
///  * [MongolPopupMenuButton]，一个在点击时自动显示菜单的 [IconButton]。
class MongolPopupMenuItem<T> extends MongolPopupMenuEntry<T> {
  /// 为弹出菜单创建一个项目。
  ///
  /// 默认情况下，项目是 [enabled] 的。
  ///
  /// `enabled` 和 `width` 参数不能为空。
  const MongolPopupMenuItem({
    super.key,
    this.value,
    this.onTap,
    this.enabled = true,
    this.width = kMinInteractiveDimension,
    this.padding,
    this.textStyle,
    this.labelTextStyle,
    this.mouseCursor,
    required this.child,
  });

  /// 如果此条目被选中，[showMongolMenu] 将返回的值。
  final T? value;

  /// 当菜单项被点击时调用。
  final VoidCallback? onTap;

  /// 是否允许用户选择此项目。
  ///
  /// 默认为 true。如果为 false，则项目不会对触摸做出反应。
  final bool enabled;

  /// 菜单项的最小宽度。
  ///
  /// 默认为 [kMinInteractiveDimension] 像素。
  @override
  final double width;

  /// 菜单项的内边距。
  ///
  /// 请注意，[width] 可能会与应用的内边距相互作用。例如，
  /// 如果提供的 [width] 大于内边距和 [child] 之和的宽度，
  /// 则内边距的效果将不可见。
  ///
  /// 如果此值为 null 且 [ThemeData.useMaterial3] 为 true，
  /// 则垂直内边距默认为两侧各 12.0。
  ///
  /// 如果此值为 null 且 [ThemeData.useMaterial3] 为 false，
  /// 则垂直内边距默认为两侧各 16.0。
  ///
  /// 当为 null 时，垂直内边距默认为两侧各 16.0。
  final EdgeInsets? padding;

  /// 弹出菜单项的文本样式。
  ///
  /// 如果此属性为 null，则使用 [PopupMenuThemeData.textStyle]。
  /// 如果 [PopupMenuThemeData.textStyle] 也为 null，则使用
  /// [ThemeData.textTheme] 的 [TextTheme.titleMedium]。
  final TextStyle? textStyle;

  /// 弹出菜单项的标签样式。
  ///
  /// 当 [ThemeData.useMaterial3] 为 true 时，这会设置弹出菜单项文本的样式。
  ///
  /// 如果此属性为 null，则使用 [PopupMenuThemeData.labelTextStyle]。
  /// 如果 [PopupMenuThemeData.labelTextStyle] 也为 null，则使用
  /// [TextTheme.labelLarge]，当弹出菜单项启用时使用 [ColorScheme.onSurface] 颜色，
  /// 当弹出菜单项禁用时使用带有 0.38 不透明度的 [ColorScheme.onSurface] 颜色。
  final WidgetStateProperty<TextStyle?>? labelTextStyle;

  /// 鼠标指针进入或悬停在小部件上时的光标。
  ///
  /// 如果 [mouseCursor] 是 [MaterialStateProperty<MouseCursor>]，
  /// 则 [WidgetStateProperty.resolve] 用于以下 [WidgetState]：
  ///
  ///  * [WidgetState.hovered]（悬停状态）。
  ///  * [WidgetState.focused]（焦点状态）。
  ///  * [WidgetState.disabled]（禁用状态）。
  ///
  /// 如果为 null，则使用 [PopupMenuThemeData.mouseCursor] 的值。
  /// 如果这也是 null，则使用 [WidgetStateMouseCursor.clickable]。
  final MouseCursor? mouseCursor;

  /// 此小部件下方树中的小部件。
  ///
  /// 通常是单行 [MongolListTile]（用于带图标的菜单）或 [MongolText]。
  /// 为子级设置了适当的 [DefaultTextStyle]。在任何情况下，
  /// 文本都应该足够短，不会换行。
  final Widget? child;

  @override
  bool represents(T? value) => value == this.value;

  @override
  MongolPopupMenuItemState<T, MongolPopupMenuItem<T>> createState() =>
      MongolPopupMenuItemState<T, MongolPopupMenuItem<T>>();
}

/// [MongolPopupMenuItem] 子类的 [State]。
///
/// 默认情况下，这实现了材料设计弹出菜单项的基本样式和布局。
///
/// 可以重写 [buildChild] 方法来调整菜单中放置的内容。默认情况下，它返回 [MongolPopupMenuItem.child]。
///
/// 可以重写 [handleTap] 方法来调整项目被点击时发生的情况。默认情况下，它使用 [Navigator.pop] 从菜单路由返回 [MongolPopupMenuItem.value]。
///
/// 此类采用两个类型参数。第二个 `W` 是使用此 [State] 的 [Widget] 的精确类型。它必须是 [MongolPopupMenuItem] 的子类。
/// 第一个 `T` 必须与该小部件类的类型参数匹配，并且是从该菜单返回的值的类型。
class MongolPopupMenuItemState<T, W extends MongolPopupMenuItem<T>>
    extends State<W> {
  /// 菜单项内容。
  ///
  /// 由 [build] 方法使用。
  ///
  /// 默认情况下，这返回 [MongolPopupMenuItem.child]。重写此方法以在菜单项中放置其他内容。
  @protected
  Widget? buildChild() => widget.child;

  /// 当用户选择菜单项时的处理程序。
  ///
  /// 由 [build] 方法插入的 [InkWell] 使用。
  ///
  /// 默认情况下，使用 [Navigator.pop] 从菜单路由返回 [MongolPopupMenuItem.value]。
  @protected
  void handleTap() {
    Navigator.pop<T>(context, widget.value);

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final PopupMenuThemeData defaults = _menuDefaults(context, theme);
    final Set<WidgetState> states = <WidgetState>{
      if (!widget.enabled) WidgetState.disabled,
    };

    TextStyle style = theme.useMaterial3
        ? (widget.labelTextStyle?.resolve(states) ??
            popupMenuTheme.labelTextStyle?.resolve(states) ??
            defaults.labelTextStyle!.resolve(states)!)
        : (widget.textStyle ?? popupMenuTheme.textStyle ?? defaults.textStyle!);

    if (!widget.enabled && !theme.useMaterial3) {
      style = style.copyWith(color: theme.disabledColor);
    }

    Widget item = AnimatedDefaultTextStyle(
      style: style,
      duration: kThemeChangeDuration,
      child: Container(
        alignment: Alignment.topCenter,
        constraints: BoxConstraints(minWidth: widget.width),
        padding: widget.padding ?? _menuVerticalPadding(theme.useMaterial3),
        child: buildChild(),
      ),
    );

    if (!widget.enabled) {
      final bool isDark = theme.brightness == Brightness.dark;
      item = IconTheme.merge(
        data: IconThemeData(opacity: isDark ? 0.5 : 0.38),
        child: item,
      );
    }

    return MergeSemantics(
      child: Semantics(
        enabled: widget.enabled,
        button: true,
        child: InkWell(
          onTap: widget.enabled ? handleTap : null,
          canRequestFocus: widget.enabled,
          mouseCursor: _EffectiveMouseCursor(
              widget.mouseCursor, popupMenuTheme.mouseCursor),
          child: MongolListTileTheme.merge(
            contentPadding: EdgeInsets.zero,
            titleTextStyle: style,
            child: item,
          ),
        ),
      ),
    );
  }
}

/// 蒙古文材料设计弹出菜单中带有复选标记的项目。
///
/// 要显示弹出菜单，请使用 [showMongolMenu] 函数。要创建一个显示弹出菜单的按钮，
/// 考虑使用 [MongolPopupMenuButton]。
///
/// [MongolCheckedPopupMenuItem] 的高度为 kMinInteractiveDimension 像素，
/// 与 [MongolPopupMenuItem] 的默认最小高度匹配。水平布局使用 [MongolListTile]；
/// 复选标记是一个 [Icons.done] 图标，显示在 [MongolListTile.leading] 位置。
///
/// 示例：
///
/// 假设存在一个 `Commands` 枚举，列出了特定弹出菜单中的可能命令，
/// 包括 `Commands.heroAndScholar` 和 `Commands.hurricaneCame`，
/// 并且假设有一个 `_heroAndScholar` 成员字段，它是一个布尔值。
/// 下面的示例显示了一个菜单，其中一个菜单项带有可以切换布尔值的复选标记，
/// 一个菜单项没有复选标记用于选择第二个选项。
/// （它还显示了放置在两个菜单项之间的分隔线。）
///
/// ```dart
/// MongolPopupMenuButton<Commands>(
///   onSelected: (Commands result) {
///     switch (result) {
///       case Commands.heroAndScholar:
///         setState(() { _heroAndScholar = !_heroAndScholar; });
///       case Commands.hurricaneCame:
///         // ...handle hurricane option
///         break;
///       // ...other items handled here
///     }
///   },
///   itemBuilder: (BuildContext context) => <MongolPopupMenuEntry<Commands>>[
///     CheckedPopupMenuItem<Commands>(
///       checked: _heroAndScholar,
///       value: Commands.heroAndScholar,
///       child: const Text('Hero and scholar'),
///     ),
///     const MongolPopupMenuDivider(),
///     const MongolPopupMenuItem<Commands>(
///       value: Commands.hurricaneCame,
///       child: MongolListTile(leading: Icon(null), title: Text('Bring hurricane')),
///     ),
///     // ...other items listed here
///   ],
/// )
/// ```
///
/// 特别注意第二个菜单项如何使用带有空白 [Icon] 的 [MongolListTile] 在 [MongolListTile.leading] 位置
/// 以获得与带有复选标记的项目相同的对齐方式。
///
/// 另请参阅：
///
///  * [MongolPopupMenuItem]，用于选择命令（而不是切换值）的弹出菜单项。
///  * [MongolPopupMenuDivider]，只是一条水平线的弹出菜单项。
///  * [showMongolMenu]，在给定位置动态显示弹出菜单的方法。
///  * [MongolPopupMenuButton]，一个在点击时自动显示菜单的 [MongolIconButton]。
class MongolCheckedPopupMenuItem<T> extends MongolPopupMenuItem<T> {
  /// 创建一个带有复选标记的弹出菜单项。
  ///
  /// 默认情况下，菜单项是 [enabled] 的但未选中。要将项目标记为选中，
  /// 请将 [checked] 设置为 true。
  const MongolCheckedPopupMenuItem({
    super.key,
    super.value,
    this.checked = false,
    super.enabled,
    super.padding,
    super.width,
    super.labelTextStyle,
    super.mouseCursor,
    super.child,
    super.onTap,
  });

  /// 是否在菜单项旁边显示复选标记。
  ///
  /// 默认为 false。
  ///
  /// 当为 true 时，显示 [Icons.done] 复选标记。
  ///
  /// 当此弹出菜单项被选中时，复选标记将适当淡入或淡出，以表示隐含的新状态。
  final bool checked;

  /// 此小部件下方树中的小部件。
  ///
  /// 通常是 [Text]。为子级设置了适当的 [DefaultTextStyle]。
  /// 文本应该足够短，不会换行。
  ///
  /// 此小部件放置在 [ListTile] 的 [ListTile.title] 插槽中，
  /// 其 [ListTile.leading] 插槽是一个 [Icons.done] 图标。
  @override
  Widget? get child => super.child;

  @override
  MongolPopupMenuItemState<T, MongolCheckedPopupMenuItem<T>> createState() =>
      _MongolCheckedPopupMenuItemState<T>();
}

class _MongolCheckedPopupMenuItemState<T>
    extends MongolPopupMenuItemState<T, MongolCheckedPopupMenuItem<T>>
    with SingleTickerProviderStateMixin {
  /// 复选标记淡入淡出动画的持续时间。
  static const Duration _fadeDuration = Duration(milliseconds: 150);

  /// 控制复选标记淡入淡出动画的控制器。
  late AnimationController _controller;

  /// 动画的不透明度值。
  Animation<double> get _opacity => _controller.view;

  /// 初始化状态，创建并配置动画控制器。
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _fadeDuration, vsync: this)
      ..value = widget.checked ? 1.0 : 0.0
      ..addListener(() => setState(() {/* animation changed */}));
  }

  /// 清理资源，释放动画控制器。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 处理菜单项点击事件，根据当前选中状态控制复选标记的淡入淡出动画。
  @override
  void handleTap() {
    // This fades the checkmark in or out when tapped.
    if (widget.checked) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    super.handleTap();
  }

  /// 构建菜单项的子部件，包含带有淡入淡出动画的复选标记和标题。
  @override
  Widget buildChild() {
    final ThemeData theme = Theme.of(context);
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final PopupMenuThemeData defaults = _menuDefaults(context, theme);
    final Set<WidgetState> states = <WidgetState>{
      if (widget.checked) WidgetState.selected,
    };
    final WidgetStateProperty<TextStyle?>? effectiveLabelTextStyle =
        widget.labelTextStyle ??
            popupMenuTheme.labelTextStyle ??
            defaults.labelTextStyle;
    return IgnorePointer(
      child: MongolListTileTheme.merge(
        contentPadding: EdgeInsets.zero,
        child: MongolListTile(
          enabled: widget.enabled,
          titleTextStyle: effectiveLabelTextStyle?.resolve(states),
          leading: FadeTransition(
            opacity: _opacity,
            child: Icon(_controller.isDismissed ? null : Icons.done),
          ),
          title: widget.child,
        ),
      ),
    );
  }
}

/// 弹出菜单的内部实现类，负责构建菜单的 UI。
class _PopupMenu<T> extends StatelessWidget {
  /// 创建一个弹出菜单。
  ///
  /// [route] 是弹出菜单的路由，包含菜单项和其他配置。
  /// [semanticLabel] 是用于辅助功能的语义标签。
  /// [constraints] 是菜单的大小约束。
  /// [clipBehavior] 是菜单的裁剪行为。
  const _PopupMenu({
    super.key,
    required this.route,
    required this.semanticLabel,
    this.constraints,
    required this.clipBehavior,
  });

  /// 弹出菜单的路由，包含菜单项和其他配置。
  final _PopupMenuRoute<T> route;

  /// 用于辅助功能的语义标签。
  final String? semanticLabel;

  /// 菜单的大小约束。
  final BoxConstraints? constraints;

  /// 菜单的裁剪行为。
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final double animationUnit = 1.0 / (route.items.length + 1.5);
    final List<Widget> children = <Widget>[];
    final ThemeData theme = Theme.of(context);
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final PopupMenuThemeData defaults = _menuDefaults(context, theme);

    for (int i = 0; i < route.items.length; i += 1) {
      final double start = (i + 1) * animationUnit;
      final double end = (start + 1.5 * animationUnit).clamp(0.0, 1.0);
      final CurvedAnimation opacity = CurvedAnimation(
        parent: route.animation!,
        curve: Interval(start, end),
      );
      Widget item = route.items[i];
      if (route.initialValue != null &&
          route.items[i].represents(route.initialValue)) {
        item = Container(
          color: Theme.of(context).highlightColor,
          child: item,
        );
      }
      children.add(
        _MenuItem(
          onLayout: (Size size) {
            route.itemSizes[i] = size;
          },
          child: FadeTransition(
            opacity: opacity,
            child: item,
          ),
        ),
      );
    }

    final CurveTween opacity =
        CurveTween(curve: const Interval(0.0, 1.0 / 3.0));
    final CurveTween height = CurveTween(curve: Interval(0.0, animationUnit));
    final CurveTween width =
        CurveTween(curve: Interval(0.0, animationUnit * route.items.length));

    final Widget child = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _kMenuMinHeight,
        maxHeight: _kMenuMaxHeight,
      ),
      child: MongolIntrinsicHeight(
        stepHeight: _kMenuHeightStep,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: semanticLabel,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: _kMenuHorizontalPadding,
            ),
            child: Row(
              children: children,
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: route.animation!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: opacity.animate(route.animation!),
          child: Material(
            shape: route.shape ?? popupMenuTheme.shape ?? defaults.shape,
            color: route.color ?? popupMenuTheme.color ?? defaults.color,
            clipBehavior: clipBehavior,
            type: MaterialType.card,
            elevation: route.elevation ??
                popupMenuTheme.elevation ??
                defaults.elevation!,
            shadowColor: route.shadowColor ??
                popupMenuTheme.shadowColor ??
                defaults.shadowColor,
            surfaceTintColor: route.surfaceTintColor ??
                popupMenuTheme.surfaceTintColor ??
                defaults.surfaceTintColor,
            child: Align(
              alignment: Alignment.topRight,
              widthFactor: width.evaluate(route.animation!),
              heightFactor: height.evaluate(route.animation!),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _PopupMenuRouteLayout extends SingleChildLayoutDelegate {
  _PopupMenuRouteLayout(
    this.position,
    this.itemSizes,
    this.selectedItemIndex,
    this.padding,
    this.avoidBounds,
  );

  final RelativeRect position;
  List<Size?> itemSizes;
  final int? selectedItemIndex;
  EdgeInsets padding;
  final Set<Rect> avoidBounds;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest).deflate(
      const EdgeInsets.all(_kMenuScreenPadding) + padding,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double buttonWidth = size.width - position.left - position.right;
    double menuX = position.left;
    if (selectedItemIndex != null) {
      double selectedCenterOffset = _kMenuHorizontalPadding;
      for (int index = 0; index < selectedItemIndex!; index += 1) {
        selectedCenterOffset += itemSizes[index]!.width;
      }
      selectedCenterOffset += itemSizes[selectedItemIndex!]!.width / 2;
      menuX = menuX + buttonWidth / 2.0 - selectedCenterOffset;
    }

    double menuY;
    if (position.top > position.bottom) {
      menuY = size.height - position.bottom - childSize.height;
    } else {
      menuY = position.top;
    }

    final Offset desiredPosition = Offset(menuX, menuY);
    final Offset originCenter = position.toRect(Offset.zero & size).center;
    final Iterable<Rect> subScreens =
        DisplayFeatureSubScreen.subScreensInBounds(
            Offset.zero & size, avoidBounds);
    final Rect subScreen = _closestScreen(subScreens, originCenter);
    return _fitInsideScreen(subScreen, childSize, desiredPosition);
  }

  Rect _closestScreen(Iterable<Rect> screens, Offset point) {
    Rect closest = screens.first;
    for (final Rect screen in screens) {
      if ((screen.center - point).distance <
          (closest.center - point).distance) {
        closest = screen;
      }
    }
    return closest;
  }

  Offset _fitInsideScreen(Rect screen, Size childSize, Offset desiredPosition) {
    double menuX = desiredPosition.dx;
    double menuY = desiredPosition.dy;
    if (menuY < screen.top + _kMenuScreenPadding + padding.top) {
      menuY = _kMenuScreenPadding + padding.top;
    } else if (menuY + childSize.height >
        screen.bottom - _kMenuScreenPadding - padding.bottom) {
      menuY = screen.bottom -
          childSize.height -
          _kMenuScreenPadding -
          padding.bottom;
    }
    if (menuX < screen.left + _kMenuScreenPadding + padding.left) {
      menuX = screen.left + _kMenuScreenPadding + padding.left;
    } else if (menuX + childSize.width >
        screen.right - _kMenuScreenPadding - padding.right) {
      menuX =
          screen.right - childSize.width - _kMenuScreenPadding - padding.right;
    }

    return Offset(menuX, menuY);
  }

  @override
  bool shouldRelayout(_PopupMenuRouteLayout oldDelegate) {
    assert(itemSizes.length == oldDelegate.itemSizes.length);

    return position != oldDelegate.position ||
        selectedItemIndex != oldDelegate.selectedItemIndex ||
        !listEquals(itemSizes, oldDelegate.itemSizes) ||
        padding != oldDelegate.padding ||
        !setEquals(avoidBounds, oldDelegate.avoidBounds);
  }
}

class _PopupMenuRoute<T> extends PopupRoute<T> {
  _PopupMenuRoute({
    required this.position,
    required this.items,
    this.initialValue,
    this.elevation,
    this.surfaceTintColor,
    this.shadowColor,
    required this.barrierLabel,
    this.semanticLabel,
    this.shape,
    this.color,
    required this.capturedThemes,
    this.constraints,
    required this.clipBehavior,
    super.settings,
    this.popUpAnimationStyle,
  })  : itemSizes = List<Size?>.filled(items.length, null),
        super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final RelativeRect position;
  final List<MongolPopupMenuEntry<T>> items;
  final List<Size?> itemSizes;
  final T? initialValue;
  final double? elevation;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final String? semanticLabel;
  final ShapeBorder? shape;
  final Color? color;
  final CapturedThemes capturedThemes;
  final BoxConstraints? constraints;
  final Clip clipBehavior;
  final AnimationStyle? popUpAnimationStyle;

  @override
  Animation<double> createAnimation() {
    if (popUpAnimationStyle != AnimationStyle.noAnimation) {
      return CurvedAnimation(
        parent: super.createAnimation(),
        curve: popUpAnimationStyle?.curve ?? Curves.linear,
        reverseCurve: popUpAnimationStyle?.reverseCurve ??
            const Interval(0.0, _kMenuCloseIntervalEnd),
      );
    }
    return super.createAnimation();
  }

  @override
  Duration get transitionDuration =>
      popUpAnimationStyle?.duration ?? _kMenuDuration;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  final String barrierLabel;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    int? selectedItemIndex;
    if (initialValue != null) {
      for (int index = 0;
          selectedItemIndex == null && index < items.length;
          index += 1) {
        if (items[index].represents(initialValue)) selectedItemIndex = index;
      }
    }

    final Widget menu = _PopupMenu<T>(
      route: this,
      semanticLabel: semanticLabel,
      constraints: constraints,
      clipBehavior: clipBehavior,
    );
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: Builder(
        builder: (BuildContext context) {
          return CustomSingleChildLayout(
            delegate: _PopupMenuRouteLayout(
              position,
              itemSizes,
              selectedItemIndex,
              mediaQuery.padding,
              _avoidBounds(mediaQuery),
            ),
            child: capturedThemes.wrap(menu),
          );
        },
      ),
    );
  }

  Set<Rect> _avoidBounds(MediaQueryData mediaQuery) {
    return DisplayFeatureSubScreen.avoidBounds(mediaQuery).toSet();
  }
}

/// 在 `position` 处显示包含 `items` 的弹出菜单。
///
/// `items` 应为非 null 且非空。
///
/// 如果指定了 `initialValue`，则具有匹配值的第一个项目将被高亮显示，
/// 并且 `position` 的值给出一个矩形，其水平中心将与高亮项目的水平中心对齐（如果可能）。
///
/// 如果未指定 `initialValue`，则菜单的右侧将与 `position` 矩形的右侧对齐。
///
/// 在这两种情况下，如果需要，菜单位置将被调整以适应屏幕。
///
/// 在垂直方向上，菜单的位置设置为向空间最大的方向增长。例如，如果 `position` 描述屏幕顶部边缘的矩形，
/// 则菜单的顶部边缘与 `position` 的顶部边缘对齐，菜单向下增长。
/// 如果 `position` 的两个边缘与屏幕的相对边缘等距，则菜单向下增长。
///
/// `initialValue` 在 `position` 处的定位是通过遍历 `items` 来找到第一个其
/// [MongolPopupMenuEntry.represents] 方法对 `initialValue` 返回 true 的项目，
/// 然后对列表中所有前面的小部件的 [MongolPopupMenuEntry.width] 值求和来实现的。
///
/// `elevation` 参数指定放置菜单的 z 坐标。海拔默认为 8，这是弹出菜单的适当海拔。
///
/// `context` 参数用于查找菜单的 [Navigator] 和 [Theme]。它仅在调用方法时使用。
/// 其对应的小部件可以在弹出菜单关闭之前安全地从树中移除。
///
/// `useRootNavigator` 参数用于确定是将菜单推送到离给定 `context` 最远还是最近的 [Navigator]。
/// 默认为 `false`。
///
/// `semanticLabel` 参数由辅助功能框架用于在菜单打开和关闭时宣布屏幕转换。
/// 如果未提供此标签，它将默认为 [MaterialLocalizations.popupMenuLabel]。
///
/// `clipBehavior` 参数用于裁剪菜单的形状。默认为 [Clip.none]。
///
/// 另请参阅：
///
///  * [MongolPopupMenuItem]，单个值的弹出菜单项。
///  * [MongolPopupMenuDivider]，只是一条垂直线的弹出菜单项。
///  * [MongolCheckedPopupMenuItem]，带有复选标记的弹出菜单项。
///  * [MongolPopupMenuButton]，提供一个通过自动调用此方法显示菜单的 [IconButton]。
///  * [SemanticsConfiguration.namesRoute]，用于边缘触发语义的描述。
Future<T?> showMongolMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<MongolPopupMenuEntry<T>> items,
  T? initialValue,
  double? elevation,
  Color? shadowColor,
  Color? surfaceTintColor,
  String? semanticLabel,
  ShapeBorder? shape,
  Color? color,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  Clip clipBehavior = Clip.none,
  RouteSettings? routeSettings,
  AnimationStyle? popUpAnimationStyle,
}) {
  assert(items.isNotEmpty);
  assert(debugCheckHasMaterialLocalizations(context));

  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      break;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      semanticLabel ??= MaterialLocalizations.of(context).popupMenuLabel;
  }

  final NavigatorState navigator =
      Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push(_PopupMenuRoute<T>(
    position: position,
    items: items,
    initialValue: initialValue,
    elevation: elevation,
    shadowColor: shadowColor,
    surfaceTintColor: surfaceTintColor,
    semanticLabel: semanticLabel,
    barrierLabel: MaterialLocalizations.of(context).menuDismissLabel,
    shape: shape,
    color: color,
    capturedThemes:
        InheritedTheme.capture(from: context, to: navigator.context),
    constraints: constraints,
    clipBehavior: clipBehavior,
    settings: routeSettings,
    popUpAnimationStyle: popUpAnimationStyle,
  ));
}

/// 菜单项被选中时的回调签名。
typedef MongolPopupMenuItemSelected<T> = void Function(T value);

/// 菜单关闭但未选中任何项时的回调签名。
typedef MongolPopupMenuCanceled = void Function();

/// 按钮点击后动态构建菜单项列表的回调签名。
typedef MongolPopupMenuItemBuilder<T> = List<MongolPopupMenuEntry<T>> Function(
    BuildContext context);

/// 当按下时显示菜单，并在菜单因项目被选中而被关闭时调用 [onSelected]。
/// 传递给 [onSelected] 的值是所选菜单项的值。
///
/// 可以提供 [child] 或 [icon] 中的一个，但不能同时提供两者。如果提供了 [icon]，
/// 则 [MongolPopupMenuButton] 的行为类似于 [IconButton]。
///
/// 如果两者都为 null，则会创建一个标准的溢出图标（取决于平台）。
///
/// 示例：
///
/// 此示例显示了一个包含四个项目的菜单，在枚举的值之间选择，并根据选择设置 `_selection` 字段。
///
/// ```dart
/// // 这是下面弹出菜单使用的类型。
/// enum WhyFarther { harder, smarter, selfStarter, tradingCharter }
///
/// // 此菜单按钮小部件更新 _selection 字段（类型为 WhyFarther，此处未显示）。
/// MongolPopupMenuButton<WhyFarther>(
///   onSelected: (WhyFarther result) { setState(() { _selection = result; }); },
///   itemBuilder: (BuildContext context) => <MongolPopupMenuEntry<WhyFarther>>[
///     const MongolPopupMenuItem<WhyFarther>(
///       value: WhyFarther.harder,
///       child: MongolText('Working a lot harder'),
///     ),
///     const MongolPopupMenuItem<WhyFarther>(
///       value: WhyFarther.smarter,
///       child: MongolText('Being a lot smarter'),
///     ),
///     const MongolPopupMenuItem<WhyFarther>(
///       value: WhyFarther.selfStarter,
///       child: MongolText('Being a self-starter'),
///     ),
///     const MongolPopupMenuItem<WhyFarther>(
///       value: WhyFarther.tradingCharter,
///       child: MongolText('Placed in charge of trading charter'),
///     ),
///   ],
/// )
/// ```
///
/// 另请参阅：
///
///  * [MongolPopupMenuItem]，单个值的弹出菜单项。
///  * [MongolPopupMenuDivider]，只是一条垂直线的弹出菜单项。
///  * [MongolCheckedPopupMenuItem]，带有复选标记的弹出菜单项。
///  * [showMongolMenu]，在给定位置动态显示弹出菜单的方法。
class MongolPopupMenuButton<T> extends StatefulWidget {
  /// 创建一个显示弹出菜单的按钮。
  ///
  /// [itemBuilder] 参数不能为空。
  const MongolPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onOpened,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.padding = const EdgeInsets.all(8.0),
    this.child,
    this.splashRadius,
    this.icon,
    this.iconSize,
    this.offset = Offset.zero,
    this.enabled = true,
    this.shape,
    this.color,
    this.iconColor,
    this.enableFeedback,
    this.constraints,
    this.clipBehavior = Clip.none,
    this.useRootNavigator = false,
    this.popUpAnimationStyle,
  }) : assert(
          !(child != null && icon != null),
          'You can only pass [child] or [icon], not both.',
        );

  /// 当按钮被按下时调用，用于创建要在菜单中显示的项目。
  final MongolPopupMenuItemBuilder<T> itemBuilder;

  /// 菜单项的值（如果有），在菜单打开时应被高亮显示。
  final T? initialValue;

  /// 当弹出菜单显示时调用。
  final VoidCallback? onOpened;

  /// 当用户从由此按钮创建的弹出菜单中选择值时调用。
  ///
  /// 如果弹出菜单在未选择值的情况下被关闭，则调用 [onCanceled] 代替。
  final MongolPopupMenuItemSelected<T>? onSelected;

  /// 当用户在未选择项目的情况下关闭弹出菜单时调用。
  ///
  /// 如果用户选择了值，则调用 [onSelected] 代替。
  final MongolPopupMenuCanceled? onCanceled;

  /// 描述按下按钮时将发生的操作的文本。
  ///
  /// 当用户长按按钮时显示此文本，并用于辅助功能。
  final String? tooltip;

  /// 打开菜单时放置菜单的 z 坐标。这控制菜单下方阴影的大小。
  ///
  /// 默认为 8，这是弹出菜单的适当海拔。
  final double? elevation;

  /// 用于绘制菜单下方阴影的颜色。
  ///
  /// 如果为 null，则使用环境 [PopupMenuThemeData.shadowColor]。
  /// 如果那也为 null，则使用整体主题的 [ThemeData.shadowColor]（默认黑色）。
  final Color? shadowColor;

  /// 用作 [color] 上的覆盖层以指示海拔的颜色。
  ///
  /// 如果为 null，则使用 [PopupMenuThemeData.surfaceTintColor]。
  /// 如果那也为 null，则默认值为 [ColorScheme.surfaceTint]。
  ///
  /// 有关如何应用此覆盖层的更多详细信息，请参阅 [Material.surfaceTintColor]。
  final Color? surfaceTintColor;

  /// 默认匹配 IconButton 的 8 dps 内边距。在某些情况下，特别是当此按钮作为列表项的尾随元素出现时，
  /// 能够将内边距设置为零是很有用的。
  final EdgeInsetsGeometry padding;

  /// 水波纹效果的半径。
  ///
  /// 如果为 null，则使用 [InkWell] 或 [IconButton] 的默认水波纹半径。
  final double? splashRadius;

  /// 如果提供，[child] 是为此按钮使用的小部件，
  /// 并且按钮将使用 [InkWell] 进行点击。
  final Widget? child;

  /// 如果提供，[icon] 用于此按钮，
  /// 并且按钮将表现得像 [IconButton]。
  final Widget? icon;

  /// The offset applied to the Popup Menu Button.
  ///
  /// When not set, the Popup Menu Button will be positioned directly next to
  /// the button that was used to create it.
  final Offset offset;

  /// Whether this popup menu button is interactive.
  ///
  /// Must be non-null, defaults to `true`
  ///
  /// If `true` the button will respond to presses by displaying the menu.
  ///
  /// If `false`, the button is styled with the disabled color from the
  /// current [Theme] and will not respond to presses or show the popup
  /// menu and [onSelected], [onCanceled] and [itemBuilder] will not be called.
  ///
  /// This can be useful in situations where the app needs to show the button,
  /// but doesn't currently have anything to show in the menu.
  final bool enabled;

  /// If provided, the shape used for the menu.
  ///
  /// If this property is null, then [PopupMenuThemeData.shape] is used.
  /// If [PopupMenuThemeData.shape] is also null, then the default shape for
  /// [MaterialType.card] is used. This default shape is a rectangle with
  /// rounded edges of BorderRadius.circular(2.0).
  final ShapeBorder? shape;

  /// If provided, the background color used for the menu.
  ///
  /// If this property is null, then [PopupMenuThemeData.color] is used.
  /// If [PopupMenuThemeData.color] is also null, then
  /// Theme.of(context).cardColor is used.
  final Color? color;

  /// If provided, this color is used for the button icon.
  ///
  /// If this property is null, then [PopupMenuThemeData.iconColor] is used.
  /// If [PopupMenuThemeData.iconColor] is also null then defaults to
  /// [IconThemeData.color].
  final Color? iconColor;

  /// Whether detected gestures should provide acoustic and/or haptic feedback.
  ///
  /// For example, on Android a tap will produce a clicking sound and a
  /// long-press will produce a short vibration, when feedback is enabled.
  ///
  /// See also:
  ///
  ///  * [Feedback] for providing platform-specific feedback to certain actions.
  final bool? enableFeedback;

  /// 如果提供，[Icon] 的大小。
  ///
  /// 如果此属性为 null，默认大小为 24.0 像素。
  final double? iconSize;

  /// 菜单的可选大小约束。
  ///
  /// 未指定时，默认为：
  /// ```dart
  /// const BoxConstraints(
  ///   minWidth: 2.0 * 56.0,
  ///   maxWidth: 5.0 * 56.0,
  /// )
  /// ```
  ///
  /// 默认约束确保菜单宽度匹配材料设计指南推荐的最大宽度。
  /// 指定此参数可以创建比默认最大宽度更宽的菜单。
  final BoxConstraints? constraints;

  /// 菜单的裁剪行为。
  ///
  /// [clipBehavior] 参数用于裁剪菜单的形状。
  ///
  /// 默认为 [Clip.none]。
  final Clip clipBehavior;

  /// 用于确定是将菜单推送到离给定 `context` 最远还是最近的 [Navigator]。
  ///
  /// 默认为 false。
  final bool useRootNavigator;

  /// 用于覆盖弹出菜单打开和关闭过渡的默认动画曲线和持续时间。
  ///
  /// 如果提供了 [AnimationStyle.curve]，它将用于覆盖默认的弹出动画曲线。
  /// 否则，默认为 [Curves.linear]。
  ///
  /// 如果提供了 [AnimationStyle.reverseCurve]，它将用于覆盖默认的弹出动画反向曲线。
  /// 否则，默认为 `Interval(0.0, 2.0 / 3.0)`。
  ///
  /// 如果提供了 [AnimationStyle.duration]，它将用于覆盖默认的弹出动画持续时间。
  /// 否则，默认为 300ms。
  ///
  /// 要禁用主题动画，请使用 [AnimationStyle.noAnimation]。
  ///
  /// 如果为 null，则使用默认动画。
  final AnimationStyle? popUpAnimationStyle;

  @override
  MongolPopupMenuButtonState<T> createState() =>
      MongolPopupMenuButtonState<T>();
}

/// [MongolPopupMenuButton] 的 [State]。
///
/// 有关如何以编程方式打开按钮状态的弹出菜单，请参阅 [showButtonMenu]。
class MongolPopupMenuButtonState<T> extends State<MongolPopupMenuButton<T>> {
  /// 一个在 [MongolPopupMenuButton] 的位置显示带有提供给 [MongolPopupMenuButton.itemBuilder] 的项目的弹出菜单的方法。
  ///
  /// 默认情况下，当用户点击按钮且 [MongolPopupMenuButton.enabled] 设置为 `true` 时调用。
  /// 此外，您可以通过手动调用此方法来打开按钮。
  ///
  /// 您可以使用 [GlobalKey] 访问 [MongolPopupMenuButtonState]，
  /// 并使用 `globalKey.currentState.showButtonMenu` 显示按钮的菜单。
  void showButtonMenu() {
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final RelativeRect menuPosition = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(widget.offset, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero) + widget.offset,
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final List<MongolPopupMenuEntry<T>> items = widget.itemBuilder(context);
    if (items.isNotEmpty) {
      widget.onOpened?.call();
      showMongolMenu<T?>(
        context: context,
        elevation: widget.elevation ?? popupMenuTheme.elevation,
        shadowColor: widget.shadowColor ?? popupMenuTheme.shadowColor,
        surfaceTintColor:
            widget.surfaceTintColor ?? popupMenuTheme.surfaceTintColor,
        items: items,
        initialValue: widget.initialValue,
        position: menuPosition,
        shape: widget.shape ?? popupMenuTheme.shape,
        color: widget.color ?? popupMenuTheme.color,
        constraints: widget.constraints,
        clipBehavior: widget.clipBehavior,
        useRootNavigator: widget.useRootNavigator,
        popUpAnimationStyle: widget.popUpAnimationStyle,
      ).then<void>((T? newValue) {
        if (!mounted) return null;
        if (newValue == null) {
          widget.onCanceled?.call();
          return null;
        }
        widget.onSelected?.call(newValue);
      });
    }
  }

  bool get _canRequestFocus {
    final NavigationMode mode =
        MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
    switch (mode) {
      case NavigationMode.traditional:
        return widget.enabled;
      case NavigationMode.directional:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final bool enableFeedback =
        widget.enableFeedback ?? popupMenuTheme.enableFeedback ?? true;
    assert(debugCheckHasMaterialLocalizations(context));

    if (widget.child != null) {
      return MongolTooltip(
        message:
            widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          onTap: widget.enabled ? showButtonMenu : null,
          canRequestFocus: _canRequestFocus,
          radius: widget.splashRadius,
          enableFeedback: enableFeedback,
          child: widget.child,
        ),
      );
    }

    return MongolIconButton(
      icon: widget.icon ?? Icon(Icons.adaptive.more),
      padding: widget.padding,
      splashRadius: widget.splashRadius,
      iconSize: widget.iconSize ?? popupMenuTheme.iconSize ?? iconTheme.size,
      color: widget.iconColor ?? popupMenuTheme.iconColor ?? iconTheme.color,
      tooltip:
          widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
      onPressed: widget.enabled ? showButtonMenu : null,
      enableFeedback: enableFeedback,
    );
  }
}

// Resolves mouse cursor from widget override -> theme -> fallback.
class _EffectiveMouseCursor extends WidgetStateMouseCursor {
  const _EffectiveMouseCursor(this.widgetCursor, this.themeCursor);

  final MouseCursor? widgetCursor;
  final WidgetStateProperty<MouseCursor?>? themeCursor;

  @override
  MouseCursor resolve(Set<WidgetState> states) {
    return WidgetStateProperty.resolveAs<MouseCursor?>(widgetCursor, states) ??
        themeCursor?.resolve(states) ??
        WidgetStateMouseCursor.clickable.resolve(states);
  }

  @override
  String get debugDescription => 'MaterialStateMouseCursor(PopupMenuItemState)';
}

class _PopupMenuDefaultsM2 extends PopupMenuThemeData {
  _PopupMenuDefaultsM2(this.context) : super(elevation: 8.0);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final TextTheme _textTheme = _theme.textTheme;

  @override
  TextStyle? get textStyle => _textTheme.titleMedium;

  static EdgeInsets menuVerticalPadding =
      const EdgeInsets.symmetric(vertical: 16.0);
}

// BEGIN GENERATED TOKEN PROPERTIES - PopupMenu

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _PopupMenuDefaultsM3 extends PopupMenuThemeData {
  _PopupMenuDefaultsM3(this.context) : super(elevation: 3.0);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;
  late final TextTheme _textTheme = _theme.textTheme;

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      final TextStyle style = _textTheme.labelLarge!;
      if (states.contains(WidgetState.disabled)) {
        return style.apply(color: _colors.onSurface.withValues(alpha: 0.38));
      }
      return style.apply(color: _colors.onSurface);
    });
  }

  @override
  Color? get color => _colors.surface;

  @override
  Color? get shadowColor => _colors.shadow;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  ShapeBorder? get shape => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4.0)));

  // TODO(tahatesser): This is taken from https://m3.material.io/components/menus/specs
  // Update this when the token is available.
  static EdgeInsets menuVerticalPadding =
      const EdgeInsets.symmetric(vertical: 12.0);
}
// END GENERATED TOKEN PROPERTIES - PopupMenu
