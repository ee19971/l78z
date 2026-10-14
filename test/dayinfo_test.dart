import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/l10n/app_localizations.dart';
import 'package:l78z/yemian/calendar.dart';
import 'package:l78z/yemian/festivals.dart';

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

  testWidgets('底部详情栏展示节日/节气/干支', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // 文案已走 l10n，测试锁中文环境。
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CalendarPage()),
      ),
    );

    expect(find.text('节日'), findsOneWidget);
    expect(find.text('节气'), findsOneWidget);
    expect(find.text('干支'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^..年 ..月 ..日$')), findsOneWidget);

    // 回到 2026 年 1 月，点开元旦
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byIcon(Icons.chevron_left));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    // 网格小字 + 详情栏节日行 + 高亮行
    expect(find.text('元旦节'), findsNWidgets(3));
  });
}
