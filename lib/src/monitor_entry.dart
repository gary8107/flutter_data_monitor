import 'monitor_section.dart';

/// 條目狀態，決定列表 icon 與顏色。
enum MonitorStatus {
  /// 進行中（例如 HTTP 已送出、尚未收到回應）。
  pending,

  /// 成功完成。
  success,

  /// 發生錯誤。
  error;

  bool get isPending => this == MonitorStatus.pending;
  bool get isError => this == MonitorStatus.error;
}

/// 一筆被監控的紀錄。
///
/// 任何資料來源（HTTP、MQTT、自訂事件）最終都轉成這個「通用條目」，
/// 這是三層解耦的核心：UI 只認識 [MonitorEntry]，不認識任何特定來源。
///
/// 欄位刻意設計為可變（title / subtitle / status / tabs），
/// 讓 channel 能像「先記 pending、收到結果再改寫」這樣就地更新同一筆，
/// 對應原始 network_logger 的 request→response 更新模式。
class MonitorEntry {
  MonitorEntry({
    required this.category,
    required this.title,
    this.subtitle,
    this.status = MonitorStatus.success,
    List<MonitorTab>? tabs,
    this.raw,
    DateTime? timestamp,
    String? id,
  })  : tabs = tabs ?? const [],
        timestamp = timestamp ?? DateTime.now(),
        id = id ?? _nextId();

  static int _counter = 0;
  static String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  /// 唯一識別碼。儲存層與詳情頁用它辨識「同一筆」的後續更新。
  final String id;

  /// 分類標籤。列表頁用它做 chip 篩選，例如 'HTTP'、'MQTT'、'EVENT'。
  final String category;

  /// 列表主標題（例如 'GET /users'）。
  String title;

  /// 列表次標題（例如完整 uri、MQTT topic）。可為 null。
  String? subtitle;

  /// 狀態。
  MonitorStatus status;

  /// 詳情頁內容。多個 tab 會顯示 TabBar；單一或空 tab 直接顯示。
  List<MonitorTab> tabs;

  /// 原始物件，需要時可取回（非必要）。
  final Object? raw;

  /// 產生時間。
  final DateTime timestamp;
}

/// 詳情頁的一個分頁，內含數個 [MonitorSection]。
///
/// HTTP 會產生 Request / Response 兩個 tab；多數自訂來源只需一個。
class MonitorTab {
  const MonitorTab({required this.name, required this.sections});

  final String name;
  final List<MonitorSection> sections;
}
