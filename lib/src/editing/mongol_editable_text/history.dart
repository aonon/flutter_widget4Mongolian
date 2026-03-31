part of '../mongol_editable_text.dart';

typedef TextEditingValueCallback = void Function(TextEditingValue value);

/// Provides undo/redo capabilities for text editing.
///
/// Listens to [controller] as a [ValueNotifier] and saves relevant values for
/// undoing/redoing. The cadence at which values are saved is a best
/// approximation of the native behaviors of a hardware keyboard on Flutter's
/// desktop platforms, as there are subtle differences between each of these
/// platforms.
///
/// Listens to keyboard undo/redo shortcuts and calls [onTriggered] when a
/// shortcut is triggered that would affect the state of the [controller].
class _TextEditingHistory extends StatefulWidget {
  /// Creates an instance of [_TextEditingHistory].
  const _TextEditingHistory({
    required this.child,
    required this.controller,
    required this.onTriggered,
  });

  /// The child widget of [_TextEditingHistory].
  final Widget child;

  /// The [TextEditingController] to save the state of over time.
  final TextEditingController controller;

  /// Called when an undo or redo causes a state change.
  ///
  /// If the state would still be the same before and after the undo/redo, this
  /// will not be called. For example, receiving a redo when there is nothing
  /// to redo will not call this method.
  ///
  /// It is also not called when the controller is changed for reasons other
  /// than undo/redo.
  final TextEditingValueCallback onTriggered;

  @override
  State<_TextEditingHistory> createState() => _TextEditingHistoryState();
}

class _TextEditingHistoryState extends State<_TextEditingHistory> {
  final _UndoStack<TextEditingValue> _stack = _UndoStack<TextEditingValue>();
  late final _Throttled<TextEditingValue> _throttledPush;
  Timer? _throttleTimer;

  // This duration was chosen as a best fit for the behavior of Mac, Linux,
  // and Windows undo/redo state save durations, but it is not perfect for any
  // of them.
  static const Duration _kThrottleDuration = Duration(milliseconds: 500);

  void _undo(UndoTextIntent intent) {
    _update(_stack.undo());
  }

  void _redo(RedoTextIntent intent) {
    _update(_stack.redo());
  }

  void _update(TextEditingValue? nextValue) {
    if (nextValue == null) {
      return;
    }
    if (nextValue.text == widget.controller.text) {
      return;
    }
    widget.onTriggered(widget.controller.value.copyWith(
      text: nextValue.text,
      selection: nextValue.selection,
    ));
  }

  void _push() {
    if (widget.controller.value == TextEditingValue.empty) {
      return;
    }

    // Gboard on Android puts non-CJK words in composing regions. Keep Android
    // behavior unchanged and coalesce composing text there; other platforms
    // skip composing text in history coalescing.
    if (defaultTargetPlatform != TargetPlatform.android &&
        !widget.controller.value.composing.isCollapsed) {
      return;
    }

    _throttleTimer = _throttledPush(widget.controller.value);
  }

  @override
  void initState() {
    super.initState();
    _throttledPush = _throttle<TextEditingValue>(
      duration: _kThrottleDuration,
      function: _stack.push,
    );
    _push();
    widget.controller.addListener(_push);
  }

  @override
  void didUpdateWidget(_TextEditingHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _stack.clear();
      oldWidget.controller.removeListener(_push);
      widget.controller.addListener(_push);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_push);
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        UndoTextIntent: Action<UndoTextIntent>.overridable(
            context: context,
            defaultAction: CallbackAction<UndoTextIntent>(onInvoke: _undo)),
        RedoTextIntent: Action<RedoTextIntent>.overridable(
            context: context,
            defaultAction: CallbackAction<RedoTextIntent>(onInvoke: _redo)),
      },
      child: widget.child,
    );
  }
}

/// A data structure representing a chronological list of states that can be
/// undone and redone.
class _UndoStack<T> {
  /// Creates an instance of [_UndoStack].
  _UndoStack();

  final List<T> _list = <T>[];

  // The index of the current value, or null if the list is empty.
  late int _index;

  /// Returns the current value of the stack.
  T? get currentValue => _list.isEmpty ? null : _list[_index];

  /// Add a new state change to the stack.
  ///
  /// Pushing identical objects will not create multiple entries.
  void push(T value) {
    if (_list.isEmpty) {
      _index = 0;
      _list.add(value);
      return;
    }

    assert(_index < _list.length && _index >= 0);

    if (value == currentValue) {
      return;
    }

    // If anything has been undone in this stack, remove those irrelevant states
    // before adding the new one.
    if (_index != _list.length - 1) {
      _list.removeRange(_index + 1, _list.length);
    }
    _list.add(value);
    _index = _list.length - 1;
  }

  /// Returns the current value after an undo operation.
  ///
  /// An undo operation moves the current value to the previously pushed value,
  /// if any.
  ///
  /// Iff the stack is completely empty, then returns null.
  T? undo() {
    if (_list.isEmpty) {
      return null;
    }

    assert(_index < _list.length && _index >= 0);

    if (_index != 0) {
      _index = _index - 1;
    }

    return currentValue;
  }

  /// Returns the current value after a redo operation.
  ///
  /// A redo operation moves the current value to the value that was last
  /// undone, if any.
  ///
  /// Iff the stack is completely empty, then returns null.
  T? redo() {
    if (_list.isEmpty) {
      return null;
    }

    assert(_index < _list.length && _index >= 0);

    if (_index < _list.length - 1) {
      _index = _index + 1;
    }

    return currentValue;
  }

  /// Remove everything from the stack.
  void clear() {
    _list.clear();
    _index = -1;
  }

  @override
  String toString() {
    return '_UndoStack $_list';
  }
}

/// A function that can be throttled with the throttle function.
typedef _Throttleable<T> = void Function(T currentArg);

/// A function that has been throttled by [_throttle].
typedef _Throttled<T> = Timer Function(T currentArg);

/// Returns a _Throttled that will call through to the given function only a
/// maximum of once per duration.
///
/// Only works for functions that take exactly one argument and return void.
_Throttled<T> _throttle<T>({
  required Duration duration,
  required _Throttleable<T> function,
  // If true, calls at the start of the timer.
  bool leadingEdge = false,
}) {
  Timer? timer;
  bool calledDuringTimer = false;
  late T arg;

  return (T currentArg) {
    arg = currentArg;
    if (timer != null) {
      calledDuringTimer = true;
      return timer!;
    }
    if (leadingEdge) {
      function(arg);
    }
    calledDuringTimer = false;
    timer = Timer(duration, () {
      if (!leadingEdge || calledDuringTimer) {
        function(arg);
      }
      timer = null;
    });
    return timer!;
  };
}

/// The start and end glyph widths (when in vertical orientation) of some
/// range of text.
@immutable
class _GlyphWidths {
  const _GlyphWidths({
    required this.start,
    required this.end,
  });

  /// The glyph width of the first line.
  final double start;

  /// The glyph width of the last line.
  final double end;
}
