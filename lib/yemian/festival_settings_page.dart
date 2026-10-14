//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 节日节气的设置页与「隐藏的节日」管理页。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'festival_prefs.dart';
import 'festival_scan.dart';

/// 节日节气设置页。
///
/// 对照原版截图砍掉了两项：「开启提醒」和「通知栏常驻（VIP）」——
/// 提醒通知在需求阶段就明确划到范围之外了。
/// 「首页显示最近节日」也不做：本页本身就是全量列表，没有「最近」的概念。
class FestivalSettingsPage extends StatefulWidget {
  const FestivalSettingsPage({super.key, this.items});

  /// 列表页已扫好的结果，原样转给隐藏管理页，省掉重复扫描。
  final List<FestivalItem>? items;

  @override
  State<FestivalSettingsPage> createState() => _FestivalSettingsPageState();
}

class _FestivalSettingsPageState extends State<FestivalSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.festTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.festColorfulBg),
            subtitle: Text(l10n.festColorfulBgSub),
            value: FestivalPrefs.showCover,
            onChanged: (v) async {
              await FestivalPrefs.setShowCover(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(l10n.festShowEmoji),
            subtitle: Text(l10n.festShowEmojiSub),
            value: FestivalPrefs.showEmoji,
            onChanged: (v) async {
              await FestivalPrefs.setShowEmoji(v);
              setState(() {});
            },
          ),
          ListTile(
            title: Text(l10n.festCoverColor),
            trailing: Text(
                FestivalPrefs.randomCover ? l10n.festCoverRandom : l10n.festCoverRotate),
            onTap: () async {
              final picked = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.festCoverColor),
                  content: RadioGroup<String>(
                    groupValue: FestivalPrefs.coverColor,
                    onChanged: (v) => Navigator.pop(ctx, v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String>(
                          value: 'order',
                          title: Text(l10n.festCoverRotate),
                          subtitle: Text(l10n.festCoverRotateSub),
                        ),
                        RadioListTile<String>(
                          value: 'random',
                          title: Text(l10n.festCoverRandom),
                          subtitle: Text(l10n.festCoverRandomSub),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (picked != null) {
                await FestivalPrefs.setCoverColor(picked);
                if (mounted) setState(() {});
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: Text(l10n.festHiddenTitle),
            subtitle: Text(
              FestivalPrefs.hidden.isEmpty
                  ? l10n.festHiddenNone
                  : l10n.festHiddenCount(FestivalPrefs.hidden.length),
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: widget.items != null,
            onTap: widget.items == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FestivalHiddenPage(items: widget.items!),
                      ),
                    );
                    // 隐藏项数量变了，返回上一层时副标题要跟着变。
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
    );
  }
}

/// 「隐藏的节日」管理页：把不关心的节日从列表里藏掉。
///
/// 隐藏后列表页和空态提示都会反映出来，这里可以随时恢复。
/// 已隐藏的置底，方便「我刚藏了哪个」。
class FestivalHiddenPage extends StatefulWidget {
  const FestivalHiddenPage({super.key, required this.items});

  /// 全年扫描结果，用来枚举出所有出现过的节日 / 节气名。
  final List<FestivalItem> items;

  @override
  State<FestivalHiddenPage> createState() => _FestivalHiddenPageState();
}

class _FestivalHiddenPageState extends State<FestivalHiddenPage> {
  /// 去重后按首次出现顺序（已按天数升序）的名字列表。
  late final List<String> _names;

  @override
  void initState() {
    super.initState();
    final seen = <String>{};
    _names = <String>[];
    for (final e in widget.items) {
      if (seen.add(e.name)) _names.add(e.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _names
        .where((n) => !FestivalPrefs.hidden.contains(n))
        .toList(growable: false);
    final hidden = _names
        .where((n) => FestivalPrefs.hidden.contains(n))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.festHiddenTitle)),
      body: ListView(
        children: [
          _groupHeader(l10n.festGroupVisible(visible.length), visible),
          _groupHeader(l10n.festGroupHidden(hidden.length), hidden),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _groupHeader(String title, List<String> names) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        for (final name in names)
          SwitchListTile(
            dense: true,
            title: Text(name),
            value: !FestivalPrefs.hidden.contains(name),
            onChanged: (v) async {
              // v = 是否显示；隐藏即把 v 取反写进名单。
              await FestivalPrefs.setHidden(name, !v);
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}
