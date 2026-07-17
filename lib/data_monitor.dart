/// 可擴充的 App 資料監控器。
///
/// 資料流：採集層(channel) → 儲存層([MonitorLog]) → 展示層(UI)。
/// 三層以通用的 [MonitorEntry] 解耦，所以新增監控來源只要產出 [MonitorEntry]，
/// UI 完全不需改動。
library data_monitor;

export 'src/monitor_entry.dart';
export 'src/monitor_section.dart';
export 'src/monitor_log.dart';
export 'src/channels/dio_monitor.dart';
export 'src/ui/monitor_button.dart' show MonitorButton, MonitorOverlay;
export 'src/ui/monitor_screen.dart' show MonitorScreen;
export 'src/ui/monitor_entry_screen.dart' show MonitorEntryScreen;
