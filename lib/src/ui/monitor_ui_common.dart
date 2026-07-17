import 'package:flutter/material.dart';

import '../monitor_entry.dart';

/// 分類色盤：同一個分類字串固定對到同一個顏色，讓列表一眼可分辨來源。
const List<Color> _palette = [
  Colors.blue,
  Colors.deepPurple,
  Colors.teal,
  Colors.orange,
  Colors.pink,
  Colors.indigo,
  Colors.green,
  Colors.brown,
];

Color categoryColor(String category) =>
    _palette[category.hashCode.abs() % _palette.length];

/// HH:mm:ss 時間字串，比「幾秒前」更適合追事件先後順序。
String formatClock(DateTime time) =>
    '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';

String _two(int value) => value.toString().padLeft(2, '0');

/// 分類小標籤。
Widget categoryBadge(String category) {
  final color = categoryColor(category);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      category,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

/// 依狀態回傳列表 leading icon。
Widget statusIcon(MonitorStatus status) {
  switch (status) {
    case MonitorStatus.pending:
      return const Icon(Icons.hourglass_empty, color: Colors.grey);
    case MonitorStatus.success:
      return const Icon(Icons.check_circle_outline, color: Colors.green);
    case MonitorStatus.error:
      return const Icon(Icons.error_outline, color: Colors.red);
  }
}

/// 狀態文字（詳情頁 header 用）。
Widget statusText(MonitorStatus status) {
  late final String label;
  late final Color color;
  switch (status) {
    case MonitorStatus.pending:
      label = '進行中';
      color = Colors.grey;
      break;
    case MonitorStatus.success:
      label = '成功';
      color = Colors.green;
      break;
    case MonitorStatus.error:
      label = '錯誤';
      color = Colors.red;
      break;
  }
  return Text(label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600));
}
