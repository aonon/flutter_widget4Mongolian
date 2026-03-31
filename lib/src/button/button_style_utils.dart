import 'package:flutter/material.dart'
    show WidgetStateProperty, WidgetStatePropertyAll;

/// Wraps a non-null value into [WidgetStatePropertyAll], otherwise returns null.
WidgetStateProperty<T>? widgetStateAllOrNull<T>(T? value) {
  return value == null ? null : WidgetStatePropertyAll<T>(value);
}
