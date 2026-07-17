import 'package:flutter/material.dart';

import '../monitor_entry.dart';
import '../monitor_log.dart';
import 'monitor_entry_screen.dart';
import 'monitor_ui_common.dart';

/// 條目列表頁：關鍵字搜尋 + 分類 chip 篩選 + 清空。
class MonitorScreen extends StatefulWidget {
  MonitorScreen({super.key, MonitorLog? log}) : log = log ?? Monitor.instance;

  final MonitorLog log;

  static Future<void> open(BuildContext context, {MonitorLog? log}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => MonitorScreen(log: log),
    ));
  }

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _searchController = TextEditingController();

  /// 已選取的分類；空集合代表不篩選（顯示全部）。
  final _selectedCategories = <String>{};

  MonitorLog get log => widget.log;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MonitorEntry> _filtered() {
    final query = _searchController.text.trim().toLowerCase();
    return log.entries.where((entry) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(entry.category)) {
        return false;
      }
      if (query.isEmpty) return true;
      return entry.title.toLowerCase().contains(query) ||
          (entry.subtitle?.toLowerCase().contains(query) ?? false) ||
          (entry.source?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('監控紀錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
            onPressed: () {
              log.clear();
              _selectedCategories.clear();
            },
          ),
        ],
      ),
      // 監聽記錄流：任何新增／更新／清空都會觸發重建。
      body: StreamBuilder<MonitorUpdate>(
        stream: log.stream,
        builder: (context, _) {
          final entries = _filtered();
          final categories = log.categories.toList()..sort();
          return Column(
            children: [
              _searchField(),
              if (categories.isNotEmpty) _categoryFilter(categories),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('尚無紀錄'))
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _tile(context, entries[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        autocorrect: false,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          prefixIcon: const Icon(Icons.search),
          hintText: '輸入關鍵字搜尋（標題／副標題／裝置品類）',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _categoryFilter(List<String> categories) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category),
                selected: _selectedCategories.contains(category),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, MonitorEntry entry) {
    return ListTile(
      key: ValueKey(entry.id),
      dense: true,
      leading: statusIcon(entry.status),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: (entry.source == null && entry.subtitle == null)
          ? null
          : Row(
              children: [
                if (entry.source != null) ...[
                  Flexible(child: sourceBadge(entry.source!)),
                  const SizedBox(width: 6),
                ],
                if (entry.subtitle != null)
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatClock(entry.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          categoryBadge(entry.category),
        ],
      ),
      onTap: () => MonitorEntryScreen.open(context, entry, log),
    );
  }
}
