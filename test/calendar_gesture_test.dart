// 注意：本文件有 4 个手势测试被标了 skip，箭头切月那个仍然在跑。
//
// 【真机结论 2026-10-13】用户真机确认日历左右滑/上下滑**正常**，
// 因此 skip 纯属测试环境限制，不是产品 bug——保留 skip 仅因这个环境下
// 测试永远跑不过，取消它只会制造必红的噪声。
//
// 诊断结论（2026-10-13）：在 `flutter test` 环境里，对 calendar-pane 做
// drag、startGesture、以及手动 hitTest + handlePointerEvent，三种方式的
// 事件都**到不了** pane 上的 Listener——尽管手动 hitTest 在同一个坐标确认
// path 里包含该 RenderPointerListener，onPointerDown/Move 的计数恒为 0。
// Listener 是 Flutter 最底层的指针组件，真机不可能整体失效，
// 故判定为测试环境（AutomatedTestWidgetsFlutterBinding 的事件派发路径）
// 与该页面的组合问题。
//
// 若哪天真机上滑不动了，取消这 4 个 skip，它们立刻就是验收标准，
// 然后从 Listener 的事件派发根因查起。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/l10n/app_localizations.dart';
import 'package:l78z/yemian/calendar.dart';

/// 手势：单指左右滑换年、上下滑换月；双指捏合换粗视图、外扩换细视图
void main() {
  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // 文案已走 l10n，测试锁中文环境——断言里的「年视图」等都来自 zh 版。
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset paneCenter(WidgetTester tester) =>
      tester.getCenter(find.byKey(const ValueKey('calendar-pane')));

  String headerTitle(WidgetTester tester) {
    final pane = tester.widget(find.byKey(const ValueKey('calendar-pane')));
    expect(pane, isNotNull);
    return tester.widgetList<Text>(find.descendant(
      of: find.byKey(const ValueKey('calendar-pane')),
      matching: find.byType(Text),
    )).first.data ??
        '';
  }

  testWidgets('单指左滑 → 下一年', (tester) async {
    await pumpCalendar(tester);
    final before = headerTitle(tester);
    final c = paneCenter(tester);

    final gesture = await tester.startGesture(c);
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(headerTitle(tester), isNot(before));
  }, skip: true);

  testWidgets('单指上滑 → 下一月', (tester) async {
    await pumpCalendar(tester);
    final before = headerTitle(tester);
    final c = paneCenter(tester);

    final gesture = await tester.startGesture(c);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -10));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(headerTitle(tester), isNot(before));
  }, skip: true);

  testWidgets('双指捏合 → 月视图换粗为年视图', (tester) async {
    await pumpCalendar(tester);
    expect(find.text('月视图'), findsOneWidget);
    final c = paneCenter(tester);

    final gesture = await tester.startGesture((c + const Offset(-20, 0)));
    await tester.pump();
    final second = await tester.startGesture((c + const Offset(20, 0)));
    await tester.pump();

    // 捏合：两指向中心靠拢，scale 变小
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await second.moveBy(const Offset(-30, 0));
    await tester.pump();

    await gesture.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(find.text('年视图'), findsOneWidget);
  }, skip: true);

  testWidgets('双指外扩 → 年视图换细为月视图', (tester) async {
    await pumpCalendar(tester);
    final c = paneCenter(tester);

    Future<void> pinchIn() async {
      final gesture = await tester.startGesture((c + const Offset(-20, 0)));
      await tester.pump();
      final second = await tester.startGesture((c + const Offset(20, 0)));
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await second.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.up();
      await second.up();
      await tester.pumpAndSettle();
    }

    Future<void> pinchOut() async {
      final gesture = await tester.startGesture((c + const Offset(-60, 0)));
      await tester.pump();
      final second = await tester.startGesture((c + const Offset(60, 0)));
      await tester.pump();
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      await second.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await second.up();
      await tester.pumpAndSettle();
    }

    // 先捏合进年视图
    await pinchIn();
    expect(find.text('年视图'), findsOneWidget);

    // 再外扩回月视图
    await pinchOut();
    expect(find.text('月视图'), findsOneWidget);
  }, skip: true);

  testWidgets('右箭头切月、左箭头切回', (tester) async {
    await pumpCalendar(tester);
    final before = headerTitle(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(headerTitle(tester), isNot(before));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(headerTitle(tester), before);
  });
}
