# data_monitor

可擴充的 App 資料監控器。仿 [`network_logger`](https://pub.dev/packages/network_logger) 的懸浮視窗體驗，但把「HTTP 專用模型」抽換成**通用條目**，因此可監控任何來源的資料。

> 完整的操作與整合說明見 **[使用手冊 MANUAL.md](MANUAL.md)**（含畫面操作、四通道接法、擴充、FAQ）。本 README 為快速上手。

## 三層架構

```
採集層 (channel)  →  儲存層 (MonitorLog)  →  展示層 (UI)
                        ▲
                通用條目 MonitorEntry 解耦
```

- **採集層**：把來源資料轉成 `MonitorEntry`，丟進 `MonitorLog`。內建 `DioMonitor`（HTTP）。
- **儲存層**：`MonitorLog` 存條目 + broadcast stream；全域單例 `Monitor.instance`。
- **展示層**：懸浮鈕 → 列表（搜尋 + 分類篩選）→ 詳情（多 tab / section）。**新增來源時完全不用改這層。** 搜尋比對 標題／副標題／來源徽章（裝置名稱·品類）。

## 快速開始

```dart
// 1) HTTP：掛上 interceptor
final dio = Dio()..interceptors.add(DioMonitor());

// 2) 掛上懸浮按鈕
```

懸浮按鈕有兩種掛法：

**（推薦）`MonitorGate`** —— 放在 `MaterialApp.builder`，生命週期跟著 widget 樹，`MaterialApp` 重建（切語言 / 主題）也不會變孤兒或重複。預設**三指連點三下**切換顯示 / 隱藏；開監控頁走與 App 同一把 `navigatorKey`，疊在所有頁面之上。

```dart
final navigatorKey = GlobalKey<NavigatorState>();

MaterialApp( // 或 MaterialApp.router
  navigatorKey: navigatorKey,
  builder: (context, child) => MonitorGate(
    navigatorKey: navigatorKey, // 要與 App 同一把
    child: child!,
  ),
  home: HomePage(),
);
```

可調參數：`initiallyVisible`（預設顯示）、`fingerCount`（預設 3）、`tapCount`（預設 3）、`tapWindow`（預設 2 秒）。

**（簡易）`MonitorOverlay.attachTo(context)`** —— 直接插進 root overlay，一行搞定；但 `MaterialApp` 重建時的 OverlayEntry 會變孤兒，適合單純 App 或快速試用。

## 內建 channel：MQTT

`MqttMonitor` **不依賴任何 MQTT 套件**，呼叫端餵已解碼的 `topic` / `payload` 字串即可（payload 是 JSON 會自動美化）。收 / 送各成一筆，用箭頭區分方向（← 收、→ 送）。

engo 的 `MqttService` 只需在**三個單點**各加一行，不必動任何 caller：

```dart
final mqtt = MqttMonitor();

// 1) 收：connect() 內 client.updates?.listen(...) 的迴圈中
final payload = MqttPublishPayload.bytesToStringAsString(
    (message.payload as MqttPublishMessage).payload.message);
mqtt.received(message.topic, payload, source: deviceLabel); // source 選用：標裝置名稱·品類

// 2) 送：publish() 內 client.publishMessage(...) 之後
mqtt.published(topic, message, qos: qos, retain: retain, source: deviceLabel);

// 3) 生命週期（選用）：onConnected / _onDisconnected / _setError
mqtt.connected(state.broker, port: state.port);
mqtt.disconnected();
mqtt.error('MQTT 連接逾時');
```

> `connect()` 內 `client.updates?.listen` 是**所有** inbound 訊息的唯一總線，`publish()` 是唯一 outbound 點——兩處各一行就把收送全包了。

## 內建 channel：App 事件 / 狀態 / 路由

同樣**不依賴任何狀態管理套件**。

**路由**：把 observer 掛到 `MaterialApp`（或 GoRouter）即可自動記錄 push/pop：

```dart
MaterialApp(
  navigatorObservers: [MonitorNavigatorObserver()],
  ...
);
```

**事件 / 狀態**：用 `AppEventMonitor` 具名 API：

```dart
final appEvent = AppEventMonitor();
appEvent.event('使用者登入', detail: 'AuthService', data: {'userId': 'u_1024'});
appEvent.stateChanged('counterProvider', from: 0, to: 1);
```

**Riverpod**：不需讓 package 依賴 riverpod，寫一個 5 行的 `ProviderObserver` 轉呼叫即可：

```dart
class MonitorProviderObserver extends ProviderObserver {
  final _monitor = AppEventMonitor();
  @override
  void didUpdateProvider(provider, previousValue, newValue, container) {
    _monitor.stateChanged(provider.name ?? provider.runtimeType.toString(),
        from: previousValue, to: newValue);
  }
}
// ProviderScope(observers: [MonitorProviderObserver()], child: ...)
```

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
| `category` | 分類，列表頁 chip 篩選依據、決定徽章顏色 |
| `title` / `subtitle` | 列表兩行文字（納入搜尋） |
| `source` | 來源標籤（裝置名稱·品類），列表列與詳情各顯示徽章（納入搜尋） |
| `status` | `pending` / `success` / `error`，決定 icon 顏色 |
| `tabs` → `sections` | 詳情頁內容 |
| `raw` | 保留原始物件（選用） |
