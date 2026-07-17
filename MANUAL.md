# data_monitor 使用手冊

可擴充的 App 資料監控器：一顆懸浮鈕叫出「監控紀錄」，把 App 內各種通訊（HTTP、MQTT、Tuya、WebSocket、自訂事件…）即時收進同一個畫面，可分類篩選、搜尋、看詳情。

本手冊分兩部分：
- **第一部分〈操作〉** 給使用／測試的人 —— 怎麼叫出來、怎麼看。
- **第二部分〈整合與擴充〉** 給開發者 —— 怎麼裝、怎麼加新的監控來源。

---

# 第一部分：操作（使用／測試）

## 1. 叫出懸浮鈕

- 依掛載設定，懸浮鈕可能**預設顯示**或**預設隱藏**。
- **預設隱藏時**：在畫面任意處**三指連點三下**即可叫出／收起（手勢與手指數可調，預設三指三下、2 秒內完成）。
- 懸浮鈕可**長按拖曳**移到不擋畫面的位置；**輕點**打開監控紀錄。

> engo App 目前設定為「預設隱藏、三指連點三下叫出」。

## 2. 監控紀錄列表

點懸浮鈕進入列表，由上而下是最新的紀錄。每一列：

```
[狀態icon]  ←/→  標題（例如 device/xxx/dp/read 或 GET /v1/device/list (200)）      [時間]
            [⚙ 裝置名稱 · 品類]   副標題（payload 預覽 / uri…）                      [分類徽章]
```

| 元素 | 意義 |
|------|------|
| **狀態 icon** | 綠勾＝成功、灰沙漏＝進行中、紅叉＝錯誤 |
| **方向箭頭** | `←` 收到（inbound）、`→` 送出（outbound）；無箭頭＝一般事件 |
| **來源徽章 `⚙ …`** | 這筆是哪台機器：`裝置名稱 · 品類`（如 `medole-erv · 全熱交換器`）。查不到品類時只顯示名稱 |
| **分類徽章** | 右下角色塊，標示通道類別（MQTT／TUYA／HTTP／WS／EVENT…），同類別固定同色 |
| **時間** | 該筆發生時間（HH:mm:ss） |

## 3. 篩選與搜尋

- **分類 chip**（列表上方）：點一個或多個 chip，只看該類別；再點取消。空選＝顯示全部。
- **搜尋框**：輸入關鍵字即時過濾，比對範圍為 **標題／副標題／來源（裝置名稱·品類）**。例如輸入「全熱交換器」可篩出該品類所有紀錄。
- 右上角**垃圾桶**：清空目前所有紀錄。

## 4. 詳情頁

點任一列進入詳情：

- 頂部 header：分類徽章、狀態、時間、標題、副標題、來源徽章。
- 內容依來源分成一個或多個 **tab**（例如 HTTP 分 `Request` / `Response`）。
- 每個 tab 內是數個 **section**：
  - **Meta / 參數**：key-value 表格（method、topic、qos、bytes…）。
  - **Payload / Body**：內容區；**JSON 會自動縮排美化**。**長按可複製全文**。
  - **Error**：紅字錯誤訊息。

---

# 第二部分：整合與擴充（開發者）

## 5. 三層架構

```
採集層 (channel)  →  儲存層 (MonitorLog / Monitor.instance)  →  展示層 (UI)
                          ▲
                  通用條目 MonitorEntry 解耦
```

- **採集層**：把來源資料轉成 `MonitorEntry` 丟進 `MonitorLog`。內建 `DioMonitor`（HTTP）、`MqttMonitor`、`AppEventMonitor` + `MonitorNavigatorObserver`。
- **儲存層**：`MonitorLog` 存條目 + broadcast stream；全域單例 `Monitor.instance`。
- **展示層**：懸浮鈕 → 列表（搜尋 + 分類篩選）→ 詳情。**新增來源完全不用改這層。**

## 6. 掛上懸浮鈕（MonitorGate，推薦）

放在 `MaterialApp.builder`，生命週期跟著 widget 樹，`MaterialApp` 重建（切語言／主題）也不會變孤兒或重複。開監控頁走與 App 同一把 `navigatorKey`。

```dart
final navigatorKey = GlobalKey<NavigatorState>();

MaterialApp( // 或 MaterialApp.router
  navigatorKey: navigatorKey,
  builder: (context, child) => MonitorGate(
    navigatorKey: navigatorKey,        // 要與 App 同一把
    initiallyVisible: false,           // 預設隱藏，三指連點三下叫出
    child: child!,
  ),
  home: HomePage(),
);
```

可調參數：`initiallyVisible`（預設 `true` 顯示）、`fingerCount`（預設 3）、`tapCount`（預設 3）、`tapWindow`（預設 2 秒）。

> 另有簡易版 `MonitorOverlay.attachTo(context)`（插進 root overlay，一行搞定），但 `MaterialApp` 重建時 OverlayEntry 會變孤兒，僅適合單純 App／快速試用。

## 7. 內建 channel 接法

各通道都是在**既有服務的單點**加一行，不必動任何 caller。以下為 engo 的接法範例。

### HTTP（DioMonitor）
在 Dio 的 interceptor 鏈加一行即可採集所有 API：
```dart
dio.interceptors.add(DioMonitor());
```

### MQTT（MqttMonitor，不依賴 mqtt_client）
呼叫端餵已解碼的 `topic` / `payload` 字串；payload 是 JSON 會自動美化。收／送各成一筆。
```dart
final mqtt = MqttMonitor();
// 收：所有 inbound 的唯一總線（connect() 內 client.updates?.listen 迴圈）
mqtt.received(topic, payloadString, qos: qos, source: deviceLabel);
// 送：唯一 outbound 點（publish 後）
mqtt.published(topic, message, qos: qos, retain: retain, source: deviceLabel);
// 生命週期（選用）
mqtt.connected(broker, port: port);
mqtt.disconnected();
mqtt.error('連線逾時');
```

### Tuya / WebSocket 等自訂通道
無專屬 channel 類別時，直接用通用 `Monitor.instance.log(...)`（見第 8 節）在該服務的收／送單點記錄即可。engo 的接法：
- **Tuya**：`TuyaService._handleDevDpUpdate`（收）、`publishDps`（送）、`_handleDevStatusChanged`（上下線）。
- **WebSocket**：`WebSocketService._onMessage`（收訊唯一入口）、connect 成功／`_onError`／`_onDone`（生命週期）。

### 來源標籤（裝置名稱 · 品類）
`source` 欄位用來標「這筆是哪台機器」。engo 以共用工具 `MonitorDeviceLabel.resolve(devId)` 解析：從裝置清單反查名稱、再以 `product-type/list/simple` 對出品類名，回傳「名稱 · 品類」。

### App 事件 / 狀態 / 路由
```dart
// 路由：掛 observer 自動記錄 push/pop
MaterialApp(navigatorObservers: [MonitorNavigatorObserver()], ...);

// 事件 / 狀態
final appEvent = AppEventMonitor();
appEvent.event('使用者登入', detail: 'AuthService', data: {'userId': 'u_1024'});
appEvent.stateChanged('counterProvider', from: 0, to: 1);
```
Riverpod 可寫一個 5 行 `ProviderObserver` 轉呼叫 `AppEventMonitor`（package 不依賴 riverpod）。

## 8. 加你自己的監控（由簡到繁）

**A. 一行純文字 log**
```dart
Monitor.instance.log(category: 'BLE', title: '收到廣播', subtitle: payloadHex);
```

**B. 帶結構化詳情 + 來源**
```dart
Monitor.instance.log(
  category: 'MQTT',
  title: 'device/123/report',
  source: 'medole-erv · 全熱交換器',
  tabs: [
    MonitorTab(name: 'Payload', sections: [
      KeyValueSection.fromMap('Meta', {'topic': topic, 'qos': '1'}),
      BodySection('Body', jsonMap),   // Map/List 自動 JSON 美化
    ]),
  ],
);
```

**C. 寫一個 channel**（來源會持續產事件時）
照 `lib/src/channels/dio_monitor.dart` 的模式：接住來源事件 → 轉 `MonitorEntry` → `log.add(entry)`；要更新同一筆就改欄位後 `log.update(entry)`。

**客製顯示**：繼承 `MonitorSection`，實作 `buildContent(context)`，即可在詳情頁畫任意 widget。內建 `KeyValueSection` / `BodySection` / `TextSection`。

## 9. MonitorEntry 欄位參考

| 欄位 | 用途 |
|------|------|
| `category` | 分類，列表 chip 篩選依據、決定徽章顏色 |
| `title` / `subtitle` | 列表兩行文字（皆納入搜尋） |
| `source` | 來源標籤（裝置名稱·品類），列表列與詳情各顯示一個徽章（納入搜尋） |
| `status` | `pending` / `success` / `error`，決定狀態 icon 顏色 |
| `tabs` → `sections` | 詳情頁內容 |
| `raw` | 保留原始物件（選用） |
| `timestamp` | 產生時間（預設 now） |

---

# 附錄：常見問題

**Q：為什麼多數裝置「在線」卻不一直發訊息，只有全熱交換器一直進來？**
IoT 的 DP 上報是**事件驅動**（狀態變才報），非持續串流 —— 靜止裝置安靜是正常的。全熱交換器是韌體設計成每 5 秒送一次狀態心跳的**特例**。此外，App 需**先訂閱／註冊**某裝置才收得到它的 DP：engo 裝置首頁即訂閱，**Tuya 裝置要打開面板才註冊**，故 Tuya 需點進去才開始出現。「在線」只代表連上雲，不代表正在對 App 串流。

**Q：Tuya / WebSocket 通道一直沒資料？**
因為它們只在**裝置狀態真的改變**時才有訊息。操作一台裝置（或打開其面板）即可觸發。

**Q：搜尋搜不到品類名？**
搜尋涵蓋 標題／副標題／來源徽章（裝置名稱·品類），品類名在來源徽章內，可直接搜。
