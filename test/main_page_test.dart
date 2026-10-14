import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/main.dart';
import 'package:l78z/yemian/calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 文案走 l10n 后环境语言决定断言文本；mock prefs 锁中文，避免 flutter_test
  // 默认 en_US 让 find.text('主页面')扑空。MyApp 首帧后会异步 load 这份 prefs。
  setUpAll(() {
    SharedPreferences.setMockInitialValues({'app_locale': 'zh_CN'});
  });

  testWidgets('默认进入主页面，底部导航顺序正确', (tester) async {
    await tester.pumpWidget(const MyApp());
    // load() 是异步的，等它 notifyListeners 触发 MaterialApp 重建。
    await tester.pumpAndSettle();

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
    // 与上一个测试同理：locale 由异步 load 决定，等一帧再找中文文案。
    await tester.pumpAndSettle();
    await tester.tap(find.text('工具'));
    await tester.pumpAndSettle();
    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('二维码 / 条形码'), findsOneWidget);
    expect(find.text('局域网传输'), findsOneWidget);
    // 设置入口已移到主页面，工具页不再出现。
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('主页面右上角齿轮直达设置', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    // 设置页的配置卡在等 Rust 侧数据（测试环境不会完成），进度环会一直转，
    // pumpAndSettle 会超时；等两帧让路由动画走完即可。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('语言与地区'), findsOneWidget);
  });
}
