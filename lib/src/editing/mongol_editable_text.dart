// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui hide TextStyle;

import 'package:characters/characters.dart'
    show CharacterRange, StringCharacters;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart'
    show
        ContentInsertionConfiguration,
        kDefaultContentInsertionMimeTypes,
        DeleteToNextWordBoundaryIntent,
        ExpandSelectionToDocumentBoundaryIntent,
        ExtendSelectionVerticallyToAdjacentLineIntent,
        ReplaceTextIntent,
        ScrollToDocumentBoundaryIntent,
        Size,
        kMinInteractiveDimension;
import 'package:flutter/rendering.dart' show RevealedOffset, ViewportOffset;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show
        Action,
        Actions,
        AnimationController,
        AppPrivateCommandCallback,
        AutofillGroup,
        AutofillGroupState,
        AutomaticKeepAliveClientMixin,
        AxisDirection,
        BuildContext,
        CallbackAction,
        CharacterRange,
        Clip,
        ClipboardStatus,
        ClipboardStatusNotifier,
        Color,
        CompositedTransformTarget,
        ContextAction,
        ContextMenuButtonItem,
        ContextMenuButtonType,
        CopySelectionTextIntent,
        Curve,
        Curves,
        DeleteCharacterIntent,
        DeleteToLineBreakIntent,
        DirectionalCaretMovementIntent,
        DirectionalFocusAction,
        DirectionalFocusIntent,
        DirectionalTextEditingIntent,
        DismissIntent,
        DoNothingAction,
        DoNothingAndStopPropagationTextIntent,
        EdgeInsets,
        ExpandSelectionToLineBreakIntent,
        ExtendSelectionByCharacterIntent,
        ExtendSelectionByPageIntent,
        ExtendSelectionToDocumentBoundaryIntent,
        ExtendSelectionToLineBreakIntent,
        ExtendSelectionToNextWordBoundaryIntent,
        ExtendSelectionToNextWordBoundaryOrCaretLocationIntent,
        Focus,
        FocusNode,
        FocusScope,
        GlobalKey,
        Intent,
        intentForMacOSSelector,
        LayerLink,
        LeafRenderObjectWidget,
        MediaQuery,
        MouseRegion,
        Offset,
        Orientation,
        PasteTextIntent,
        PointerDownEvent,
        primaryFocus,
        Radius,
        Rect,
        RedoTextIntent,
        ScrollBehavior,
        ScrollConfiguration,
        ScrollController,
        ScrollPhysics,
        Scrollable,
        ScrollableState,
        ScrollIntent,
        ScrollIncrementType,
        ScrollPosition,
        ScrollAction,
        SelectAllTextIntent,
        SelectionChangedCallback,
        Semantics,
        Simulation,
        State,
        StatefulWidget,
        TapRegionCallback,
        TextAlign,
        TextDirection,
        TextEditingController,
        TextFieldTapRegion,
        TextMagnifierConfiguration,
        TextSelectionControls,
        TextSelectionHandleType,
        TextSelectionHandleControls,
        TextSelectionToolbarAnchors,
        TextSelectionPoint,
        TextSpan,
        TextStyle,
        TickerMode,
        TickerProviderStateMixin,
        TransposeCharactersIntent,
        UndoTextIntent,
        UpdateSelectionIntent,
        View,
        Widget,
        WidgetsBinding,
        WidgetsBindingObserver,
        debugCheckHasMediaQuery;

import 'package:mongol/src/base/mongol_text_align.dart';
import 'package:mongol/src/editing/mongol_render_editable.dart';
import 'package:mongol/src/editing/text_selection/mongol_text_selection.dart';
import 'package:mongol/src/editing/mongol_toolbar_options.dart';

import 'text_editing_controller_extension.dart';
import 'mongol_text_editing_intents.dart';
import 'mongol_mouse_cursors.dart';
import 'platform_utils.dart';
import 'web_text_cursor_helper.dart';

export 'package:flutter/services.dart'
    show
        SelectionChangedCause,
        TextEditingValue,
        TextSelection,
        TextInputType,
        SmartQuotesType,
        SmartDashesType;

part 'mongol_editable_text/types_and_simulation.dart';
part 'mongol_editable_text/widget.dart';
part 'mongol_editable_text/state.dart';
part 'mongol_editable_text/render_widget.dart';
part 'mongol_editable_text/text_boundaries.dart';
part 'mongol_editable_text/actions.dart';
part 'mongol_editable_text/history.dart';
