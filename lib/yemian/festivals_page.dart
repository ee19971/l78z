//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 节日节气列表页——未来一年的节日与节气，按「还有几天」升序排。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'festival_prefs.dart';
import 'festival_scan.dart';
import 'festival_settings_page.dart';
import 'festivals.dart';

/// 节日节气列表：从今天起一年内的所有节日与节气。
///
/// 卡片样式照参考图：标题 + emoji、日期行、类型徽章，右侧「还有 N 天」。
class FestivalsPage extends StatefulWidget {
  const FestivalsPage({super.key});

  @override
  State<FestivalsPage> createState() => _FestivalsPageState();
}

class _FestivalsPageState extends State<FestivalsPage> {
  /// 扫描结果；null 表示还没扫完。
  List<FestivalItem>? _items;

  /// 搜索关键词；null 表示搜索框收起。
  String? _query;
  final _searchCtrl = TextEditingController();

  /// 当日随机 seed：同一天内配色稳定，跨天才换。
  late final int _seed;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _seed = now.year * 10000 + now.month * 100 + now.day;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 先读偏好，再扫。扫描本身要 50~200ms，两件事都在这里等，
    // 首屏先画一帧 loading（_items 仍为 null），避免首帧卡顿。
    await FestivalPrefs.load();
    final items = scanFestivals();
    if (!mounted) return;
    setState(() => _items = items);
  }

  /// 从设置页回来时重读偏好并重画——静态字段已被设置页改过，
  /// 这里只需 setState，但隐藏名单要重新过滤。
  Future<void> _reloadAfterSettings() async {
    await FestivalPrefs.load();
    if (!mounted) return;
    setState(() {});
  }

  List<FestivalItem> get _visible {
    final all = _items ?? const <FestivalItem>[];
    final q = _query?.trim();
    return all.where((e) {
      if (FestivalPrefs.hidden.contains(e.name)) return false;
      if (q != null && q.isNotEmpty && !e.name.contains(q)) return false;
      return true;
    }).toList();
  }

  // -----------------------------------------------------------------------
  // 卡片
  // -----------------------------------------------------------------------

  /// 日期行：按来源选写法，需要拿当天的 [DayInfo]。
  String _dateLabel(FestivalItem item) =>
      festivalDateLabel(context, DayInfo.of(item.date), item.isLunar);

  Widget _card(FestivalItem item, int index) {
    final theme = Theme.of(context);
    final bg = FestivalPrefs.showCover
        ? festivalCardColor(index,
            random: FestivalPrefs.randomCover, seed: _seed)
        : theme.colorScheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (FestivalPrefs.showEmoji) ...[
                        const SizedBox(width: 6),
                        Text(festivalEmoji(item),
                            style: const TextStyle(fontSize: 18)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateLabel(item),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badgeLabel(AppLocalizations.of(context)!),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _daysLeft(item.daysLeft),
          ],
        ),
      ),
    );
  }

  /// 右侧「还有 **N** 天」：小字、大数字、小字，三段垂直居中。
  ///
  /// 当天显示「今天」而不是「0 天」——数字 0 读起来像「还没到」，
  /// 而这天其实就是今天。
  Widget _daysLeft(int days) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (days == 0) {
      return Text(
        l10n.commonToday,
        style: theme.textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(l10n.festRemain, style: theme.textTheme.labelSmall),
        Text(
          '$days',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        Text(l10n.commonDayUnit, style: theme.textTheme.labelSmall),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // 外壳
  // -----------------------------------------------------------------------

  Widget _buildBody() {
    final items = _visible;

    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      final theme = Theme.of(context);
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              _query?.trim().isNotEmpty ?? false
                  ? l10n.festNoMatch(_query!.trim())
                  : l10n.festEmpty,
              style: theme.textTheme.bodyMedium,
            ),
            if (FestivalPrefs.hidden.isNotEmpty &&
                !(_query?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Text(
                l10n.festHiddenNotice(FestivalPrefs.hidden.length),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) => _card(items[i], i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.festTitle),
        actions: [
          IconButton(
            icon: Icon(_query == null ? Icons.search : Icons.close),
            tooltip: _query == null ? l10n.festSearch : l10n.festCloseSearch,
            onPressed: () {
              setState(() {
                if (_query == null) {
                  _query = '';
                } else {
                  _query = null;
                  _searchCtrl.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.toolsSettings,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FestivalSettingsPage(items: _items),
                ),
              );
              await _reloadAfterSettings();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框收起时整条不占位，避免列表顶上多一条空缝。
          if (_query != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.festSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
