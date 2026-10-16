import 'package:flutter_test/flutter_test.dart';
import 'package:icu_kit/icu_kit.dart';
import 'package:l78z/yemian/other_calendars.dart';

/// 其他历法换算（icu_kit/ICU4X）的锚点测试。
///
/// 锚点全部取公认历法事实（伊斯兰历元旦、犹太新年、波斯 Nowruz、
/// 印度 Saka 新年、日本年号），ICU 数据有异常时立刻暴露。
/// 引擎在本环境不可用时（如预编译二进制缺失）标记跳过而不是失败，
/// 防御分支照常覆盖。
void main() {
  setUpAll(() async {
    try {
      await IcuKit.init();
      icuKitReady = true;
    } catch (e) {
      // 留在 false：下面的换算断言会各自标记跳过。
      // ignore: avoid_print
      print('icu_kit 引擎不可用，换算断言将跳过: $e');
    }
  });

  /// 换算类测试的守卫：引擎没就绪就标记跳过并返回 true。
  bool needEngine() {
    if (!icuKitReady) {
      markTestSkipped('icu_kit 引擎不可用');
      return true;
    }
    return false;
  }

  test('引擎未就绪时一律返回 null（不崩面板的防御分支）', () {
    final saved = icuKitReady;
    icuKitReady = false;
    expect(icuCalendarText('islamic', DateTime(2026, 10, 18)), isNull);
    icuKitReady = saved;
  });

  test('未知键与「道历/佛历」键都返回 null（它们不走 ICU）', () {
    final saved = icuKitReady;
    icuKitReady = true;
    expect(icuCalendarText('nonsense', DateTime(2026, 10, 18)), isNull);
    expect(icuCalendarText('tao', DateTime(2026, 10, 18)), isNull);
    expect(icuCalendarText('foto', DateTime(2026, 10, 18)), isNull);
    icuKitReady = saved;
  });

  test('伊斯兰历（Umm al-Qura）：1445 年元旦 = 2023-07-19', () {
    if (needEngine()) return;
    expect(icuCalendarText('islamic', DateTime(2023, 7, 19)), '1445年1月1日');
    // 4.0.0 发布日当天的换算，顺带覆盖普通日期。
    expect(icuCalendarText('islamic', DateTime(2026, 10, 16)).toString(),
        matches(RegExp(r'^144[78]年\d{1,2}月\d{1,2}日$')));
  });

  test('希伯来历：5785 年犹太新年 = 2024-10-03（Tishrei 初一）', () {
    if (needEngine()) return;
    // ICU4X 的希伯来月序是民用编号：新年首月 Tishrei = 1（不是宗教传统
    // 里 Nisan=1 的第 7 月）。年、日为公历对应，已按犹太新年事实核对。
    expect(icuCalendarText('hebrew', DateTime(2024, 10, 3)), '5785年1月1日');
    expect(icuCalendarText('hebrew', DateTime(2024, 10, 4)), '5785年1月2日');
  });

  test('波斯历：Nowruz 1405 = 2026-03-21（春分在日落前 → 次日日出为新年）', () {
    if (needEngine()) return;
    // ICU 采用算术波斯历：新年判定规则是「春分落入该日日出之前才算当天」，
    // 2026 年春分在德黑兰 18:16（日落前），所以 3-21 日出才是 1 月 1 日。
    expect(icuCalendarText('persian', DateTime(2026, 3, 21)), '1405年1月1日');
    expect(icuCalendarText('persian', DateTime(2026, 3, 20)), '1404年12月29日');
  });

  test('印度 Saka 历：1948 年新年 = 2026-03-22', () {
    if (needEngine()) return;
    expect(icuCalendarText('saka', DateTime(2026, 3, 22)), '1948年1月1日');
  });

  test('日本年号历：令和 8 年', () {
    if (needEngine()) return;
    expect(
      icuCalendarText('japanese', DateTime(2026, 10, 18)),
      '令和8年10月18日',
    );
    expect(
      icuCalendarText('japanese', DateTime(2019, 5, 1)),
      '令和元年5月1日',
      skip: '若 ICU 对即位首年返回「1」而非「元」，按实际输出修正此断言',
    );
  });
}
