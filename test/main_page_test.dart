import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/main.dart';
import 'package:l78z/yemian/calendar.dart';

void main() {
  testWidgets('默认进入主页面，底部导航顺序正确', (tester) async {
    await tester.pumpWidget(const MyApp());

    // 默认展示主页面内容 + 导航栏同名标签
    expect(find.text('主页面'), findsNWidgets(2));

    // 徽标顺序：节日节气、日期计算、主页面、工具、倒数日、日历
    final nav = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(NavigationDestination),
    );
    expect(
      tester.widgetList<NavigationDestination>(nav).map((d) => d.label),
      ['节日节气', '日期计算', '主页面', '工具', '倒数日', '日历'],
    );

    // 默认选中主页面（index 2）
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    // 点击日历切换
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage), findsOneWidget);
  });

  testWidgets('工具页可进入并含三个入口', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('工具'));
    await tester.pumpAndSettle();
    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('二维码 / 条形码'), findsOneWidget);
    expect(find.text('局域网传输'), findsOneWidget);
  });
}
