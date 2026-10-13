//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 精选城市表与时区库初始化——主页面时钟的时间来源。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 精选城市：名字、IANA 时区标识、所属国家/地区。
class CityInfo {
  const CityInfo(this.name, this.location, this.region);

  /// 中文名，搜索就搜这个。
  final String name;

  /// IANA 标识，如 `Asia/Shanghai`。时区库据此查夏令时规则。
  final String location;

  /// 所属国家或地区，列表里用作分组副标题。
  final String region;
}

/// 时区库是否已就绪。
///
/// 初始化失败不会抛出去——时钟页会退回本机时间继续可用，
/// 比整个主页面白屏强。
bool timezonesReady = false;

/// 初始化 IANA 时区库，幂等，失败静默降级。
///
/// 用的是 `package:timezone/data/latest_10y.dart`：它是**编译进包的 Dart
/// 源码**，自带字节数组直接内存初始化，不需要 asset 声明，也不走
/// rootBundle。而包里 `standalone.dart` 的 `initializeTimeZone()` 走
/// `Isolate.resolvePackageUri` 找文件，在 Flutter 里找不到——那条路不能用。
///
/// 数据覆盖未来 10 年的夏令时规则，对一个常驻城市的选择器绰绰有余；
/// 真到了 2036 年，这版本 App 早该升级了。
void initTimezones() {
  if (timezonesReady) return;
  try {
    tzdata.initializeTimeZones();
    timezonesReady = true;
  } catch (_) {
    timezonesReady = false;
  }
}

/// 默认城市：北京。
///
/// 不引 `flutter_native_timezone` 去取本机时区名——那个插件 Windows 上
/// 没有实现，而我们有 msix 产物，为省一次手动切换拉一个跨平台不全的
/// 原生依赖不划算。用户点一下城市名就能换。
const CityInfo kDefaultCity = CityInfo('北京', 'Asia/Shanghai', '中国');

/// 精选城市表：中国 37 个 + 全球主要都市 45 个。
///
/// 全国除港澳台外都挂在 `Asia/Shanghai` 下——中国自 1991 年起全国统一
/// 不再分时区夏令时，映射到同一个 location 是准确的。
const List<CityInfo> kCities = [
  // ---- 中国 ----
  CityInfo('北京', 'Asia/Shanghai', '中国'),
  CityInfo('上海', 'Asia/Shanghai', '中国'),
  CityInfo('天津', 'Asia/Shanghai', '中国'),
  CityInfo('重庆', 'Asia/Shanghai', '中国'),
  CityInfo('广州', 'Asia/Shanghai', '中国'),
  CityInfo('深圳', 'Asia/Shanghai', '中国'),
  CityInfo('成都', 'Asia/Shanghai', '中国'),
  CityInfo('杭州', 'Asia/Shanghai', '中国'),
  CityInfo('南京', 'Asia/Shanghai', '中国'),
  CityInfo('武汉', 'Asia/Shanghai', '中国'),
  CityInfo('西安', 'Asia/Shanghai', '中国'),
  CityInfo('长沙', 'Asia/Shanghai', '中国'),
  CityInfo('郑州', 'Asia/Shanghai', '中国'),
  CityInfo('济南', 'Asia/Shanghai', '中国'),
  CityInfo('青岛', 'Asia/Shanghai', '中国'),
  CityInfo('合肥', 'Asia/Shanghai', '中国'),
  CityInfo('福州', 'Asia/Shanghai', '中国'),
  CityInfo('厦门', 'Asia/Shanghai', '中国'),
  CityInfo('南昌', 'Asia/Shanghai', '中国'),
  CityInfo('石家庄', 'Asia/Shanghai', '中国'),
  CityInfo('太原', 'Asia/Shanghai', '中国'),
  CityInfo('沈阳', 'Asia/Shanghai', '中国'),
  CityInfo('大连', 'Asia/Shanghai', '中国'),
  CityInfo('长春', 'Asia/Shanghai', '中国'),
  CityInfo('哈尔滨', 'Asia/Shanghai', '中国'),
  CityInfo('南宁', 'Asia/Shanghai', '中国'),
  CityInfo('海口', 'Asia/Shanghai', '中国'),
  CityInfo('贵阳', 'Asia/Shanghai', '中国'),
  CityInfo('昆明', 'Asia/Shanghai', '中国'),
  CityInfo('拉萨', 'Asia/Shanghai', '中国'),
  CityInfo('兰州', 'Asia/Shanghai', '中国'),
  CityInfo('西宁', 'Asia/Shanghai', '中国'),
  CityInfo('银川', 'Asia/Shanghai', '中国'),
  CityInfo('乌鲁木齐', 'Asia/Shanghai', '中国'),
  CityInfo('呼和浩特', 'Asia/Shanghai', '中国'),
  CityInfo('香港', 'Asia/Hong_Kong', '中国'),
  CityInfo('澳门', 'Asia/Macau', '中国'),
  CityInfo('台北', 'Asia/Taipei', '中国'),

  // ---- 亚洲 ----
  CityInfo('东京', 'Asia/Tokyo', '日本'),
  CityInfo('首尔', 'Asia/Seoul', '韩国'),
  CityInfo('新加坡', 'Asia/Singapore', '新加坡'),
  CityInfo('曼谷', 'Asia/Bangkok', '泰国'),
  CityInfo('吉隆坡', 'Asia/Kuala_Lumpur', '马来西亚'),
  CityInfo('雅加达', 'Asia/Jakarta', '印尼'),
  CityInfo('马尼拉', 'Asia/Manila', '菲律宾'),
  CityInfo('胡志明市', 'Asia/Ho_Chi_Minh', '越南'),
  CityInfo('河内', 'Asia/Ho_Chi_Minh', '越南'),
  CityInfo('新德里', 'Asia/Kolkata', '印度'),
  CityInfo('孟买', 'Asia/Kolkata', '印度'),
  CityInfo('迪拜', 'Asia/Dubai', '阿联酋'),
  CityInfo('特拉维夫', 'Asia/Jerusalem', '以色列'),
  CityInfo('伊斯坦布尔', 'Europe/Istanbul', '土耳其'),

  // ---- 欧洲 ----
  CityInfo('莫斯科', 'Europe/Moscow', '俄罗斯'),
  CityInfo('伦敦', 'Europe/London', '英国'),
  CityInfo('巴黎', 'Europe/Paris', '法国'),
  CityInfo('柏林', 'Europe/Berlin', '德国'),
  CityInfo('阿姆斯特丹', 'Europe/Amsterdam', '荷兰'),
  CityInfo('苏黎世', 'Europe/Zurich', '瑞士'),
  CityInfo('罗马', 'Europe/Rome', '意大利'),
  CityInfo('马德里', 'Europe/Madrid', '西班牙'),
  CityInfo('斯德哥尔摩', 'Europe/Stockholm', '瑞典'),
  CityInfo('赫尔辛基', 'Europe/Helsinki', '芬兰'),
  CityInfo('哥本哈根', 'Europe/Copenhagen', '丹麦'),

  // ---- 美洲 ----
  CityInfo('纽约', 'America/New_York', '美国'),
  CityInfo('华盛顿', 'America/New_York', '美国'),
  CityInfo('芝加哥', 'America/Chicago', '美国'),
  CityInfo('洛杉矶', 'America/Los_Angeles', '美国'),
  CityInfo('旧金山', 'America/Los_Angeles', '美国'),
  CityInfo('西雅图', 'America/Los_Angeles', '美国'),
  CityInfo('檀香山', 'Pacific/Honolulu', '美国'),
  CityInfo('多伦多', 'America/Toronto', '加拿大'),
  CityInfo('温哥华', 'America/Vancouver', '加拿大'),
  CityInfo('墨西哥城', 'America/Mexico_City', '墨西哥'),
  CityInfo('圣保罗', 'America/Sao_Paulo', '巴西'),
  CityInfo('布宜诺斯艾利斯', 'America/Argentina/Buenos_Aires', '阿根廷'),

  // ---- 大洋洲 / 非洲 ----
  CityInfo('悉尼', 'Australia/Sydney', '澳大利亚'),
  CityInfo('墨尔本', 'Australia/Sydney', '澳大利亚'),
  CityInfo('珀斯', 'Australia/Perth', '澳大利亚'),
  CityInfo('奥克兰', 'Pacific/Auckland', '新西兰'),
  CityInfo('开罗', 'Africa/Cairo', '埃及'),
  CityInfo('约翰内斯堡', 'Africa/Johannesburg', '南非'),
  CityInfo('内罗毕', 'Africa/Nairobi', '肯尼亚'),
  CityInfo('拉各斯', 'Africa/Lagos', '尼日利亚'),
];

/// 按 IANA 标识反查城市；查不到返回默认城市，让调用方少一层 null 判断。
CityInfo cityByLocation(String location) {
  for (final c in kCities) {
    if (c.location == location) return c;
  }
  return kDefaultCity;
}

/// 按关键词筛城市。中英文都试一下：城市名是中文，但位置标识是英文，
/// 搜 `asia` 能把亚洲的都捞出来。
List<CityInfo> searchCities(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCities;
  return [
    for (final c in kCities)
      if (c.name.toLowerCase().contains(q) ||
          c.location.toLowerCase().contains(q) ||
          c.region.toLowerCase().contains(q))
        c,
  ];
}

/// 取某城市的当前时间。时区库没就绪时退回本机时间，页面照常显示。
///
/// 注意返回值始终是 `TZDateTime`，调用方按 [DateTime] 用即可，
/// 但取 `.timeZoneOffset` 才是**该城市**的偏移，本机 `DateTime.timeZoneOffset`
/// 拿到的是设备所在时区，两者不能混。
DateTime nowIn(CityInfo city) {
  if (!timezonesReady) return DateTime.now();
  try {
    return tz.TZDateTime.now(tz.getLocation(city.location));
  } catch (_) {
    return DateTime.now();
  }
}

/// 把偏移格式化成 `UTC+8` / `UTC-5` / `UTC+5:30`。
///
/// 半时区（印度、伊朗）必须带分钟，否则会显示成 UTC+5 少半小时。
String formatUtcOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final h = abs.inHours;
  final m = abs.inMinutes % 60;
  return m == 0 ? 'UTC$sign$h' : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
}
