# data_monitor

可擴充的 App 資料監控器。仿 [`network_logger`](https://pub.dev/packages/network_logger) 的懸浮視窗體驗，但把「HTTP 專用模型」抽換成**通用條目**，因此可監控任何來源的資料。

## 三層架構

```
採集層 (channel)  →  儲存層 (MonitorLog)  →  展示層 (UI)
                        ▲
                通用條目 MonitorEntry 解耦
```

- **採集層**：把來源資料轉成 `MonitorEntry`，丟進 `MonitorLog`。內建 `DioMonitor`（HTTP）。
- **儲存層**：`MonitorLog` 存條目 + broadcast stream；全域單例 `Monitor.instance`。
- **展示層**：懸浮鈕 → 列表（搜尋 + 分類篩選）→ 詳情（多 tab / section）。**新增來源時完全不用改這層。**

## 快速開始

```dart
// 1) HTTP：掛上 interceptor
final dio = Dio()..interceptors.add(DioMonitor());

// 2) 掛上懸浮按鈕（在 MaterialApp 之下的頁面）
MonitorOverlay.attachTo(context);
```

## 內建 channel：MQTT

`MqttMonitor` **不依賴任何 MQTT 套件**，呼叫端餵已解碼的 `topic` / `payload` 字串即可（payload 是 JSON 會自動美化）。收 / 送各成一筆，用箭頭區分方向（← 收、→ 送）。

engo 的 `MqttService` 只需在**三個單點**各加一行，不必動任何 caller：

```dart
final mqtt = MqttMonitor();

// 1) 收：connect() 內 client.updates?.listen(...) 的迴圈中
final payload = MqttPublishPayload.bytesToStringAsString(
    (message.payload as MqttPublishMessage).payload.message);
mqtt.received(message.topic, payload);

// 2) 送：publish() 內 client.publishMessage(...) 之後
mqtt.published(topic, message, qos: qos, retain: retain);

// 3) 生命週期（選用）：onConnected / _onDisconnected / _setError
mqtt.connected(state.broker, port: state.port);
mqtt.disconnected();
mqtt.error('MQTT 連接逾時');
```

> `connect()` 內 `client.updates?.listen` 是**所有** inbound 訊息的唯一總線，`publish()` 是唯一 outbound 點——兩處各一行就把收送全包了。

## 新增你自己的監控（三種由簡到繁）

### A. 一行純文字 log（最省事，免寫 channel）

```dart
Monitor.instance.log(category: 'BLE', title: '收到廣播', subtitle: payloadHex);
```

### B. 帶結構化詳情

```dart
Monitor.instance.log(
  category: 'MQTT',
  title: 'device/123/report',
  tabs: [
    MonitorTab(name: 'Payload', sections: [
      KeyValueSection.fromMap('Meta', {'topic': topic, 'qos': '1'}),
      BodySection('Body', jsonMap),           // Map/List 自動 JSON 美化
    ]),
  ],
);
```

### C. 寫一個 channel（來源會持續產事件時）

照 `lib/src/channels/dio_monitor.dart` 的模式：接住來源事件 → 轉 `MonitorEntry` → `log.add(entry)`；需要更新同一筆就改欄位後 `log.update(entry)`。

### 客製顯示

繼承 `MonitorSection`，實作 `buildContent(context)`，即可在詳情頁畫任意 widget。內建 `KeyValueSection` / `BodySection` / `TextSection`。

## 內建欄位對照（可自行擴充）

| 欄位 | 用途 |
|------|------|
| `category` | 分類，列表頁 chip 篩選依據 |
| `title` / `subtitle` | 列表兩行文字 |
| `status` | `pending` / `success` / `error`，決定 icon 顏色 |
| `tabs` → `sections` | 詳情頁內容 |
| `raw` | 保留原始物件（選用） |
