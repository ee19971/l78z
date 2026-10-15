//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 应用级偏好——语言、字号、字体族（含外部目录自定义字体）、时区城市，以及驱动 MaterialApp 重建的模型。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 时区城市存的键；存 IANA 标识而不是城市名——名字可能改，标识不会。
///
/// 主页面时钟与设置页「时区城市」共用这一个键，两边改任何一边都同步生效。
const String kCityLocation = 'main_city_location';

/// 主题用的字体族名，与 pubspec `fonts:` 段声明保持一致。
const String kFontFamilySans = 'NotoSansSC';

const String kFontFamilySerif = 'NotoSerifSC';

/// 霞鹜文楷 GB——中英文默认字体，与 pubspec `fonts:` 段声明保持一致。
const String kFontFamilyWenKai = 'LXGWWenKaiGB';

/// 自定义字体（用户从其他目录选的 ttf/otf）注册进 Flutter 后用的族名。
///
/// 字体文件本身不进包，启动时按 [AppSettingsModel.customFontPath] 从原路径
/// 读入注册；文件丢失时 [AppSettingsModel.customFontLoaded] 保持 false，
/// [AppSettingsModel.effectiveFontFamily] 回落系统默认。
const String kFontFamilyCustom = 'CustomFont';

/// 全部可选项的展示顺序；设置页弹窗按此生成。
const List<String> kFontFamilyOptions = [
  'system',
  kFontFamilyWenKai,
  kFontFamilySans,
  kFontFamilySerif,
  kFontFamilyCustom,
];

/// 主题色板：中国传统色，一色一名。
///
/// 值做 Material3 的 seed，由 [ColorScheme.fromSeed] 派生整套配色；
/// id 同时是 prefs 存的值，所以**只增不改**——改了老用户的设置会失联。
const Map<String, Color> kThemeColors = {
  'zhusha': Color(0xFFE34234), // 朱砂
  'yanzhi': Color(0xFF9D2933), // 胭脂
  'dailan': Color(0xFF425066), // 黛蓝
  'shiqing': Color(0xFF1685A9), // 石青
  'zhuqing': Color(0xFF789262), // 竹青
  'xiangse': Color(0xFFF0C239), // 缃色
};

/// 默认主题色：朱砂。
const String kThemeColorDefault = 'zhusha';

/// 主题色的显示名，与 [kThemeColors] 同序；i18n 见 l10n 的 setTheme* 系列。

/// 应用级设置模型：改任何一项都会写 prefs 并通知 [MaterialApp] 重建。
///
/// 单例而非 Provider/InheritedWidget：设置只有「读一次 + 偶尔改一项」，
/// 一个 ChangeNotifier 够用，也和秒表模型的单例风格一致。
class AppSettingsModel extends ChangeNotifier {
  AppSettingsModel._();

  static final AppSettingsModel instance = AppSettingsModel._();

  /// 语言。null = 跟随系统（Flutter 按 supportedLocales 自动匹配）。
  Locale? locale;

  /// 全局字号缩放，1.0 为系统默认。
  double fontScale = 1.0;

  /// 字体族：[kFontFamilySans] / [kFontFamilySerif] / [kFontFamilyWenKai] /
  /// [kFontFamilyCustom] / 'system' = 系统默认。
  ///
  /// 默认是霞鹜文楷——中英文界面统一的手写风默认字体。
  String fontFamily = kFontFamilyWenKai;

  /// 自定义字体文件的绝对路径；null = 没设过。
  String? customFontPath;

  /// 自定义字体是否成功注册。文件被移动/删除后为 false，界面回退系统默认。
  bool customFontLoaded = false;

  /// 主题色 id，取值见 [kThemeColors]；非法值一律回落朱砂。
  String themeColorId = kThemeColorDefault;

  static const String _kLocale = 'app_locale';
  static const String _kFontScale = 'app_font_scale';
  static const String _kFontFamily = 'app_font_family';
  static const String _kCustomFontPath = 'app_custom_font_path';
  static const String _kThemeColor = 'app_theme_color';

  /// 启动时读一次 prefs；没设过的项保持默认值（跟随系统/1.0/霞鹜文楷/朱砂）。
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kLocale);
    locale = switch (raw) {
      'zh_CN' => const Locale('zh', 'CN'),
      'en' => const Locale('en'),
      _ => null,
    };
    fontScale = sp.getDouble(_kFontScale) ?? 1.0;
    fontFamily = sp.getString(_kFontFamily) ?? kFontFamilyWenKai;
    customFontPath = sp.getString(_kCustomFontPath);
    customFontLoaded = false;
    final colorId = sp.getString(_kThemeColor);
    themeColorId =
        kThemeColors.containsKey(colorId) ? colorId! : kThemeColorDefault;
    notifyListeners();
    // 通知后再注册字体：注册是 IO，慢盘上不该拖住 MaterialApp 首帧；
    // 注册完成会再通知一次，主题用新族名重建。
    if (fontFamily == kFontFamilyCustom) await _registerCustomFont();
  }

  /// 设语言；传 null 表示跟随系统。
  Future<void> setLocale(Locale? value) async {
    locale = value;
    final sp = await SharedPreferences.getInstance();
    if (value == null) {
      await sp.remove(_kLocale);
    } else if (value.countryCode == 'CN') {
      await sp.setString(_kLocale, 'zh_CN');
    } else {
      await sp.setString(_kLocale, value.languageCode);
    }
    notifyListeners();
  }

  /// 设字号缩放，范围夹在 0.85–1.4，防手滑拖出离谱值。
  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(0.85, 1.4);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kFontScale, fontScale);
    notifyListeners();
  }

  /// 设字体族；传 'system' 表示系统默认，传 [kFontFamilyCustom] 会顺带
  /// 重新注册自定义字体文件（换过文件后切回来也能立刻生效）。
  Future<void> setFontFamily(String value) async {
    fontFamily = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFontFamily, value);
    notifyListeners();
    if (value == kFontFamilyCustom) await _registerCustomFont();
  }

  /// 设自定义字体文件路径并立即注册；顺带把当前字体族切到
  /// [kFontFamilyCustom]——用户选文件就是为了用它。
  ///
  /// 只记原路径不复制文件：文件被移动后自动回退系统默认（见
  /// [customFontLoaded]），想换文件时重选一次即可覆盖。
  Future<void> setCustomFontPath(String path) async {
    customFontPath = path;
    fontFamily = kFontFamilyCustom;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCustomFontPath, path);
    await sp.setString(_kFontFamily, kFontFamilyCustom);
    notifyListeners();
    await _registerCustomFont();
  }

  /// 清掉自定义字体，回到系统默认。
  Future<void> clearCustomFontPath() async {
    customFontPath = null;
    customFontLoaded = false;
    fontFamily = 'system';
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kCustomFontPath);
    await sp.setString(_kFontFamily, 'system');
    notifyListeners();
  }

  /// 从 [customFontPath] 读入字体文件注册为 [kFontFamilyCustom]。
  ///
  /// 文件缺失/读失败不算错误：置 [customFontLoaded] = false 让主题回退，
  /// 不弹窗不崩溃——路径是用户自己记的，文件随时可能被挪走。
  Future<void> _registerCustomFont() async {
    final path = customFontPath;
    if (path == null || path.isEmpty) {
      customFontLoaded = false;
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader(kFontFamilyCustom)
        ..addFont(Future<ByteData>.value(
            ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length)));
      await loader.load();
      customFontLoaded = true;
    } catch (_) {
      customFontLoaded = false;
    }
    notifyListeners();
  }

  /// 设主题色；id 不在色板里则忽略（防脏数据）。
  Future<void> setThemeColor(String id) async {
    if (!kThemeColors.containsKey(id)) return;
    themeColorId = id;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kThemeColor, id);
    notifyListeners();
  }

  /// 当前主题色；未知 id 回落朱砂。
  Color get themeColor => kThemeColors[themeColorId] ?? kThemeColors[kThemeColorDefault]!;

  /// 当前生效的字体族名；系统默认（或自定义字体加载失败）时返回 null，
  /// 让主题不传 fontFamily，交给平台自己的默认字体。
  String? get effectiveFontFamily => switch (fontFamily) {
        kFontFamilySans || kFontFamilySerif || kFontFamilyWenKai => fontFamily,
        kFontFamilyCustom => customFontLoaded ? kFontFamilyCustom : null,
        _ => null,
      };
}
