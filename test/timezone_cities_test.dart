import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/yemian/timezone_data.dart';
import 'package:timezone/timezone.dart';

/// 首都表是 73 条硬编码的 IANA 标识，写错一个就是**静默退化**：
/// 运行时 `getLocation` 抛出会被 [nowIn] 的 try/catch 吞掉，
/// 时钟悄悄退成本机时间，界面上看不出任何异常。
/// 这组测试就是拿来做那个兜底 catch 的第二道网。
void main() {
  test('时区库可初始化', () {
    initTimezones();
    expect(timezonesReady, isTrue, reason: 'initTimezones 内部 try/catch 吞了异常');
  });

  test('首都表里每个 IANA 标识都真实存在于 tz 数据库', () {
    initTimezones();
    expect(kCities, isNotEmpty);
    for (final c in kCities) {
      expect(
        () => getLocation(c.location),
        returnsNormally,
        reason: '${c.region} ${c.name} → ${c.location} 解析失败',
      );
    }
  });

  test('首都表规模在精选区间，且按五大洲分组', () {
    expect(kCities.length, inInclusiveRange(60, 80));
    expect(
      kContinentCities.keys,
      ['亚洲', '欧洲', '非洲', '美洲', '大洋洲'],
    );
    // 平铺表与分组表必须一致，否则搜索结果和列表会对不上。
    expect(kCities.length,
        kContinentCities.values.fold<int>(0, (sum, g) => sum + g.length));
  });

  test('首都表没有重复项（同名同位置）', () {
    final seen = <String>{};
    for (final c in kCities) {
      final key = '${c.name}|${c.location}';
      expect(seen.add(key), isTrue, reason: '$key 重复出现在首都表里');
    }
  });

  test('中国条目只有北京且落在 Asia/Shanghai', () {
    final china = [for (final c in kCities) if (c.region == '中国') c];
    expect(china, hasLength(1));
    expect(china.single.name, '北京');
    expect(china.single.location, 'Asia/Shanghai');
  });

  test('每个首都都挂在自己的国家名下', () {
    for (final c in kCities) {
      expect(c.region, isNotEmpty, reason: '${c.name} 缺国家名');
      expect(c.name, isNotEmpty);
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

  test('未知的时区标识回落到默认首都，不抛异常', () {
    expect(cityByLocation('Mars/Olympus').name, kDefaultCity.name);
    expect(cityByLocation('Asia/Shanghai').name, '北京');
  });

  test('搜索：首都名、国家名、IANA 名都能命中', () {
    expect(searchCities('北京').map((c) => c.name), contains('北京'));
    expect(searchCities('asia/tokyo').map((c) => c.name), contains('东京'));
    expect(searchCities('日本').map((c) => c.name), contains('东京'));
    expect(searchCities('法国').map((c) => c.name), contains('巴黎'));
    expect(searchCities(''), hasLength(kCities.length));
    expect(searchCities('不存在的国家'), isEmpty);
  });

  test('分组搜索：命中的组保留标题，未命中的组整个消失', () {
    final groups = searchCitiesGrouped('法国');
    expect(groups.keys, ['欧洲']);
    expect(groups['欧洲']!.map((c) => c.name), ['巴黎']);

    // 搜 IANA 前缀跨组命中：亚洲组和美洲组都该在。
    final wide = searchCitiesGrouped('america/');
    expect(wide.keys, containsAll(['美洲']));
    expect(wide['美洲']!.map((c) => c.name), contains('华盛顿'));

    // 空查询返回全部组。
    expect(searchCitiesGrouped('').keys, kContinentCities.keys);
  });
}
