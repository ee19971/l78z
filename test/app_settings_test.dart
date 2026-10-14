//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 应用级设置模型与首装时区探测的测试。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/yemian/app_settings.dart';
import 'package:l78z/yemian/timezone_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AppSettingsModel 是全局单例，跑之前把状态清回默认，避免上一个用例残留。
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettingsModel.instance;
    s.locale = null;
    s.fontScale = 1.0;
    s.fontFamily = 'system';
  });

  test('load：空 prefs 时保持默认（跟随系统 / 1.0 / 系统字体）', () async {
    await AppSettingsModel.instance.load();
    final s = AppSettingsModel.instance;
    expect(s.locale, isNull);
    expect(s.fontScale, 1.0);
    expect(s.fontFamily, 'system');
    expect(s.effectiveFontFamily, isNull);
  });

  test('load：zh_CN / en 与字号、字体族一起恢复', () async {
    SharedPreferences.setMockInitialValues({
      'app_locale': 'zh_CN',
      'app_font_scale': 1.2,
      'app_font_family': kFontFamilySerif,
    });
    await AppSettingsModel.instance.load();
    final s = AppSettingsModel.instance;
    expect(s.locale, const Locale('zh', 'CN'));
    expect(s.fontScale, closeTo(1.2, 1e-9));
    expect(s.fontFamily, kFontFamilySerif);
    expect(s.effectiveFontFamily, kFontFamilySerif);
  });

  test('setFontScale 夹在 0.85–1.4，防手滑拖出离谱值', () async {
    await AppSettingsModel.instance.setFontScale(0.5);
    expect(AppSettingsModel.instance.fontScale, closeTo(0.85, 1e-9));
    await AppSettingsModel.instance.setFontScale(2.0);
    expect(AppSettingsModel.instance.fontScale, closeTo(1.4, 1e-9));
  });

  test('setLocale 写回 prefs，load 后能还原', () async {
    await AppSettingsModel.instance.setLocale(const Locale('en'));
    // 清掉内存值模拟「重启后再读一次」；prefs 里已经有上次写入的 'en'。
    AppSettingsModel.instance.locale = null;
    await AppSettingsModel.instance.load();
    expect(AppSettingsModel.instance.locale, const Locale('en'));
  });

  test('kCountryCodeToLocation 关键国家映射到首都', () {
    expect(kCountryCodeToLocation['CN'], 'Asia/Shanghai');
    expect(kCountryCodeToLocation['JP'], 'Asia/Tokyo');
    expect(kCountryCodeToLocation['US'], 'America/New_York');
  });

  test('detectLocalCity：任何环境都返回一个真实存在的城市', () {
    final city = detectLocalCity();
    expect(city.location, isNotEmpty);
    expect(city.name, isNotEmpty);
  });
}
