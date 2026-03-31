part of '../mongol_input_decorator.dart';

class _InputDecoratorDefaultsM2 extends InputDecorationTheme {
  const _InputDecoratorDefaultsM2(this.context) : super();

  final BuildContext context;

  @override
  TextStyle? get hintStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  TextStyle? get labelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  TextStyle? get floatingLabelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        if (states.contains(WidgetState.error)) {
          return TextStyle(color: Theme.of(context).colorScheme.error);
        }
        if (states.contains(WidgetState.focused)) {
          return TextStyle(color: Theme.of(context).colorScheme.primary);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  TextStyle? get helperStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final ThemeData themeData = Theme.of(context);
        if (states.contains(WidgetState.disabled)) {
          return themeData.textTheme.bodySmall!
              .copyWith(color: Colors.transparent);
        }

        return themeData.textTheme.bodySmall!
            .copyWith(color: themeData.hintColor);
      });

  @override
  TextStyle? get errorStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final ThemeData themeData = Theme.of(context);
        if (states.contains(WidgetState.disabled)) {
          return themeData.textTheme.bodySmall!
              .copyWith(color: Colors.transparent);
        }
        return themeData.textTheme.bodySmall!
            .copyWith(color: themeData.colorScheme.error);
      });

  @override
  Color? get fillColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          // dark theme: 5% white
          // light theme: 2% black
          switch (Theme.of(context).brightness) {
            case Brightness.dark:
              return const Color(0x0DFFFFFF);
            case Brightness.light:
              return const Color(0x05000000);
          }
        }
        // dark theme: 10% white
        // light theme: 4% black
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return const Color(0x1AFFFFFF);
          case Brightness.light:
            return const Color(0x0A000000);
        }
      });

  @override
  Color? get iconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled) &&
            !states.contains(WidgetState.focused)) {
          return Theme.of(context).disabledColor;
        }
        if (states.contains(WidgetState.focused)) {
          return Theme.of(context).colorScheme.primary;
        }
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return Colors.white70;
          case Brightness.light:
            return Colors.black45;
        }
      });

  @override
  Color? get prefixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled) &&
            !states.contains(WidgetState.focused)) {
          return Theme.of(context).disabledColor;
        }
        if (states.contains(WidgetState.focused)) {
          return Theme.of(context).colorScheme.primary;
        }
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return Colors.white70;
          case Brightness.light:
            return Colors.black45;
        }
      });

  @override
  Color? get suffixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled) &&
            !states.contains(WidgetState.focused)) {
          return Theme.of(context).disabledColor;
        }
        if (states.contains(WidgetState.focused)) {
          return Theme.of(context).colorScheme.primary;
        }
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return Colors.white70;
          case Brightness.light:
            return Colors.black45;
        }
      });
}

class _InputDecoratorDefaultsM3 extends InputDecorationTheme {
  _InputDecoratorDefaultsM3(this.context) : super();

  final BuildContext context;

  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  TextStyle? get hintStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  Color? get fillColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withAlpha(0xa);
        }
        return _colors.surfaceContainerHighest;
      });

  @override
  BorderSide? get activeIndicatorBorder =>
      WidgetStateBorderSide.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _colors.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: _colors.error, width: 2.0);
          }
          return BorderSide(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: _colors.onSurface);
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: _colors.primary, width: 2.0);
        }
        return BorderSide(color: _colors.onSurfaceVariant);
      });

  @override
  BorderSide? get outlineBorder =>
      WidgetStateBorderSide.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _colors.onSurface.withValues(alpha: 0.12));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: _colors.error, width: 2.0);
          }
          return BorderSide(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: _colors.onSurface);
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: _colors.primary, width: 2.0);
        }
        return BorderSide(color: _colors.outline);
      });

  @override
  Color? get iconColor => _colors.onSurfaceVariant;

  @override
  Color? get prefixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        return _colors.onSurfaceVariant;
      });

  @override
  Color? get suffixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.error)) {
          return _colors.error;
        }
        return _colors.onSurfaceVariant;
      });

  @override
  TextStyle? get labelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodyLarge ?? const TextStyle();
        if (states.contains(WidgetState.disabled)) {
          return textStyle.copyWith(
              color: _colors.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return textStyle.copyWith(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return textStyle.copyWith(color: _colors.error);
          }
          return textStyle.copyWith(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return textStyle.copyWith(color: _colors.onSurfaceVariant);
        }
        if (states.contains(WidgetState.focused)) {
          return textStyle.copyWith(color: _colors.primary);
        }
        return textStyle.copyWith(color: _colors.onSurfaceVariant);
      });

  @override
  TextStyle? get floatingLabelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodyLarge ?? const TextStyle();
        if (states.contains(WidgetState.disabled)) {
          return textStyle.copyWith(
              color: _colors.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return textStyle.copyWith(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return textStyle.copyWith(color: _colors.error);
          }
          return textStyle.copyWith(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return textStyle.copyWith(color: _colors.onSurfaceVariant);
        }
        if (states.contains(WidgetState.focused)) {
          return textStyle.copyWith(color: _colors.primary);
        }
        return textStyle.copyWith(color: _colors.onSurfaceVariant);
      });

  @override
  TextStyle? get helperStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodySmall ?? const TextStyle();
        if (states.contains(WidgetState.disabled)) {
          return textStyle.copyWith(
              color: _colors.onSurface.withValues(alpha: 0.38));
        }
        return textStyle.copyWith(color: _colors.onSurfaceVariant);
      });

  @override
  TextStyle? get errorStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodySmall ?? const TextStyle();
        return textStyle.copyWith(color: _colors.error);
      });
}
