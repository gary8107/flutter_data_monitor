import 'dart:async';

import 'monitor_entry.dart';

/// 儲存被監控的條目，並在新增／更新時透過 broadcast stream 通知監聽者。
///
/// 對應原始 network_logger 的 `NetworkEventList`，但條目改為通用的
/// [MonitorEntry]，因此可承載任何來源的資料。
class MonitorLog {
  final _controller = StreamController<MonitorUpdate>.broadcast();

  /// 已記錄的條目，最新的在最前面。
  final entries = <MonitorEntry>[];

  /// 條目變動事件流，展示層以 [StreamBuilder] 監聽它即可自動刷新。
  Stream<MonitorUpdate> get stream => _controller.stream;

  /// 目前出現過的所有分類（供列表頁產生篩選 chip）。
  Set<String> get categories => entries.map((e) => e.category).toSet();

  /// 新增一筆並通知。
  void add(MonitorEntry entry) {
    entries.insert(0, entry);
    _controller.add(MonitorUpdate(entry));
  }

  /// 通知某筆已更新（內容通常已就地改寫，例如 pending → success）。
  void update(MonitorEntry entry) {
    _controller.add(MonitorUpdate(entry));
  }

  /// 便捷記錄：一行就記下任何東西，回傳該條目方便後續 [update]。
  ///
  /// 這也是「純文字 log」最省事的用法：
  /// ```dart
  /// Monitor.instance.log(category: 'BLE', title: '收到廣播封包', subtitle: payloadHex);
  /// ```
  MonitorEntry log({
    required String category,
    required String title,
    String? subtitle,
    MonitorStatus status = MonitorStatus.success,
    List<MonitorTab>? tabs,
    Object? raw,
  }) {
    final entry = MonitorEntry(
      category: category,
      title: title,
      subtitle: subtitle,
      status: status,
      tabs: tabs,
      raw: raw,
    );
    add(entry);
    return entry;
  }

  /// 清空全部並通知。
  void clear() {
    entries.clear();
    _controller.add(const MonitorUpdate.clear());
  }

  /// 釋放資源。
  void dispose() {
    _controller.close();
  }
}

/// [MonitorLog.stream] 發出的事件。[entry] 為 null 代表清空。
class MonitorUpdate {
  const MonitorUpdate(this.entry);
  const MonitorUpdate.clear() : entry = null;

  final MonitorEntry? entry;
}

/// 全域單例入口。多數情況直接用 `Monitor.instance` 即可；
/// 需要隔離的獨立記錄流時，可自行 new 一個 [MonitorLog] 傳給 channel / UI。
class Monitor extends MonitorLog {
  Monitor._();
  static final Monitor instance = Monitor._();
}
