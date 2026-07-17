import 'package:flutter/widgets.dart';

import '../monitor_entry.dart';
import '../monitor_log.dart';
import '../monitor_section.dart';

/// App 內部事件 / 狀態採集器。
///
/// 與其他 channel 一樣**不依賴任何狀態管理套件**（Riverpod / GetX）：
/// 呼叫端把事件名稱與資料餵進來即可。Riverpod 的接法只需一個 5 行的
/// `ProviderObserver` 轉呼叫本類別，見 README。
///
/// 路由變化請改用同檔的 [MonitorNavigatorObserver]（純 Flutter，零依賴）。
class AppEventMonitor {
  AppEventMonitor({MonitorLog? log}) : log = log ?? Monitor.instance;

  final MonitorLog log;

  static const String eventCategory = 'EVENT';
  static const String stateCategory = 'STATE';

  /// 記一筆一般 App 事件。[data] 有值時會在詳情頁以 BodySection 顯示（JSON 自動美化）。
  MonitorEntry event(
    String name, {
    String? detail,
    Object? data,
    MonitorStatus status = MonitorStatus.success,
  }) {
    return log.log(
      category: eventCategory,
      title: name,
      subtitle: detail,
      status: status,
      tabs: data == null
          ? null
          : [
              MonitorTab(name: '內容', sections: [BodySection('Data', data)]),
            ],
    );
  }

  /// 記一筆狀態變化（from → to）。適合 Riverpod / GetX 的 state 更新。
  MonitorEntry stateChanged(
    String name, {
    Object? from,
    Object? to,
  }) {
    return log.log(
      category: stateCategory,
      title: name,
      subtitle: '${_short(from)}  →  ${_short(to)}',
      tabs: [
        MonitorTab(name: '變化', sections: [
          KeyValueSection('State', [
            MapEntry('from', '$from'),
            MapEntry('to', '$to'),
          ]),
        ]),
      ],
    );
  }

  /// 列表副標題用的短字串。
  String _short(Object? value) {
    final text = '$value'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 40 ? text : '${text.substring(0, 40)}…';
  }
}

/// 路由變化採集器：掛到 `MaterialApp.navigatorObservers`（或 GoRouter 的 observers）
/// 即可自動記錄 push / pop / replace / remove。
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [MonitorNavigatorObserver()],
///   ...
/// );
/// ```
class MonitorNavigatorObserver extends NavigatorObserver {
  MonitorNavigatorObserver({MonitorLog? log}) : log = log ?? Monitor.instance;

  final MonitorLog log;

  static const String category = 'ROUTE';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('push', route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('pop', route, previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _record('replace', newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('remove', route, previousRoute);
    super.didRemove(route, previousRoute);
  }

  void _record(String action, Route<dynamic>? route, Route<dynamic>? other) {
    final name = _name(route);
    log.log(
      category: category,
      title: '$action  $name',
      subtitle: other == null ? null : 'from ${_name(other)}',
      tabs: [
        MonitorTab(name: 'Route', sections: [
          KeyValueSection.fromMap('Meta', {
            'action': action,
            'route': name,
            'previous': _name(other),
            'arguments': route?.settings.arguments,
          }),
        ]),
      ],
    );
  }

  String _name(Route<dynamic>? route) {
    if (route == null) return '(none)';
    return route.settings.name ?? route.runtimeType.toString();
  }
}
