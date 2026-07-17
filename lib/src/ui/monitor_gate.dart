import 'package:flutter/material.dart';

import '../monitor_log.dart';
import 'monitor_screen.dart';

/// 把監控懸浮鈕以「穩定的 widget 樹方式」掛在整個 App 之上，並用手勢切換顯示。
///
/// 相較於 [MonitorOverlay.attachTo]（OverlayEntry，`MaterialApp` 重建時可能變孤兒、
/// 或重複掛出多顆），[MonitorGate] 放在 `MaterialApp.builder`，生命週期跟著 widget 樹，
/// 較穩、可控。
///
/// 開啟監控頁走「與 App 同一把 [navigatorKey]」，因此監控頁會疊在所有頁面之上；
/// 監控頁開著時懸浮鈕自動隱藏，避免蓋住內容。
///
/// 預設手勢：**三指連點三下**切換懸浮鈕顯示 / 隱藏。手指數與連點次數可調。
///
/// 用法（engo，`MaterialApp.router` + GoRouter）：
/// ```dart
/// MaterialApp.router(
///   routerConfig: goRouter,
///   builder: (context, child) => MonitorGate(
///     navigatorKey: RouterService.rootNavigatorKey, // 與 GoRouter 同一把
///     child: child!,
///   ),
/// );
/// ```
class MonitorGate extends StatefulWidget {
  const MonitorGate({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.log,
    this.initiallyVisible = true,
    this.fingerCount = 3,
    this.tapCount = 3,
    this.tapWindow = const Duration(milliseconds: 2000),
  });

  /// 被包住的 App 內容（通常是 `MaterialApp.builder` 的 child）。
  final Widget child;

  /// 開啟監控頁用的 Navigator。要與 App 同一把，監控頁才能疊在所有頁面之上。
  final GlobalKey<NavigatorState> navigatorKey;

  final MonitorLog? log;

  /// 初始是否顯示懸浮鈕。設 false 則預設隱藏、靠手勢喚出。
  final bool initiallyVisible;

  /// 觸發手勢的同時手指數（預設 3）。
  final int fingerCount;

  /// 觸發手勢的連點次數（預設 3）。
  final int tapCount;

  /// 連點需在此時間窗內完成（預設 2 秒）。
  final Duration tapWindow;

  @override
  State<MonitorGate> createState() => _MonitorGateState();
}

class _MonitorGateState extends State<MonitorGate> {
  late bool _visible = widget.initiallyVisible;
  bool _monitorOpen = false;

  // 懸浮鈕位置（可拖曳）。
  double _right = 30;
  double _bottom = 30;
  static const Size _buttonSize = Size(57, 57);

  // 手勢偵測狀態。
  final Set<int> _activePointers = {};
  bool _reachedTarget = false;
  DateTime? _gestureStart;
  final List<DateTime> _tapTimes = [];

  // 單次「多指點按」允許的最長持續時間（超過視為拖曳/滑動，不計入）。
  static const Duration _maxTapDuration = Duration(milliseconds: 1000);

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointers.isEmpty) _gestureStart = DateTime.now();
    _activePointers.add(event.pointer);
    if (_activePointers.length >= widget.fingerCount) _reachedTarget = true;
  }

  void _onPointerFinished(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isNotEmpty) return; // 還有手指沒放開，先不結算

    final start = _gestureStart;
    final isQuick =
        start != null && DateTime.now().difference(start) < _maxTapDuration;
    if (_reachedTarget && isQuick) _registerTap();

    _reachedTarget = false;
    _gestureStart = null;
  }

  void _registerTap() {
    final now = DateTime.now();
    _tapTimes.add(now);
    // 只保留時間窗內的點按。
    _tapTimes.removeWhere((t) => now.difference(t) > widget.tapWindow);
    if (_tapTimes.length >= widget.tapCount) {
      _tapTimes.clear();
      setState(() => _visible = !_visible);
    }
  }

  Future<void> _openMonitor() async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    // 監控頁開著時先收起懸浮鈕（它在 child 之上，否則會蓋住監控頁）。
    setState(() => _monitorOpen = true);
    try {
      await navigator.push(MaterialPageRoute(
        builder: (_) => MonitorScreen(log: widget.log),
      ));
    } finally {
      if (mounted) setState(() => _monitorOpen = false);
    }
  }

  // 長按拖曳時，記住上一個位移量以換算每次的增量。
  Offset _lastDragOffset = Offset.zero;

  void _onDragBy(Offset delta, Size screen) {
    setState(() {
      _right = (_right - delta.dx).clamp(0, screen.width - _buttonSize.width);
      _bottom = (_bottom - delta.dy).clamp(0, screen.height - _buttonSize.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Listener 當「祖先」包住整棵樹：pointer 事件會沿命中路徑往上傳到所有祖先，
    // 因此不論底下哪個 widget 處理手勢，這裡都一定收得到每一個觸控。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerFinished,
      onPointerCancel: _onPointerFinished,
      child: Stack(
        children: [
          widget.child,
          if (_visible && !_monitorOpen)
            Positioned(
              right: _right,
              bottom: _bottom,
              child: GestureDetector(
                // 用長按拖曳，避免與「點一下開監控」的 tap 在手勢競技場衝突。
                onLongPressStart: (_) => _lastDragOffset = Offset.zero,
                onLongPressMoveUpdate: (details) {
                  _onDragBy(details.offsetFromOrigin - _lastDragOffset, screen);
                  _lastDragOffset = details.offsetFromOrigin;
                },
                child: FloatingActionButton(
                  heroTag: '_data_monitor_gate_fab',
                  backgroundColor: Colors.deepPurple,
                  onPressed: _openMonitor,
                  child: const Icon(Icons.monitor_heart, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
