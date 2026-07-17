# Changelog

## 0.1.0

- 核心三層架構：`MonitorEntry` / `MonitorLog` / `Monitor.instance`。
- 內建 `DioMonitor`（HTTP 採集，Request / Response 分頁）。
- 通用 `Monitor.instance.log(...)`（純文字與結構化事件）。
- UI：可拖曳懸浮鈕、列表（搜尋 + 分類 chip 篩選）、詳情（多 tab / section）。
- 可擴充點：`MonitorSection` 子類化客製顯示。
