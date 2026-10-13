//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 精选国家首都表与时区库初始化——主页面时钟的时间来源。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 国家首都：首都名、IANA 时区标识、国家名。
class CityInfo {
  const CityInfo(this.name, this.location, this.region);

  /// 首都中文名，搜索就搜这个。
  final String name;

  /// IANA 标识，如 `Asia/Shanghai`。时区库据此查夏令时规则。
  final String location;

  /// 所属国家名，列表里用作副标题，也是搜索维度之一。
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
/// 数据覆盖未来 10 年的夏令时规则，对一个首都选择器绰绰有余；
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

/// 默认首都：北京。
///
/// 不引 `flutter_native_timezone` 去取本机时区名——那个插件 Windows 上
/// 没有实现，而我们有 msix 产物，为省一次手动切换拉一个跨平台不全的
/// 原生依赖不划算。用户点一下首都名就能换。
const CityInfo kDefaultCity = CityInfo('北京', 'Asia/Shanghai', '中国');

/// 按大洲分组的首都表：键顺序即列表顺序，共 73 个国家/地区。
///
/// 精选主要国家而非全量联合国会员国：列表太长反而难翻，搜索才是主路径。
/// 中国只列北京——大陆全国单一时区，选北京与选上海得到的时间完全相同，
/// 再列省会只是重复同一条时间；港澳台同为 UTC+8 且无夏令时，北京已覆盖。
///
/// 少数「首都名 ≠ 时区城名」的条目（如比勒陀利亚挂 Africa/Johannesburg、
/// 巴西利亚挂 America/Sao_Paulo）是 IANA 的历史命名，以官方时区库为准。
const Map<String, List<CityInfo>> kContinentCities = {
  '亚洲': [
    CityInfo('北京', 'Asia/Shanghai', '中国'),
    CityInfo('东京', 'Asia/Tokyo', '日本'),
    CityInfo('首尔', 'Asia/Seoul', '韩国'),
    CityInfo('平壤', 'Asia/Pyongyang', '朝鲜'),
    CityInfo('乌兰巴托', 'Asia/Ulaanbaatar', '蒙古'),
    CityInfo('新德里', 'Asia/Kolkata', '印度'),
    CityInfo('伊斯兰堡', 'Asia/Karachi', '巴基斯坦'),
    CityInfo('达卡', 'Asia/Dhaka', '孟加拉国'),
    CityInfo('曼谷', 'Asia/Bangkok', '泰国'),
    CityInfo('河内', 'Asia/Ho_Chi_Minh', '越南'),
    CityInfo('雅加达', 'Asia/Jakarta', '印度尼西亚'),
    CityInfo('马尼拉', 'Asia/Manila', '菲律宾'),
    CityInfo('吉隆坡', 'Asia/Kuala_Lumpur', '马来西亚'),
    CityInfo('新加坡', 'Asia/Singapore', '新加坡'),
    CityInfo('德黑兰', 'Asia/Tehran', '伊朗'),
    CityInfo('利雅得', 'Asia/Riyadh', '沙特阿拉伯'),
    CityInfo('阿布扎比', 'Asia/Dubai', '阿联酋'),
    CityInfo('安卡拉', 'Europe/Istanbul', '土耳其'),
    CityInfo('特拉维夫', 'Asia/Jerusalem', '以色列'),
  ],
  '欧洲': [
    CityInfo('伦敦', 'Europe/London', '英国'),
    CityInfo('巴黎', 'Europe/Paris', '法国'),
    CityInfo('柏林', 'Europe/Berlin', '德国'),
    CityInfo('罗马', 'Europe/Rome', '意大利'),
    CityInfo('马德里', 'Europe/Madrid', '西班牙'),
    CityInfo('里斯本', 'Europe/Lisbon', '葡萄牙'),
    CityInfo('阿姆斯特丹', 'Europe/Amsterdam', '荷兰'),
    CityInfo('布鲁塞尔', 'Europe/Brussels', '比利时'),
    CityInfo('维也纳', 'Europe/Vienna', '奥地利'),
    CityInfo('伯尔尼', 'Europe/Zurich', '瑞士'),
    CityInfo('布拉格', 'Europe/Prague', '捷克'),
    CityInfo('华沙', 'Europe/Warsaw', '波兰'),
    CityInfo('布达佩斯', 'Europe/Budapest', '匈牙利'),
    CityInfo('布加勒斯特', 'Europe/Bucharest', '罗马尼亚'),
    CityInfo('雅典', 'Europe/Athens', '希腊'),
    CityInfo('基辅', 'Europe/Kyiv', '乌克兰'),
    CityInfo('莫斯科', 'Europe/Moscow', '俄罗斯'),
    CityInfo('斯德哥尔摩', 'Europe/Stockholm', '瑞典'),
    CityInfo('奥斯陆', 'Europe/Oslo', '挪威'),
    CityInfo('赫尔辛基', 'Europe/Helsinki', '芬兰'),
    CityInfo('哥本哈根', 'Europe/Copenhagen', '丹麦'),
    CityInfo('都柏林', 'Europe/Dublin', '爱尔兰'),
  ],
  '非洲': [
    CityInfo('开罗', 'Africa/Cairo', '埃及'),
    CityInfo('比勒陀利亚', 'Africa/Johannesburg', '南非'),
    CityInfo('阿布贾', 'Africa/Lagos', '尼日利亚'),
    CityInfo('内罗毕', 'Africa/Nairobi', '肯尼亚'),
    CityInfo('亚的斯亚贝巴', 'Africa/Addis_Ababa', '埃塞俄比亚'),
    CityInfo('阿克拉', 'Africa/Accra', '加纳'),
    CityInfo('达喀尔', 'Africa/Dakar', '塞内加尔'),
    CityInfo('金沙萨', 'Africa/Kinshasa', '刚果（金）'),
    CityInfo('罗安达', 'Africa/Luanda', '安哥拉'),
    CityInfo('哈拉雷', 'Africa/Harare', '津巴布韦'),
    CityInfo('多多马', 'Africa/Dar_es_Salaam', '坦桑尼亚'),
    CityInfo('拉巴特', 'Africa/Casablanca', '摩洛哥'),
  ],
  '美洲': [
    CityInfo('华盛顿', 'America/New_York', '美国'),
    CityInfo('渥太华', 'America/Toronto', '加拿大'),
    CityInfo('墨西哥城', 'America/Mexico_City', '墨西哥'),
    CityInfo('哈瓦那', 'America/Havana', '古巴'),
    CityInfo('危地马拉城', 'America/Guatemala', '危地马拉'),
    CityInfo('巴拿马城', 'America/Panama', '巴拿马'),
    CityInfo('波哥大', 'America/Bogota', '哥伦比亚'),
    CityInfo('加拉加斯', 'America/Caracas', '委内瑞拉'),
    CityInfo('利马', 'America/Lima', '秘鲁'),
    CityInfo('圣地亚哥', 'America/Santiago', '智利'),
    CityInfo('布宜诺斯艾利斯', 'America/Argentina/Buenos_Aires', '阿根廷'),
    CityInfo('巴西利亚', 'America/Sao_Paulo', '巴西'),
    CityInfo('蒙得维的亚', 'America/Montevideo', '乌拉圭'),
    CityInfo('拉巴斯', 'America/La_Paz', '玻利维亚'),
    CityInfo('基多', 'America/Guayaquil', '厄瓜多尔'),
    CityInfo('亚松森', 'America/Asuncion', '巴拉圭'),
    CityInfo('金斯敦', 'America/Jamaica', '牙买加'),
  ],
  '大洋洲': [
    CityInfo('堪培拉', 'Australia/Sydney', '澳大利亚'),
    CityInfo('惠灵顿', 'Pacific/Auckland', '新西兰'),
    CityInfo('苏瓦', 'Pacific/Fiji', '斐济'),
  ],
};

/// 平铺的全部首都，供反查与测试使用。
///
/// 用 `final` 而非 `const`：它是从 [kContinentCities] 展平派生的，
/// 保持单一数据源，避免两份表各自演化后对不上。
final List<CityInfo> kCities = [
  for (final group in kContinentCities.values) ...group,
];

/// 按大洲分组筛首都：丢掉没有命中的组，保留组名与组内命中的条目。
///
/// 弹层直接按这个结果渲染「大洲标题 + 城市」，标题只在有命中时出现。
Map<String, List<CityInfo>> searchCitiesGrouped(String query) {
  final q = query.trim().toLowerCase();
  bool match(CityInfo c) => q.isEmpty ||
      c.name.toLowerCase().contains(q) ||
      c.location.toLowerCase().contains(q) ||
      c.region.toLowerCase().contains(q);

  return {
    for (final entry in kContinentCities.entries)
      if (entry.value.any(match))
        entry.key: [
          for (final c in entry.value)
            if (match(c)) c,
        ],
  };
}

/// 按关键词平铺筛首都。中英文都试：首都名是中文，但位置标识是英文，
/// 搜 `asia` 能把亚洲的都捞出来。
List<CityInfo> searchCities(String query) => [
      for (final group in searchCitiesGrouped(query).values) ...group,
    ];

/// 按 IANA 标识反查首都；查不到返回默认首都，让调用方少一层 null 判断。
CityInfo cityByLocation(String location) {
  for (final c in kCities) {
    if (c.location == location) return c;
  }
  return kDefaultCity;
}

/// 取某首都的当前时间。时区库没就绪时退回本机时间，页面照常显示。
///
/// 返回值里的偏移是**该首都**的偏移；本机 `DateTime.timeZoneOffset`
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
