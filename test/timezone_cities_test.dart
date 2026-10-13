import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/yemian/timezone_data.dart';
import 'package:timezone/timezone.dart';

/// 城市表是 80 条硬编码的 IANA 标识，写错一个就是**静默退化**：
/// 运行时 `getLocation` 抛出会被 [nowIn] 的 try/catch 吞掉，
/// 时钟悄悄退成本机时间，界面上看不出任何异常。
/// 这组测试就是拿来做那个兜底 catch 的第二道网。
void main() {
  test('时区库可初始化', () {
    initTimezones();
    expect(timezonesReady, isTrue, reason: 'initTimezones 内部 try/catch 吞了异常');
  });

  test('城市表里每个 IANA 标识都真实存在于 tz 数据库', () {
    initTimezones();
    expect(kCities, isNotEmpty);
    for (final c in kCities) {
      expect(
        () => getLocation(c.location),
        returnsNormally,
        reason: '${c.name} → ${c.location} 解析失败',
      );
    }
  });

  test('城市表没有重复项（同名同位置）', () {
    final seen = <String>{};
    for (final c in kCities) {
      final key = '${c.name}|${c.location}';
      expect(seen.add(key), isTrue, reason: '$key 重复出现在城市表里');
    }
  });

  test('中国城市（除港澳台外）都落在 Asia/Shanghai', () {
    for (final c in kCities) {
      if (c.region != '中国') continue;
      if (const {'香港', '澳门', '台北'}.contains(c.name)) continue;
      expect(c.location, 'Asia/Shanghai', reason: '${c.name} 不该有独立时区');
    }
  });

  test('北京时间比东京晚一小时', () {
    initTimezones();
    final beijing = getLocation('Asia/Shanghai');
    final tokyo = getLocation('Asia/Tokyo');
    expect(
      TZDateTime.now(tokyo).timeZoneOffset - TZDateTime.now(beijing).timeZoneOffset,
      const Duration(hours: 1),
    );
  });

  test('伦敦冬夏两季的偏移不同——证明夏令时生效', () {
    initTimezones();
    final london = getLocation('Europe/London');
    // 1 月 1 日（冬令时 GMT+0）与 7 月 1 日（夏令时 BST+1）。
    final winter = TZDateTime(london, 2026, 1, 1, 12);
    final summer = TZDateTime(london, 2026, 7, 1, 12);
    expect(winter.timeZoneOffset, const Duration(hours: 0));
    expect(summer.timeZoneOffset, const Duration(hours: 1));
  });

  test('UTC 偏移格式化：整点、负数、半时区', () {
    expect(formatUtcOffset(const Duration(hours: 8)), 'UTC+8');
    expect(formatUtcOffset(const Duration(hours: -5)), 'UTC-5');
    expect(formatUtcOffset(const Duration(hours: 5, minutes: 30)), 'UTC+5:30');
    expect(formatUtcOffset(Duration.zero), 'UTC+0');
  });

  test('未知的时区标识回落到默认城市，不抛异常', () {
    expect(cityByLocation('Mars/Olympus').name, kDefaultCity.name);
  });

  test('搜索：中文名、IANA 名、地区都能命中', () {
    expect(searchCities('北京').map((c) => c.name), contains('北京'));
    expect(searchCities('asia/tokyo').map((c) => c.name), contains('东京'));
    expect(searchCities('日本').map((c) => c.name), contains('东京'));
    expect(searchCities(''), hasLength(kCities.length));
    expect(searchCities('不存在的城市'), isEmpty);
  });
}
