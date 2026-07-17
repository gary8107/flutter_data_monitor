import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../monitor_log.dart';
import 'monitor_screen.dart';

/// 可拖曳的懸浮容器，把 [MonitorButton] 掛到畫面右下角。
///
/// 用法（在有 Overlay 的地方，例如 MaterialApp 底下的頁面）：
/// ```dart
/// MonitorOverlay.attachTo(context);
/// ```
class MonitorOverlay extends StatefulWidget {
  const MonitorOverlay._({
    required this.right,
    required this.bottom,
    required this.draggable,
    required this.log,
  });

  final double bottom;
  final double right;
  final bool draggable;
  final MonitorLog log;

  static const double _defaultPadding = 30;

  /// 掛到指定 [context] 的 Overlay。回傳 [OverlayEntry] 方便日後移除。
  static OverlayEntry attachTo(
    BuildContext context, {
    bool rootOverlay = true,
    double bottom = _defaultPadding,
    double right = _defaultPadding,
    bool draggable = true,
    MonitorLog? log,
  }) {
    final entry = OverlayEntry(
      builder: (context) => MonitorOverlay._(
        bottom: bottom,
        right: right,
        draggable: draggable,
        log: log ?? Monitor.instance,
      ),
    );
    // 下一幀再插入，避免在 build 過程中改動 Overlay。
    Future.delayed(Duration.zero, () {
      final overlay = Overlay.maybeOf(context, rootOverlay: rootOverlay);
      if (overlay == null) {
        throw FlutterError(
          'DataMonitor: 找不到 Overlay。請在 MaterialApp / Navigator 之下的頁面呼叫 '
          'MonitorOverlay.attachTo()。',
        );
      }
      overlay.insert(entry);
    });
    return entry;
  }

  @override
  State<MonitorOverlay> createState() => _MonitorOverlayState();
}

class _MonitorOverlayState extends State<MonitorOverlay> {
  static const Size _buttonSize = Size(57, 57);

  late double bottom = widget.bottom;
  late double right = widget.right;
  late MediaQueryData screen;
  Offset? lastPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screen = MediaQuery.of(context);
  }

  void _onDrag(LongPressMoveUpdateDetails details) {
    final delta = lastPosition! - details.localPosition;
    bottom += delta.dy;
    right += delta.dx;
    lastPosition = details.localPosition;

    // 夾住邊界，避免拖出畫面外。
    bottom = bottom.clamp(0, screen.size.height - _buttonSize.height);
    right = right.clamp(0, screen.size.width - _buttonSize.width);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.draggable) {
      return Positioned(
        right: widget.right + screen.padding.right,
        bottom: widget.bottom + screen.padding.bottom,
        child: MonitorButton(log: widget.log),
      );
    }

    return Positioned(
      right: right,
      bottom: bottom,
      child: GestureDetector(
        onLongPressMoveUpdate: _onDrag,
        onLongPressUp: () => setState(() => lastPosition = null),
        onLongPressDown: (details) =>
            setState(() => lastPosition = details.localPosition),
        child: Material(
          color: Colors.transparent,
          elevation: lastPosition == null ? 0 : 30,
          borderRadius: BorderRadius.circular(_buttonSize.width),
          child: MonitorButton(log: widget.log),
        ),
      ),
    );
  }
}

/// 開啟 [MonitorScreen] 的懸浮按鈕，有新紀錄時會閃爍提示。
class MonitorButton extends StatefulWidget {
  MonitorButton({
    super.key,
    this.color = Colors.deepPurple,
    this.blinkPeriod = const Duration(milliseconds: 1500),
    this.showOnlyOnDebug = false,
    MonitorLog? log,
  }) : log = log ?? Monitor.instance;

  /// 記錄流來源。
  final MonitorLog log;

  /// 閃爍週期。
  final Duration blinkPeriod;

  /// 按鈕底色。
  final Color color;

  /// 設為 true 時，只在 debug build 顯示（release 自動隱藏）。
  final bool showOnlyOnDebug;

  @override
  State<MonitorButton> createState() => _MonitorButtonState();
}

class _MonitorButtonState extends State<MonitorButton> {
  StreamSubscription<MonitorUpdate>? _subscription;
  Timer? _blinkTimer;
  bool _visible = true;
  int _blink = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _blinkTimer = Timer.periodic(widget.blinkPeriod, (_) {
      if (_blink > 0 && mounted) setState(() => _blink--);
    });
  }

  @override
  void didUpdateWidget(covariant MonitorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log != widget.log) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.log.stream.listen((_) {
      if (mounted) setState(() => _blink = _blink % 2 == 0 ? 6 : 5);
    });
  }

  Future<void> _open() async {
    setState(() => _visible = false);
    try {
      await MonitorScreen.open(context, log: widget.log);
    } finally {
      if (mounted) setState(() => _visible = true);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox();
    if (widget.showOnlyOnDebug && !kDebugMode) return const SizedBox();

    return FloatingActionButton(
      backgroundColor: widget.color,
      onPressed: _open,
      child: Icon(
        _blink % 2 == 0 ? Icons.monitor_heart : Icons.monitor_heart_outlined,
        color: Colors.white,
      ),
    );
  }
}
