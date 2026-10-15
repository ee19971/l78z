import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/l10n/app_localizations.dart';
import 'package:l78z/yemian/calendar.dart';
import 'package:l78z/yemian/calendar_prefs.dart';
import 'package:l78z/yemian/festivals.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('DayInfo 节日/节气/干支', () {
    final newYear = DayInfo.of(DateTime(2026, 1, 1));
    expect(newYear.festivals, contains('元旦节'));

    final spring = DayInfo.of(DateTime(2026, 2, 17));
    expect(spring.festivals, contains('春节'));
    expect(spring.lunarDayText, '初一');

    final lichun = DayInfo.of(DateTime(2026, 2, 4));
    expect(lichun.jieQi, '立春');

    final plain = DayInfo.of(DateTime(2026, 10, 10));
    expect(plain.jieQi, '');
    expect(plain.cellLabel, isNotEmpty);
    expect(plain.ganZhiText, matches(RegExp(r'^..年 ..月 ..日$')));
    expect(plain.weekText, '星期六');

    // 缓存命中应返回同一实例
    expect(identical(DayInfo.of(plain.date), plain), isTrue);
  });

  testWidgets('默认档：详情栏只有节气/干支，不列节日', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CalendarPrefs.load();
    await tester.pumpWidget(
      MaterialApp(
        // 文案已走 l10n，测试锁中文环境。
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CalendarPage()),
      ),
    );

    // 默认档（节气+农历日）刻意不列节日——「节日」行整行消失。
    expect(find.text('节日'), findsNothing);
    expect(find.text('节气'), findsOneWidget);
    expect(find.text('干支'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^..年 ..月 ..日$')), findsOneWidget);

    // 回到 2026 年 1 月，点开元旦：格子小字是农历日而非节日名。
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byIcon(Icons.chevron_left));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('元旦节'), findsNothing);
  });

  testWidgets('完整档：格子小字与详情栏恢复节日显示', (tester) async {
    // 用 mock prefs 指定档位：initState 里的 load() 会从这里读到「完整」，
    // 不会把内存值又刷回默认。
    SharedPreferences.setMockInitialValues({'calendar_cell_label_mode': 'full'});
    await CalendarPrefs.load();
    addTearDown(() => CalendarPrefs.cellLabelMode = CellLabelMode.jieqiLunar);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CalendarPage()),
      ),
    );

    expect(find.text('节日'), findsOneWidget);

    // 回到 2026 年 1 月，点开元旦：网格小字 + 详情栏节日行 + 高亮行。
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byIcon(Icons.chevron_left));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('元旦节'), findsNWidgets(3));
  });
}
