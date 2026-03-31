part of '../mongol_input_decorator.dart';

class MongolInputDecorator extends StatefulWidget {
  /// Creates a widget that displays a border, labels, and icons,
  /// for a [MongolTextField].
  ///
  /// The [isFocused], [isHovering], [expands], and [isEmpty] arguments must not
  /// be null.
  const MongolInputDecorator({
    super.key,
    required this.decoration,
    this.baseStyle,
    this.textAlign,
    this.textAlignHorizontal,
    this.isFocused = false,
    this.isHovering = false,
    this.expands = false,
    this.isEmpty = false,
    this.child,
  });

  /// The text and styles to use when decorating the child.
  ///
  /// Null [InputDecoration] properties are initialized with the corresponding
  /// values from [ThemeData.inputDecorationTheme].
  ///
  /// Must not be null.
  final InputDecoration decoration;

  /// The style on which to base the label, hint, counter, and error styles
  /// if the [decoration] does not provide explicit styles.
  ///
  /// If null, `baseStyle` defaults to the `subtitle1` style from the
  /// current [Theme], see [ThemeData.textTheme].
  ///
  /// The [TextStyle.textBaseline] of the [baseStyle] is used to determine
  /// the baseline used for text alignment.
  final TextStyle? baseStyle;

  /// How the text in the decoration should be aligned vertically.
  final MongolTextAlign? textAlign;

  /// How the text should be aligned horizontally.
  ///
  /// Determines the alignment of the baseline within the available space of
  /// the input (typically a `MongolTextField`). For example,
  /// `TextAlignHorizontal.left` will place the baseline such that the text,
  /// and any attached decoration like prefix and suffix, is as close to the
  /// left side of the input as possible without overflowing. The widths of the
  /// prefix and suffix are similarly included for other alignment values. If
  /// the width is greater than the width available, then the prefix and suffix
  /// will be allowed to overflow first before the text scrolls.
  final TextAlignHorizontal? textAlignHorizontal;

  /// Whether the input field has focus.
  ///
  /// Determines the position of the label text and the color and weight of the
  /// border.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///
  ///  * [InputDecoration.hoverColor], which is also blended into the focus
  ///    color and fill color when the [isHovering] is true to produce the final
  ///    color.
  final bool isFocused;

  /// Whether the input field is being hovered over by a mouse pointer.
  ///
  /// Determines the container fill color, which is a blend of
  /// [InputDecoration.hoverColor] with [InputDecoration.fillColor] when
  /// true, and [InputDecoration.fillColor] when not.
  ///
  /// Defaults to false.
  final bool isHovering;

  /// If true, the width of the input field will be as large as possible.
  ///
  /// If wrapped in a widget that constrains its child's width, like Expanded
  /// or SizedBox, the input field will only be affected if [expands] is set to
  /// true.
  ///
  /// See [MongolTextField.minLines] and [MongolTextField.maxLines] for related
  /// ways to affect the width of an input. When [expands] is true, both must
  /// be null in order to avoid ambiguity in determining the width.
  ///
  /// Defaults to false.
  final bool expands;

  /// Whether the input field is empty.
  ///
  /// Determines the position of the label text and whether to display the hint
  /// text.
  ///
  /// Defaults to false.
  final bool isEmpty;

  /// The widget below this widget in the tree.
  ///
  /// Typically a [MongolEditableText], [DropdownButton], or [InkWell].
  final Widget? child;

  /// Whether the label needs to get out of the way of the input, either by
  /// floating or disappearing.
  ///
  /// Will withdraw when not empty, or when focused while enabled.
  bool get _labelShouldWithdraw =>
      !isEmpty || (isFocused && decoration.enabled);

  @override
  State<MongolInputDecorator> createState() => _InputDecoratorState();

  /// The RenderBox that defines this decorator's "container". That's the
  /// area which is filled if [InputDecoration.filled] is true. It's the area
  /// adjacent to [InputDecoration.icon] and to the left of the widgets that contain
  /// [InputDecoration.helperText], [InputDecoration.errorText], and
  /// [InputDecoration.counterText].
  ///
  /// [MongolTextField] renders ink splashes within the container.
  static RenderBox? containerOf(BuildContext context) {
    final result = context.findAncestorRenderObjectOfType<_RenderDecoration>();
    return result?.container;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<InputDecoration>('decoration', decoration));
    properties.add(DiagnosticsProperty<TextStyle>('baseStyle', baseStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('isFocused', isFocused));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('isEmpty', isEmpty));
  }
}

class _InputDecoratorState extends State<MongolInputDecorator>
    with TickerProviderStateMixin {
  late final AnimationController _floatingLabelController;
  late final Animation<double> _floatingLabelAnimation;
  late final AnimationController _shakingLabelController;
  final _InputBorderGap _borderGap = _InputBorderGap();
  static const OrdinalSortKey _kPrefixSemanticsSortOrder = OrdinalSortKey(0);
  static const OrdinalSortKey _kInputSemanticsSortOrder = OrdinalSortKey(1);
  static const OrdinalSortKey _kSuffixSemanticsSortOrder = OrdinalSortKey(2);
  static const SemanticsTag _kPrefixSemanticsTag =
      SemanticsTag('_InputDecoratorState.prefix');
  static const SemanticsTag _kSuffixSemanticsTag =
      SemanticsTag('_InputDecoratorState.suffix');

  @override
  void initState() {
    super.initState();

    final labelIsInitiallyFloating = widget.decoration.floatingLabelBehavior ==
            FloatingLabelBehavior.always ||
        (widget.decoration.floatingLabelBehavior !=
                FloatingLabelBehavior.never &&
            widget._labelShouldWithdraw);

    _floatingLabelController = AnimationController(
        duration: _kTransitionDuration,
        vsync: this,
        value: labelIsInitiallyFloating ? 1.0 : 0.0);
    _floatingLabelController.addListener(_handleChange);
    _floatingLabelAnimation = CurvedAnimation(
      parent: _floatingLabelController,
      curve: _kTransitionCurve,
      reverseCurve: _kTransitionCurve.flipped,
    );

    _shakingLabelController = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveDecoration = null;
  }

  @override
  void dispose() {
    _floatingLabelController.dispose();
    _shakingLabelController.dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {
      // The _floatingLabelController's value has changed.
    });
  }

  InputDecoration? _effectiveDecoration;

  InputDecoration get decoration => _effectiveDecoration ??=
      widget.decoration.applyDefaults(Theme.of(context).inputDecorationTheme);

  MongolTextAlign? get textAlign => widget.textAlign;

  bool get isFocused => widget.isFocused;

  bool get _hasError =>
      decoration.errorText != null || decoration.error != null;

  bool get isHovering => widget.isHovering && decoration.enabled;

  bool get isEmpty => widget.isEmpty;

  bool get _floatingLabelEnabled {
    return decoration.floatingLabelBehavior != FloatingLabelBehavior.never;
  }

  @override
  void didUpdateWidget(MongolInputDecorator old) {
    super.didUpdateWidget(old);
    if (widget.decoration != old.decoration) {
      _effectiveDecoration = null;
    }

    final floatBehaviorChanged = widget.decoration.floatingLabelBehavior !=
        old.decoration.floatingLabelBehavior;

    if (widget._labelShouldWithdraw != old._labelShouldWithdraw ||
        floatBehaviorChanged) {
      if (_floatingLabelEnabled &&
          (widget._labelShouldWithdraw ||
              widget.decoration.floatingLabelBehavior ==
                  FloatingLabelBehavior.always)) {
        _floatingLabelController.forward();
      } else {
        _floatingLabelController.reverse();
      }
    }

    final String? errorText = decoration.errorText;
    final String? oldErrorText = old.decoration.errorText;

    if (_floatingLabelController.isCompleted &&
        errorText != null &&
        errorText != oldErrorText) {
      _shakingLabelController
        ..value = 0.0
        ..forward();
    }
  }

  Color _getDefaultM2BorderColor(ThemeData themeData) {
    if (!decoration.enabled && !isFocused) {
      return ((decoration.filled ?? false) &&
              !(decoration.border?.isOutline ?? false))
          ? Colors.transparent
          : themeData.disabledColor;
    }
    if (_hasError) {
      return themeData.colorScheme.error;
    }
    if (isFocused) {
      return themeData.colorScheme.primary;
    }
    if (decoration.filled!) {
      return themeData.hintColor;
    }
    final Color enabledColor = themeData.colorScheme.onSurface.withAlpha(0x61);
    if (isHovering) {
      final Color hoverColor = decoration.hoverColor ??
          themeData.inputDecorationTheme.hoverColor ??
          themeData.hoverColor;
      return Color.alphaBlend(hoverColor.withAlpha(0x1f), enabledColor);
    }
    return enabledColor;
  }

  Color _getFillColor(ThemeData themeData, InputDecorationTheme defaults) {
    if (decoration.filled != true) {
      // filled == null same as filled == false
      return Colors.transparent;
    }
    if (decoration.fillColor != null) {
      return WidgetStateProperty.resolveAs(
          decoration.fillColor!, materialState);
    }
    return WidgetStateProperty.resolveAs(defaults.fillColor!, materialState);
  }

  Color _getHoverColor(ThemeData themeData) {
    if (decoration.filled == null ||
        !decoration.filled! ||
        isFocused ||
        !decoration.enabled) {
      return Colors.transparent;
    }
    return decoration.hoverColor ??
        themeData.inputDecorationTheme.hoverColor ??
        themeData.hoverColor;
  }

  Color _getIconColor(ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(decoration.iconColor, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.iconColor, materialState) ??
        WidgetStateProperty.resolveAs(defaults.iconColor!, materialState);
  }

  Color _getPrefixIconColor(
      ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(
            decoration.prefixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.prefixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(defaults.prefixIconColor!, materialState);
  }

  Color _getSuffixIconColor(
      ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(
            decoration.suffixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.suffixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(defaults.suffixIconColor!, materialState);
  }

  // True if the label will be shown and the hint will not.
  // If we're not focused, there's no value, labelText was provided, and
  // floatingLabelBehavior isn't set to always, then the label appears where the
  // hint would.
  bool get _hasInlineLabel {
    return !widget._labelShouldWithdraw &&
        (decoration.labelText != null || decoration.label != null) &&
        decoration.floatingLabelBehavior != FloatingLabelBehavior.always;
  }

  // If the label is a floating placeholder, it's always shown.
  bool get _shouldShowLabel => _hasInlineLabel || _floatingLabelEnabled;

  // The base style for the inline label when they're displayed "inline",
  // i.e. when they appear in place of the empty text field.
  TextStyle _getInlineLabelStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    final TextStyle defaultStyle =
        WidgetStateProperty.resolveAs(defaults.labelStyle!, materialState);

    final TextStyle? style =
        WidgetStateProperty.resolveAs(decoration.labelStyle, materialState) ??
            WidgetStateProperty.resolveAs(
                themeData.inputDecorationTheme.labelStyle, materialState);

    return themeData.textTheme.titleMedium!
        .merge(widget.baseStyle)
        .merge(defaultStyle)
        .merge(style)
        .copyWith(height: 1);
  }

  // The base style for the inline hint when they're displayed "inline",
  // i.e. when they appear in place of the empty text field.
  TextStyle _getInlineHintStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    final TextStyle defaultStyle =
        WidgetStateProperty.resolveAs(defaults.hintStyle!, materialState);

    final TextStyle? style =
        WidgetStateProperty.resolveAs(decoration.hintStyle, materialState) ??
            WidgetStateProperty.resolveAs(
                themeData.inputDecorationTheme.hintStyle, materialState);

    return themeData.textTheme.titleMedium!
        .merge(widget.baseStyle)
        .merge(defaultStyle)
        .merge(style);
  }

  TextStyle _getFloatingLabelStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    TextStyle defaultTextStyle = WidgetStateProperty.resolveAs(
        defaults.floatingLabelStyle!, materialState);
    if (_hasError && decoration.errorStyle?.color != null) {
      defaultTextStyle =
          defaultTextStyle.copyWith(color: decoration.errorStyle?.color);
    }
    defaultTextStyle = defaultTextStyle
        .merge(decoration.floatingLabelStyle ?? decoration.labelStyle);

    final TextStyle? style = WidgetStateProperty.resolveAs(
            decoration.floatingLabelStyle, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.floatingLabelStyle, materialState);

    return themeData.textTheme.titleMedium!
        .merge(widget.baseStyle)
        .copyWith(height: 1)
        .merge(defaultTextStyle)
        .merge(style);
  }

  TextStyle _getHelperStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(defaults.helperStyle!, materialState)
        .merge(WidgetStateProperty.resolveAs(
            decoration.helperStyle, materialState));
  }

  TextStyle _getErrorStyle(ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(defaults.errorStyle!, materialState)
        .merge(decoration.errorStyle);
  }

  Set<WidgetState> get materialState {
    return <WidgetState>{
      if (!decoration.enabled) WidgetState.disabled,
      if (isFocused) WidgetState.focused,
      if (isHovering) WidgetState.hovered,
      if (_hasError) WidgetState.error,
    };
  }

  InputBorder _getDefaultBorder(
      ThemeData themeData, InputDecorationTheme defaults) {
    final InputBorder border =
        WidgetStateProperty.resolveAs(decoration.border, materialState) ??
            const SidelineInputBorder();

    if (decoration.border is WidgetStateProperty<InputBorder>) {
      return border;
    }

    if (border.borderSide == BorderSide.none) {
      return border;
    }

    if (themeData.useMaterial3) {
      if (decoration.filled!) {
        return border.copyWith(
          borderSide: WidgetStateProperty.resolveAs(
              defaults.activeIndicatorBorder, materialState),
        );
      } else {
        return border.copyWith(
          borderSide: WidgetStateProperty.resolveAs(
              defaults.outlineBorder, materialState),
        );
      }
    } else {
      return border.copyWith(
        borderSide: BorderSide(
          color: _getDefaultM2BorderColor(themeData),
          width: ((decoration.isCollapsed ??
                      themeData.inputDecorationTheme.isCollapsed) ||
                  decoration.border == InputBorder.none ||
                  !decoration.enabled)
              ? 0.0
              : isFocused
                  ? 2.0
                  : 1.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final InputDecorationTheme defaults = Theme.of(context).useMaterial3
        ? _InputDecoratorDefaultsM3(context)
        : _InputDecoratorDefaultsM2(context);

    final TextStyle labelStyle = _getInlineLabelStyle(themeData, defaults);
    final TextBaseline textBaseline = labelStyle.textBaseline!;

    final TextStyle hintStyle = _getInlineHintStyle(themeData, defaults);
    final String? hintText = decoration.hintText;
    final Widget? hint = hintText == null
        ? null
        : AnimatedOpacity(
            opacity: (isEmpty && !_hasInlineLabel) ? 1.0 : 0.0,
            duration:
                decoration.hintFadeDuration ?? _kHintFadeTransitionDuration,
            curve: _kTransitionCurve,
            child: MongolText(
              hintText,
              style: hintStyle,
              overflow: hintStyle.overflow ?? TextOverflow.ellipsis,
              textAlign: textAlign,
              maxLines: decoration.hintMaxLines,
            ),
          );

    InputBorder? border;
    if (!decoration.enabled) {
      border = _hasError ? decoration.errorBorder : decoration.disabledBorder;
    } else if (isFocused) {
      border =
          _hasError ? decoration.focusedErrorBorder : decoration.focusedBorder;
    } else {
      border = _hasError ? decoration.errorBorder : decoration.enabledBorder;
    }
    border ??= _getDefaultBorder(themeData, defaults);

    final Widget container = _BorderContainer(
      border: border,
      gap: _borderGap,
      gapAnimation: _floatingLabelAnimation,
      fillColor: _getFillColor(themeData, defaults),
      hoverColor: _getHoverColor(themeData),
      isHovering: isHovering,
    );

    final Widget? label =
        decoration.labelText == null && decoration.label == null
            ? null
            : _Shaker(
                animation: _shakingLabelController.view,
                child: AnimatedOpacity(
                  duration: _kTransitionDuration,
                  curve: _kTransitionCurve,
                  opacity: _shouldShowLabel ? 1.0 : 0.0,
                  child: AnimatedDefaultTextStyle(
                    duration: _kTransitionDuration,
                    curve: _kTransitionCurve,
                    style: widget._labelShouldWithdraw
                        ? _getFloatingLabelStyle(themeData, defaults)
                        : labelStyle,
                    child: decoration.label ??
                        MongolText(
                          decoration.labelText!,
                          overflow: TextOverflow.ellipsis,
                          textAlign: textAlign,
                        ),
                  ),
                ),
              );

    final bool hasPrefix =
        decoration.prefix != null || decoration.prefixText != null;
    final bool hasSuffix =
        decoration.suffix != null || decoration.suffixText != null;

    Widget? input = widget.child;
    // If at least two out of the three are visible, it needs semantics sort
    // order.
    final bool needsSemanticsSortOrder = widget._labelShouldWithdraw &&
        (input != null ? (hasPrefix || hasSuffix) : (hasPrefix && hasSuffix));

    final Widget? prefix = hasPrefix
        ? _AffixText(
            labelIsFloating: widget._labelShouldWithdraw,
            text: decoration.prefixText,
            style: WidgetStateProperty.resolveAs(
                    decoration.prefixStyle, materialState) ??
                hintStyle,
            semanticsSortKey:
                needsSemanticsSortOrder ? _kPrefixSemanticsSortOrder : null,
            semanticsTag: _kPrefixSemanticsTag,
            child: decoration.prefix,
          )
        : null;

    final Widget? suffix = hasSuffix
        ? _AffixText(
            labelIsFloating: widget._labelShouldWithdraw,
            text: decoration.suffixText,
            style: WidgetStateProperty.resolveAs(
                    decoration.suffixStyle, materialState) ??
                hintStyle,
            semanticsSortKey:
                needsSemanticsSortOrder ? _kSuffixSemanticsSortOrder : null,
            semanticsTag: _kSuffixSemanticsTag,
            child: decoration.suffix,
          )
        : null;

    if (input != null && needsSemanticsSortOrder) {
      input = Semantics(
        sortKey: _kInputSemanticsSortOrder,
        child: input,
      );
    }

    final bool decorationIsDense = decoration.isDense ?? false;
    final double iconSize = decorationIsDense ? 18.0 : 24.0;

    final Widget? icon = decoration.icon == null
        ? null
        : MouseRegion(
            cursor: SystemMouseCursors.basic,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 16.0),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: _getIconColor(themeData, defaults),
                  size: iconSize,
                ),
                child: decoration.icon!,
              ),
            ),
          );

    final Widget? prefixIcon = decoration.prefixIcon == null
        ? null
        : Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: ConstrainedBox(
                constraints: decoration.prefixIconConstraints ??
                    themeData.visualDensity.effectiveConstraints(
                      const BoxConstraints(
                        minWidth: kMinInteractiveDimension,
                        minHeight: kMinInteractiveDimension,
                      ),
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: _getPrefixIconColor(themeData, defaults),
                    size: iconSize,
                  ),
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        foregroundColor:
                            _getPrefixIconColor(themeData, defaults),
                        iconSize: iconSize,
                      ),
                    ),
                    child: Semantics(
                      child: decoration.prefixIcon,
                    ),
                  ),
                ),
              ),
            ),
          );

    final Widget? suffixIcon = decoration.suffixIcon == null
        ? null
        : Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: ConstrainedBox(
                constraints: decoration.suffixIconConstraints ??
                    themeData.visualDensity.effectiveConstraints(
                      const BoxConstraints(
                        minWidth: kMinInteractiveDimension,
                        minHeight: kMinInteractiveDimension,
                      ),
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: _getSuffixIconColor(themeData, defaults),
                    size: iconSize,
                  ),
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        foregroundColor:
                            _getSuffixIconColor(themeData, defaults),
                        iconSize: iconSize,
                      ),
                    ),
                    child: Semantics(
                      child: decoration.suffixIcon,
                    ),
                  ),
                ),
              ),
            ),
          );

    final Widget helperError = _HelperError(
      textAlign: textAlign,
      helperText: decoration.helperText,
      helperStyle: _getHelperStyle(themeData, defaults),
      helperMaxLines: decoration.helperMaxLines,
      error: decoration.error,
      errorText: decoration.errorText,
      errorStyle: _getErrorStyle(themeData, defaults),
      errorMaxLines: decoration.errorMaxLines,
    );

    Widget? counter;
    if (decoration.counter != null) {
      counter = decoration.counter;
    } else if (decoration.counterText != null && decoration.counterText != '') {
      counter = Semantics(
        container: true,
        liveRegion: isFocused,
        child: MongolText(
          decoration.counterText!,
          style: _getHelperStyle(themeData, defaults).merge(
              WidgetStateProperty.resolveAs(
                  decoration.counterStyle, materialState)),
          overflow: TextOverflow.ellipsis,
          semanticsLabel: decoration.semanticCounterText,
        ),
      );
    }

    // The _Decoration widget and _RenderDecoration assume that contentPadding
    // has been resolved to EdgeInsets.
    const textDirection = TextDirection.ltr;
    final EdgeInsets? decorationContentPadding =
        decoration.contentPadding?.resolve(textDirection);

    final EdgeInsets contentPadding;
    final double floatingLabelWidth;
    if (decoration.isCollapsed ?? themeData.inputDecorationTheme.isCollapsed) {
      floatingLabelWidth = 0.0;
      contentPadding = decorationContentPadding ?? EdgeInsets.zero;
    } else if (!border.isOutline) {
      // 4.0: the horizontal gap between the inline elements and the floating label.
      floatingLabelWidth = MediaQuery.textScalerOf(context)
          .scale((4.0 + 0.75 * labelStyle.fontSize!));
      if (decoration.filled ?? false) {
        contentPadding = decorationContentPadding ??
            (decorationIsDense
                ? const EdgeInsets.fromLTRB(8.0, 12.0, 8.0, 12.0)
                : const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0));
      } else {
        // Not top or bottom padding for underline borders that aren't filled
        // is a small concession to backwards compatibility. This eliminates
        // the most noticeable layout change introduced by #13734.
        contentPadding = decorationContentPadding ??
            (decorationIsDense
                ? const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0)
                : const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0));
      }
    } else {
      floatingLabelWidth = 0.0;
      contentPadding = decorationContentPadding ??
          (decorationIsDense
              ? const EdgeInsets.fromLTRB(20.0, 12.0, 12.0, 12.0)
              : const EdgeInsets.fromLTRB(24.0, 12.0, 16.0, 12.0));
    }

    final _Decorator decorator = _Decorator(
      decoration: _Decoration(
          contentPadding: contentPadding,
          isCollapsed: decoration.isCollapsed ??
              themeData.inputDecorationTheme.isCollapsed,
          floatingLabelWidth: floatingLabelWidth,
          floatingLabelAlignment: decoration.floatingLabelAlignment!,
          floatingLabelProgress: _floatingLabelAnimation.value,
          border: border,
          borderGap: _borderGap,
          alignLabelWithHint: decoration.alignLabelWithHint ?? false,
          isDense: decoration.isDense,
          visualDensity: themeData.visualDensity,
          icon: icon,
          input: input,
          label: label,
          hint: hint,
          prefix: prefix,
          suffix: suffix,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          helperError: helperError,
          counter: counter,
          container: container),
      textBaseline: textBaseline,
      textAlignHorizontal: widget.textAlignHorizontal,
      isFocused: isFocused,
      expands: widget.expands,
      isEmpty: isEmpty,
    );

    final BoxConstraints? constraints =
        decoration.constraints ?? themeData.inputDecorationTheme.constraints;
    if (constraints != null) {
      return ConstrainedBox(
        constraints: constraints,
        child: decorator,
      );
    }
    return decorator;
  }
}

