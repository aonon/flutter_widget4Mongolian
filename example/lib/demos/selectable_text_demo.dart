// 蒙古文可选择文本组件使用示例

import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart';

class MongolSelectableTextExample extends StatelessWidget {
  const MongolSelectableTextExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SelectableTextDemoPage();
  }
}

class SelectableTextDemoPage extends StatefulWidget {
  const SelectableTextDemoPage({super.key});

  @override
  State<SelectableTextDemoPage> createState() => _SelectableTextDemoPageState();
}

class _SelectableTextDemoPageState extends State<SelectableTextDemoPage> {
  String _selectedText = '';
  late GlobalKey<ScaffoldMessengerState> _scaffoldKey;

  @override
  void initState() {
    super.initState();
    _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('蒙古文可选择文本示例'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 简单示例
                      const MongolSelectableText('基础示例：',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SizedBox(
                          height: 200,
                          child: MongolSelectableText(
                            'ᠰᠠᠢᠨ ᠪᠠᠢᠨᠠ᠎ᠠ ᠤᠤ 你好，世界！这是一个可选择的蒙古文文本。长按选择文本，然后点击复制。',
                            style: const TextStyle(fontSize: 18),
                            onSelectionChanged: (selection, cause) {
                              setState(() {
                                _selectedText = '选中的文本：${selection.toString()}';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 富文本示例
                      const MongolSelectableText('富文本示例：',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MongolSelectableRichText.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: '蒙古文',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const TextSpan(text: '是一种美丽的语言'),
                              TextSpan(
                                text: '，支持垂直书写',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          onSelectionChanged: (selection, cause) {
                            setState(() {
                              _selectedText = '富文本选中：${selection.toString()}';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 自定义颜色示例
                      const MongolSelectableText('自定义选区颜色：',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MongolSelectableText(
                          '长按此文本，选区将以绿色高亮显示。',
                          style: const TextStyle(fontSize: 18),
                          selectionColor: Colors.green.withOpacity(0.4),
                          onSelectionChanged: (selection, cause) {
                            setState(() {
                              _selectedText = '选中内容已改变';
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 显示选中文本信息
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MongolSelectableText.rich(
                          _selectedText.isEmpty
                              ? const TextSpan(
                                  text: "ᠰᠣᠩᠭᠤᠭᠳᠠᠭᠰᠠᠨ ᠠᠭᠤᠯᠭ᠎ᠠ ᠪᠠᠢᠨ᠎ᠠ ᠤᠤ")
                              : TextSpan(text: _selectedText),
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedText.isEmpty
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 显示选中文本信息
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MongolSelectableRichText.rich(TextSpan(
                          style: TextStyle(fontSize: 30, color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'ᠨᠢᠭᠡ\n', style: TextStyle(fontSize: 40)),
                            TextSpan(
                                text: 'ᠬᠣᠶᠠᠷ',
                                style:
                                    TextStyle(backgroundColor: Colors.yellow)),
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
                            TextSpan(
                                text: 'ᠪᠡ ᠲᠠᠪᠤ ᠵᠢᠷᠭᠤ',
                                style: TextStyle(color: Colors.blue)),
                            TextSpan(text: 'ᠭ᠎ᠠ ᠨᠠᠢᠮᠠ '),
                            TextSpan(
                                text: 'ᠶᠢᠰᠦ ', style: TextStyle(fontSize: 20)),
                            TextSpan(
                                text: 'ᠠᠷᠪᠠ',
                                style: TextStyle(
                                    fontFamily: 'MenksoftAmuguleng',
                                    color: Colors.purple)),
                          ],
                        )),
                      ),
                      const SizedBox(height: 30),
                      // 功能说明
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '使用说明：',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('1. 长按文本获取选择框'),
                            Text('2. 拖动扩展选择范围'),
                            Text('3. 在选择上下文菜单中点击"复制"'),
                            Text('4. 单击清除选择'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
