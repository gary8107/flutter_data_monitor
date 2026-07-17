# Changelog

## 0.1.0

- 核心三層架構：`MonitorEntry` / `MonitorLog` / `Monitor.instance`。
- 內建 `DioMonitor`（HTTP 採集，Request / Response 分頁）。
- 內建 `MqttMonitor`（MQTT 收/送/生命週期，payload JSON 自動美化，不依賴 mqtt_client）。
- 內建 `AppEventMonitor` 與 `MonitorNavigatorObserver`（App 事件 / 狀態 / 路由採集）。
- 通用 `Monitor.instance.log(...)`（純文字與結構化事件）。
- UI：可拖曳懸浮鈕、列表（搜尋 + 分類 chip 篩選）、詳情（多 tab / section）。
- `MonitorGate`：掛在 `MaterialApp.builder` 的穩定式懸浮鈕，預設三指連點三下切換顯示 / 隱藏。
- 可擴充點：`MonitorSection` 子類化客製顯示。
