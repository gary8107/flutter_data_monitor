import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _jsonEncoder = JsonEncoder.withIndent('  ');

/// 詳情頁的一個內容區塊（灰色小標題 + 內容）。
///
/// 這是「客製顯示」的擴充點：想要不同的呈現方式，
/// 繼承此類別並實作 [buildContent] 即可，UI 會自動套用。
abstract class MonitorSection {
  const MonitorSection(this.title);

  /// 區塊標題（會以大寫灰色小字呈現）。
  final String title;

  /// 由子類別實作的實際內容。
  Widget buildContent(BuildContext context);

  /// 外框（標題 + 內容），由詳情頁呼叫。子類別通常不需覆寫。
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 6),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        buildContent(context),
      ],
    );
  }
}

/// key-value 表格，適合 headers、參數清單。
class KeyValueSection extends MonitorSection {
  KeyValueSection(super.title, this.entries);

  KeyValueSection.fromMap(String title, Map<String, Object?> map)
      : entries =
            map.entries.map((e) => MapEntry(e.key, '${e.value}')).toList(),
        super(title);

  final List<MapEntry<String, String>> entries;

  @override
  Widget buildContent(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 15),
        child: Text('—'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) => SelectableText(e.key)).toList(),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) => SelectableText(e.value)).toList(),
          ),
        ],
      ),
    );
  }
}

/// body 區塊：Map / List 會自動 JSON 美化縮排，長按可複製全文。
class BodySection extends MonitorSection {
  BodySection(super.title, this.body);

  final Object? body;

  String get _text {
    final value = body;
    if (value == null) return '';
    if (value is String) return value;
    if (value is List || value is Map) {
      try {
        return _jsonEncoder.convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  @override
  Widget buildContent(BuildContext context) {
    final text = _text;
    if (text.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 15),
        child: Text('—'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: GestureDetector(
        // 長按複製，方便把 payload 貼到別處分析。
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已複製到剪貼簿'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: ['sans-serif'],
          ),
        ),
      ),
    );
  }
}

/// 單純一段文字，可指定顏色（例如錯誤紅字）。
class TextSection extends MonitorSection {
  TextSection(super.title, this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SelectableText(text, style: TextStyle(color: color)),
    );
  }
}
