import 'package:flutter/material.dart';

import '../monitor_entry.dart';
import '../monitor_log.dart';
import 'monitor_ui_common.dart';

/// 顯示單筆條目的詳情。多個 tab 顯示 TabBar；否則直接顯示唯一內容。
class MonitorEntryScreen extends StatelessWidget {
  const MonitorEntryScreen({
    super.key,
    required this.entry,
    required this.log,
  });

  final MonitorEntry entry;
  final MonitorLog log;

  /// 開啟詳情。以 stream 監聽同一筆的更新（例如 HTTP pending → response），
  /// 收到就重建畫面。
  static Future<void> open(
    BuildContext context,
    MonitorEntry entry,
    MonitorLog log,
  ) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => StreamBuilder<MonitorUpdate>(
        stream: log.stream.where((update) => update.entry == entry),
        builder: (context, _) => MonitorEntryScreen(entry: entry, log: log),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = entry.tabs;
    final hasTabBar = tabs.length > 1;

    return DefaultTabController(
      length: tabs.isEmpty ? 1 : tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('紀錄詳情'),
          bottom: hasTabBar
              ? TabBar(tabs: [for (final tab in tabs) Tab(text: tab.name)])
              : null,
        ),
        body: Column(
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: tabs.isEmpty
                  ? const Center(child: Text('（無內容）'))
                  : TabBarView(
                      children: [
                        for (final tab in tabs) _sectionList(context, tab),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: categoryColor(entry.category).withOpacity(0.08),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              categoryBadge(entry.category),
              const SizedBox(width: 8),
              statusText(entry.status),
              const Spacer(),
              Text(
                formatClock(entry.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            entry.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (entry.subtitle != null) ...[
            const SizedBox(height: 2),
            SelectableText(
              entry.subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionList(BuildContext context, MonitorTab tab) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final section in tab.sections) section.build(context),
      ],
    );
  }
}
