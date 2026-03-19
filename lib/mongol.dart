/// Mongol 库 - 提供蒙古文垂直排版支持的 Flutter 组件库
library;

// 基础组件
/// 蒙古文文本对齐方式枚举
/// 支持：顶对齐、底对齐、居中对齐、两端对齐
export 'package:mongol/src/base/mongol_text_align.dart';

/// 蒙古文文本绘制器
/// 用于自定义绘制、布局和测量垂直蒙古文文本
export 'package:mongol/src/base/mongol_text_painter.dart';

// 按钮组件
/// 支持垂直排版的 ElevatedButton 变体，适用于强调操作
export 'package:mongol/src/button/mongol_elevated_button.dart';

/// 支持垂直排版的 FilledButton 变体，适用于突出显示操作
export 'package:mongol/src/button/mongol_filled_button.dart';

/// 支持垂直排版的 IconButton 变体，适用于图标操作场景
export 'package:mongol/src/button/mongol_icon_button.dart';

/// 支持垂直排版的 OutlinedButton 变体，适用于次要操作
export 'package:mongol/src/button/mongol_outlined_button.dart';

/// 支持垂直排版的 TextButton 变体，适用于常规操作
export 'package:mongol/src/button/mongol_text_button.dart';

// 对话框组件
/// 支持垂直排版的 AlertDialog 变体，用于显示重要信息或确认场景
export 'package:mongol/src/dialog/mongol_alert_dialog.dart';

// 编辑组件
/// 蒙古文对齐相关工具和辅助方法
export 'package:mongol/src/editing/alignment.dart';

/// 蒙古文输入框边框样式
/// 提供 SidelineInputBorder 和 MongolOutlineInputBorder
export 'package:mongol/src/editing/input_border.dart'
    show SidelineInputBorder, MongolOutlineInputBorder;

/// 可编辑蒙古文文本渲染类，支持垂直排版和文本选择
export 'package:mongol/src/editing/mongol_render_editable.dart';

/// 蒙古文文本编辑快捷键，支持垂直排版的文本操作
export 'package:mongol/src/editing/mongol_text_editing_shortcuts.dart';

/// 支持垂直排版的 TextField 变体，用于蒙古文输入场景
export 'package:mongol/src/editing/mongol_text_field.dart';

// 列表组件
/// 支持垂直排版的 ListTile 变体，用于显示列表项
export 'package:mongol/src/list/mongol_list_tile.dart';

/// 支持垂直排版的 CheckboxListTile 变体，用于带复选框的列表项
export 'package:mongol/src/list/mongol_checkbox_list_tile.dart';

/// 支持垂直排版的 RadioListTile 变体，用于带单选按钮的列表项
export 'package:mongol/src/list/mongol_radio_list_tile.dart';

/// 支持垂直排版的 SwitchListTile 变体，用于带开关的列表项
export 'package:mongol/src/list/mongol_switch_list_tile.dart';

// 菜单组件
/// 支持垂直排版的 PopupMenu 变体，用于显示弹出菜单
export 'package:mongol/src/menu/mongol_popup_menu.dart';

/// 支持垂直排版的 Tooltip 变体，用于显示提示信息
export 'package:mongol/src/menu/mongol_tooltip.dart';

// 文本组件
/// 支持垂直排版的 RichText 变体，用于显示富文本内容
export 'package:mongol/src/text/mongol_rich_text.dart';

/// 支持垂直排版的 Text 变体，用于显示简单文本
export 'package:mongol/src/text/mongol_text.dart';

/// 支持垂直排版的 SelectableText 变体，用于显示可选择和可复制的文本
export 'package:mongol/src/selectable_text/mongol_selectable_text.dart';

/// 支持垂直排版的 SelectableRichText 变体，用于显示可选择、可复制的富文本
export 'package:mongol/src/selectable_text/mongol_selectable_rich_text.dart';

/// 支持垂直排版的 EditableText 变体，提供底层文本编辑功能
export 'package:mongol/src/editing/mongol_editable_text.dart';
