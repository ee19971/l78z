//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 城市选择弹层——主页面时钟与设置页「时区城市」共用。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'timezone_data.dart';

/// 打开城市选择弹层；选中返回 [CityInfo]，取消返回 null。
///
/// 泛型用 Object? 而非 void：返回值要做 `is CityInfo` 判断，
/// 对 void 做类型检查是编译错误。
Future<CityInfo?> showCityPickerSheet(BuildContext context) async {
  final value = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CityPickerSheet(),
  );
  return value is CityInfo ? value : null;
}

/// 城市选择弹层：搜索框 + 按大洲分组的列表，选中即返回 [CityInfo]。
class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({super.key});

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 分组结果展平成混合行：大洲名（String）与首都（CityInfo）交替，
    // 标题行只在该组有命中时出现。
    final rows = <Object>[
      for (final entry in searchCitiesGrouped(_query).entries) ...[
        entry.key,
        ...entry.value,
      ],
    ];
    // 结果太多时把弹层撑高：给了七成屏，剩下的空间让列表自己滚。
    final sheetHeight = MediaQuery.of(context).size.height * 0.7;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                isDense: true,
                hintText: AppLocalizations.of(context)!.pickerSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                        AppLocalizations.of(context)!.pickerNoMatch(_query),
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is String) {
                        // 大洲分组标题：上留白让它和上一组拉开距离。
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            row,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                          ),
                        );
                      }
                      final c = row as CityInfo;
                      return ListTile(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text('${c.region} · ${c.location}'),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
