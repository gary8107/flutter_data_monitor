import 'dart:convert';

import 'package:flutter/painting.dart' show Color;

import '../monitor_entry.dart';
import '../monitor_log.dart';
import '../monitor_section.dart';

/// MQTT 訊息採集器。
///
/// 刻意**不依賴任何 MQTT 套件**：呼叫端把已解碼的 `topic` / `payload` 字串餵進來即可，
/// 因此本 package 不會被 mqtt_client 綁定，可搭配任何 MQTT 實作。
///
/// 與 [DioMonitor] 不同，MQTT 沒有「請求→回應」的配對關係，訊息是單向的串流，
/// 所以每一筆收 / 送各自成為一筆獨立條目，用箭頭區分方向（← 收、→ 送）。
///
/// engo 端接法（在 MqttService 三個單點各加一行，不必動 caller）：
/// ```dart
/// final mqttMonitor = MqttMonitor();
///
/// // 1) 收：connect() 內 client.updates?.listen(...) 迴圈中
/// final payload = MqttPublishPayload.bytesToStringAsString(
///   (message.payload as MqttPublishMessage).payload.message);
/// mqttMonitor.received(message.topic, payload);
///
/// // 2) 送：publish() 內 client.publishMessage(...) 之後
/// mqttMonitor.published(topic, message, qos: qos, retain: retain);
///
/// // 3) 生命週期：onConnected / _onDisconnected / _setError
/// mqttMonitor.connected(state.broker, port: state.port);
/// ```
class MqttMonitor {
  MqttMonitor({MonitorLog? log}) : log = log ?? Monitor.instance;

  final MonitorLog log;

  static const String category = 'MQTT';

  /// 收到訂閱訊息（裝置上報）。[source] 可帶裝置名稱等來源標記。
  MonitorEntry received(String topic, String payload,
      {Object? qos, String? source}) {
    return _message(
      arrow: '←',
      label: '收到',
      topic: topic,
      payload: payload,
      qos: qos,
      source: source,
    );
  }

  /// 發布訊息（下發控制）。[source] 可帶裝置名稱等來源標記。
  MonitorEntry published(
    String topic,
    String payload, {
    Object? qos,
    bool? retain,
    String? source,
  }) {
    return _message(
      arrow: '→',
      label: '發布',
      topic: topic,
      payload: payload,
      qos: qos,
      retain: retain,
      source: source,
    );
  }

  /// 連線成功。
  MonitorEntry connected(String broker, {Object? port}) {
    return log.log(
      category: category,
      title: '● 已連線  $broker${port == null ? '' : ':$port'}',
    );
  }

  /// 已斷線。
  MonitorEntry disconnected({String? reason}) {
    return log.log(
      category: category,
      title: '○ 已斷線',
      subtitle: reason,
    );
  }

  /// 訂閱 / 取消訂閱等一般生命週期事件。
  MonitorEntry lifecycle(String event, {String? detail}) {
    return log.log(category: category, title: event, subtitle: detail);
  }

  /// 錯誤（連線 / 訂閱 / 發布失敗）。
  MonitorEntry error(String message, {String? topic}) {
    return log.log(
      category: category,
      title: topic == null ? '錯誤' : '錯誤  $topic',
      status: MonitorStatus.error,
      tabs: [
        MonitorTab(name: '錯誤', sections: [
          TextSection('Message', message, color: const Color(0xFFD32F2F)),
        ]),
      ],
    );
  }

  MonitorEntry _message({
    required String arrow,
    required String label,
    required String topic,
    required String payload,
    Object? qos,
    bool? retain,
    String? source,
  }) {
    final meta = <String, Object?>{
      '方向': label,
      'topic': topic,
      if (qos != null) 'qos': qos,
      if (retain != null) 'retain': retain,
      'bytes': payload.length,
    };
    final entry = MonitorEntry(
      category: category,
      title: '$arrow  $topic',
      subtitle: _preview(payload),
      source: source,
      tabs: [
        MonitorTab(name: label, sections: [
          KeyValueSection.fromMap('Meta', meta),
          // 若 payload 是 JSON 字串，解析後交給 BodySection 做縮排美化；
          // 否則原字串照原樣顯示。
          BodySection('Payload', _decode(payload)),
        ]),
      ],
      raw: payload,
    );
    log.add(entry);
    return entry;
  }

  /// payload 是 JSON 就解析成物件（讓 BodySection 美化），否則回傳原字串。
  Object _decode(String payload) {
    final trimmed = payload.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(trimmed) as Object;
      } catch (_) {
        // 不是合法 JSON，落回原字串。
      }
    }
    return payload;
  }

  /// 列表副標題用的單行預覽。
  String _preview(String payload) {
    final flat = payload.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 60 ? flat : '${flat.substring(0, 60)}…';
  }
}
