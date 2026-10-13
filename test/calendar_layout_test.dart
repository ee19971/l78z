import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/yemian/calendar.dart';

Future<void> pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: CalendarPage())),
  );
  await tester.pump();
}

void main() {
  testWidgets('紧凑竖屏：单列布局，无溢出', (tester) async {
    await pumpAt(tester, const Size(280, 480));
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text('干支'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('矮横屏：整体滚动，无溢出', (tester) async {
    await pumpAt(tester, const Size(500, 320));
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text('干支'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板竖屏：左日历右详情', (tester) async {
    await pumpAt(tester, const Size(768, 1024));
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('干支'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('折叠屏展开：日历与详情各占一半', (tester) async {
    // 三星 Z Fold 展开后的逻辑宽度约 670~800
    await pumpAt(tester, const Size(673, 659));

    expect(find.byType(VerticalDivider), findsOneWidget);
    final half = (673 - 1) / 2;
    expect(
      tester.getSize(find.byKey(const ValueKey('calendar-pane'))).width,
      closeTo(half, 1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-pane'))).width,
      closeTo(half, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面宽屏：日历 3/5、详情 2/5', (tester) async {
    await pumpAt(tester, const Size(1200, 800));

    final rest = 1200 - 1;
    expect(
      tester.getSize(find.byKey(const ValueKey('calendar-pane'))).width,
      closeTo(rest * 3 / 5, 1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-pane'))).width,
      closeTo(rest * 2 / 5, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面宽屏：左日历右详情且可点选', (tester) async {
    await pumpAt(tester, const Size(1000, 700));
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('干支'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'-15$')), findsOneWidget);
  });
}
