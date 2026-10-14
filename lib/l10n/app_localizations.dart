import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @tabFestivals.
  ///
  /// In zh, this message translates to:
  /// **'节日节气'**
  String get tabFestivals;

  /// No description provided for @tabCalculator.
  ///
  /// In zh, this message translates to:
  /// **'日期计算'**
  String get tabCalculator;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'主页面'**
  String get tabHome;

  /// No description provided for @tabTools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get tabTools;

  /// No description provided for @tabCountdown.
  ///
  /// In zh, this message translates to:
  /// **'倒数日'**
  String get tabCountdown;

  /// No description provided for @tabCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get tabCalendar;

  /// No description provided for @appInitFailed.
  ///
  /// In zh, this message translates to:
  /// **'初始化失败: {error}\n请检查浏览器控制台或查看是否缺少 COOP/COEP 请求头'**
  String appInitFailed(String error);

  /// No description provided for @pickerSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索国家或首都，如 日本、巴黎、asia'**
  String get pickerSearchHint;

  /// No description provided for @pickerNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配「{query}」的国家或首都'**
  String pickerNoMatch(String query);

  /// No description provided for @setRegionTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言与地区'**
  String get setRegionTitle;

  /// No description provided for @setDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get setDisplayTitle;

  /// No description provided for @setLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get setLanguage;

  /// No description provided for @setFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get setFollowSystem;

  /// No description provided for @setLanguageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get setLanguageZh;

  /// No description provided for @setLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get setLanguageEn;

  /// No description provided for @setTimeZoneCity.
  ///
  /// In zh, this message translates to:
  /// **'时区城市'**
  String get setTimeZoneCity;

  /// No description provided for @setAutoDetect.
  ///
  /// In zh, this message translates to:
  /// **'自动检测'**
  String get setAutoDetect;

  /// No description provided for @setFont.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get setFont;

  /// No description provided for @setFontSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get setFontSystem;

  /// No description provided for @setFontSans.
  ///
  /// In zh, this message translates to:
  /// **'思源黑体'**
  String get setFontSans;

  /// No description provided for @setFontSerif.
  ///
  /// In zh, this message translates to:
  /// **'思源宋体'**
  String get setFontSerif;

  /// No description provided for @setFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字号  {percent}%'**
  String setFontSize(int percent);

  /// No description provided for @setFontPreview.
  ///
  /// In zh, this message translates to:
  /// **'永 Aa 互传助手 2026 — the quick brown fox'**
  String get setFontPreview;

  /// No description provided for @mainTitle.
  ///
  /// In zh, this message translates to:
  /// **'主页面'**
  String get mainTitle;

  /// No description provided for @mainOcr.
  ///
  /// In zh, this message translates to:
  /// **'OCR 识别'**
  String get mainOcr;

  /// No description provided for @mainQrScan.
  ///
  /// In zh, this message translates to:
  /// **'二维码扫描'**
  String get mainQrScan;

  /// No description provided for @mainStopwatch.
  ///
  /// In zh, this message translates to:
  /// **'秒表'**
  String get mainStopwatch;

  /// No description provided for @mainOnThisDay.
  ///
  /// In zh, this message translates to:
  /// **'历史上的今天'**
  String get mainOnThisDay;

  /// No description provided for @mainTzNotReady.
  ///
  /// In zh, this message translates to:
  /// **'时区库未就绪'**
  String get mainTzNotReady;

  /// No description provided for @mainToday.
  ///
  /// In zh, this message translates to:
  /// **'就在今天'**
  String get mainToday;

  /// No description provided for @mainTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get mainTomorrow;

  /// No description provided for @mainInDays.
  ///
  /// In zh, this message translates to:
  /// **'还有 {days} 天'**
  String mainInDays(int days);

  /// No description provided for @mainTodayTitle.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get mainTodayTitle;

  /// No description provided for @mainSolar.
  ///
  /// In zh, this message translates to:
  /// **'公历'**
  String get mainSolar;

  /// No description provided for @mainLunar.
  ///
  /// In zh, this message translates to:
  /// **'农历'**
  String get mainLunar;

  /// No description provided for @mainGanZhi.
  ///
  /// In zh, this message translates to:
  /// **'干支'**
  String get mainGanZhi;

  /// No description provided for @mainZodiac.
  ///
  /// In zh, this message translates to:
  /// **'生肖'**
  String get mainZodiac;

  /// No description provided for @mainJieQi.
  ///
  /// In zh, this message translates to:
  /// **'节气'**
  String get mainJieQi;

  /// No description provided for @mainNextFestival.
  ///
  /// In zh, this message translates to:
  /// **'下一个：{name}'**
  String mainNextFestival(String name);

  /// No description provided for @toolsTitle.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get toolsTitle;

  /// No description provided for @toolsScan.
  ///
  /// In zh, this message translates to:
  /// **'扫一扫'**
  String get toolsScan;

  /// No description provided for @toolsScanSub.
  ///
  /// In zh, this message translates to:
  /// **'扫码 / 选图解码 / 图片 OCR'**
  String get toolsScanSub;

  /// No description provided for @toolsQr.
  ///
  /// In zh, this message translates to:
  /// **'二维码 / 条形码'**
  String get toolsQr;

  /// No description provided for @toolsQrSub.
  ///
  /// In zh, this message translates to:
  /// **'14 种格式，支持 WiFi、名片等模板'**
  String get toolsQrSub;

  /// No description provided for @toolsLan.
  ///
  /// In zh, this message translates to:
  /// **'局域网传输'**
  String get toolsLan;

  /// No description provided for @toolsLanSub.
  ///
  /// In zh, this message translates to:
  /// **'手机与电脑互传文本与文件'**
  String get toolsLanSub;

  /// No description provided for @toolsSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get toolsSettings;

  /// No description provided for @setThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get setThemeColor;

  /// No description provided for @setThemeZhusha.
  ///
  /// In zh, this message translates to:
  /// **'朱砂'**
  String get setThemeZhusha;

  /// No description provided for @setThemeYanzhi.
  ///
  /// In zh, this message translates to:
  /// **'胭脂'**
  String get setThemeYanzhi;

  /// No description provided for @setThemeDailan.
  ///
  /// In zh, this message translates to:
  /// **'黛蓝'**
  String get setThemeDailan;

  /// No description provided for @setThemeShiqing.
  ///
  /// In zh, this message translates to:
  /// **'石青'**
  String get setThemeShiqing;

  /// No description provided for @setThemeZhuqing.
  ///
  /// In zh, this message translates to:
  /// **'竹青'**
  String get setThemeZhuqing;

  /// No description provided for @setThemeXiangse.
  ///
  /// In zh, this message translates to:
  /// **'缃色'**
  String get setThemeXiangse;

  /// No description provided for @otdLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'数据加载失败：{error}'**
  String otdLoadFailed(String error);

  /// No description provided for @otdEvents.
  ///
  /// In zh, this message translates to:
  /// **'大事记'**
  String get otdEvents;

  /// No description provided for @otdBirths.
  ///
  /// In zh, this message translates to:
  /// **'今天出生'**
  String get otdBirths;

  /// No description provided for @otdDeaths.
  ///
  /// In zh, this message translates to:
  /// **'今天逝世'**
  String get otdDeaths;

  /// No description provided for @otdCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 条'**
  String otdCount(int n);

  /// No description provided for @otdSummary.
  ///
  /// In zh, this message translates to:
  /// **'大事 {events} · 诞生 {births} · 逝世 {deaths}'**
  String otdSummary(int events, int births, int deaths);

  /// No description provided for @otdEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这一天暂无收录的条目'**
  String get otdEmpty;

  /// No description provided for @otdNoData.
  ///
  /// In zh, this message translates to:
  /// **'本日暂无数据'**
  String get otdNoData;

  /// No description provided for @swTitle.
  ///
  /// In zh, this message translates to:
  /// **'秒表'**
  String get swTitle;

  /// No description provided for @swStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get swStart;

  /// No description provided for @swPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get swPause;

  /// No description provided for @swResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get swResume;

  /// No description provided for @swReset.
  ///
  /// In zh, this message translates to:
  /// **'复位'**
  String get swReset;

  /// No description provided for @swLap.
  ///
  /// In zh, this message translates to:
  /// **'计次'**
  String get swLap;

  /// No description provided for @swHint.
  ///
  /// In zh, this message translates to:
  /// **'计时中点「计次」开始计圈'**
  String get swHint;

  /// No description provided for @swLapN.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 圈'**
  String swLapN(int n);

  /// No description provided for @swTotal.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get swTotal;

  /// No description provided for @calcTitle.
  ///
  /// In zh, this message translates to:
  /// **'日期计算'**
  String get calcTitle;

  /// No description provided for @calcTabProject.
  ///
  /// In zh, this message translates to:
  /// **'日期推算'**
  String get calcTabProject;

  /// No description provided for @calcTabDiff.
  ///
  /// In zh, this message translates to:
  /// **'日期间隔'**
  String get calcTabDiff;

  /// No description provided for @calcTabTime.
  ///
  /// In zh, this message translates to:
  /// **'时间推算'**
  String get calcTabTime;

  /// No description provided for @calcDaysLabel.
  ///
  /// In zh, this message translates to:
  /// **'相差的日子'**
  String get calcDaysLabel;

  /// No description provided for @calcUnitDays.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get calcUnitDays;

  /// No description provided for @calcHintNegative.
  ///
  /// In zh, this message translates to:
  /// **'可为负数'**
  String get calcHintNegative;

  /// No description provided for @calcResult.
  ///
  /// In zh, this message translates to:
  /// **'推算结果'**
  String get calcResult;

  /// No description provided for @calcNDays.
  ///
  /// In zh, this message translates to:
  /// **'{n} 天'**
  String calcNDays(int n);

  /// No description provided for @calcLater.
  ///
  /// In zh, this message translates to:
  /// **'终点比起点晚 {n} 天'**
  String calcLater(int n);

  /// No description provided for @calcEarlier.
  ///
  /// In zh, this message translates to:
  /// **'终点比起点早 {n} 天'**
  String calcEarlier(int n);

  /// No description provided for @calcHoursLabel.
  ///
  /// In zh, this message translates to:
  /// **'相差的小时'**
  String get calcHoursLabel;

  /// No description provided for @calcUnitHours.
  ///
  /// In zh, this message translates to:
  /// **'时'**
  String get calcUnitHours;

  /// No description provided for @calcMinutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'相差的分钟'**
  String get calcMinutesLabel;

  /// No description provided for @calcUnitMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get calcUnitMinutes;

  /// No description provided for @calcLunar.
  ///
  /// In zh, this message translates to:
  /// **'农历'**
  String get calcLunar;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get commonRefresh;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @cdTitle.
  ///
  /// In zh, this message translates to:
  /// **'倒数日'**
  String get cdTitle;

  /// No description provided for @cdAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加倒数日'**
  String get cdAdd;

  /// No description provided for @cdEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑倒数日'**
  String get cdEditTitle;

  /// No description provided for @cdOpFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String cdOpFailed(String error);

  /// No description provided for @cdSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String cdSaveFailed(String error);

  /// No description provided for @cdLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取失败:{error}'**
  String cdLoadFailed(String error);

  /// No description provided for @cdDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{title}」'**
  String cdDeleteTitle(String title);

  /// No description provided for @cdDeleteMsg.
  ///
  /// In zh, this message translates to:
  /// **'删除后无法恢复。'**
  String get cdDeleteMsg;

  /// No description provided for @commonDayUnit.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get commonDayUnit;

  /// No description provided for @cdRemain.
  ///
  /// In zh, this message translates to:
  /// **'还剩'**
  String get cdRemain;

  /// No description provided for @cdPassed.
  ///
  /// In zh, this message translates to:
  /// **'已过'**
  String get cdPassed;

  /// No description provided for @cdHas.
  ///
  /// In zh, this message translates to:
  /// **'还有'**
  String get cdHas;

  /// No description provided for @cdUntilNext.
  ///
  /// In zh, this message translates to:
  /// **'距下次'**
  String get cdUntilNext;

  /// No description provided for @cdToday.
  ///
  /// In zh, this message translates to:
  /// **'就是今天'**
  String get cdToday;

  /// No description provided for @cdModeCountdown.
  ///
  /// In zh, this message translates to:
  /// **'倒数'**
  String get cdModeCountdown;

  /// No description provided for @cdModeCountup.
  ///
  /// In zh, this message translates to:
  /// **'正数'**
  String get cdModeCountup;

  /// No description provided for @cdModeYearly.
  ///
  /// In zh, this message translates to:
  /// **'每年'**
  String get cdModeYearly;

  /// No description provided for @cdModeCountdownFull.
  ///
  /// In zh, this message translates to:
  /// **'倒数：距离目标日还剩几天'**
  String get cdModeCountdownFull;

  /// No description provided for @cdModeCountupFull.
  ///
  /// In zh, this message translates to:
  /// **'正数：目标日已经过去几天'**
  String get cdModeCountupFull;

  /// No description provided for @cdModeYearlyFull.
  ///
  /// In zh, this message translates to:
  /// **'每年重复：生日、纪念日'**
  String get cdModeYearlyFull;

  /// No description provided for @cdTotal.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 个倒数日'**
  String cdTotal(int n);

  /// No description provided for @cdEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有倒数日'**
  String get cdEmpty;

  /// No description provided for @cdEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'把重要的日子记下来，桌面部件会替你盯着'**
  String get cdEmptyHint;

  /// No description provided for @cdPin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get cdPin;

  /// No description provided for @cdUnpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get cdUnpin;

  /// No description provided for @cdPinHint.
  ///
  /// In zh, this message translates to:
  /// **'置顶的会排在最前，桌面部件也优先显示'**
  String get cdPinHint;

  /// No description provided for @cdPinSwitchHint.
  ///
  /// In zh, this message translates to:
  /// **'排在列表最前，桌面部件也优先显示'**
  String get cdPinSwitchHint;

  /// No description provided for @cdFieldTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get cdFieldTitle;

  /// No description provided for @cdFieldTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：考研初试、结婚纪念日'**
  String get cdFieldTitleHint;

  /// No description provided for @cdFieldTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标日期'**
  String get cdFieldTarget;

  /// No description provided for @cdFieldMode.
  ///
  /// In zh, this message translates to:
  /// **'计数方式'**
  String get cdFieldMode;

  /// No description provided for @cdFieldColor.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get cdFieldColor;

  /// No description provided for @cdFieldNote.
  ///
  /// In zh, this message translates to:
  /// **'备注（可选）'**
  String get cdFieldNote;

  /// No description provided for @cdErrTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写标题'**
  String get cdErrTitleRequired;

  /// No description provided for @cdQuote.
  ///
  /// In zh, this message translates to:
  /// **'「{text}」'**
  String cdQuote(String text);

  /// No description provided for @cdLifeTitle.
  ///
  /// In zh, this message translates to:
  /// **'人生进度'**
  String get cdLifeTitle;

  /// No description provided for @cdLifeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置出生日期后，这里和桌面部件都会显示进度'**
  String get cdLifeSubtitle;

  /// No description provided for @cdLifeEdit.
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get cdLifeEdit;

  /// No description provided for @cdLifePassed.
  ///
  /// In zh, this message translates to:
  /// **'已过 {pct}%'**
  String cdLifePassed(String pct);

  /// No description provided for @cdLifeLived.
  ///
  /// In zh, this message translates to:
  /// **'已活 {days} 天'**
  String cdLifeLived(int days);

  /// No description provided for @cdLifeRemaining.
  ///
  /// In zh, this message translates to:
  /// **'距 {age} 岁预期寿命还有 {days} 天'**
  String cdLifeRemaining(int age, int days);

  /// No description provided for @cdLifeSetupTitle.
  ///
  /// In zh, this message translates to:
  /// **'人生进度设置'**
  String get cdLifeSetupTitle;

  /// No description provided for @cdBirthday.
  ///
  /// In zh, this message translates to:
  /// **'出生日期'**
  String get cdBirthday;

  /// No description provided for @cdNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get cdNotSet;

  /// No description provided for @cdLifespanField.
  ///
  /// In zh, this message translates to:
  /// **'预期寿命（岁）'**
  String get cdLifespanField;

  /// No description provided for @cdLifespanHelp.
  ///
  /// In zh, this message translates to:
  /// **'用于折算总天数，随时可以改'**
  String get cdLifespanHelp;

  /// No description provided for @cdQuoteField.
  ///
  /// In zh, this message translates to:
  /// **'人生格言（可选）'**
  String get cdQuoteField;

  /// No description provided for @cdQuoteHelp.
  ///
  /// In zh, this message translates to:
  /// **'显示在进度卡片和桌面部件顶部'**
  String get cdQuoteHelp;

  /// No description provided for @cdDefaultQuote.
  ///
  /// In zh, this message translates to:
  /// **'今天不走，明天要跑。'**
  String get cdDefaultQuote;

  /// No description provided for @cdErrPickBirthday.
  ///
  /// In zh, this message translates to:
  /// **'请选择出生日期'**
  String get cdErrPickBirthday;

  /// No description provided for @cdErrLifespan.
  ///
  /// In zh, this message translates to:
  /// **'预期寿命需为正整数'**
  String get cdErrLifespan;

  /// No description provided for @cdClearLife.
  ///
  /// In zh, this message translates to:
  /// **'清除人生进度'**
  String get cdClearLife;

  /// No description provided for @commonToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get commonToday;

  /// No description provided for @festTitle.
  ///
  /// In zh, this message translates to:
  /// **'节日节气'**
  String get festTitle;

  /// No description provided for @festRemain.
  ///
  /// In zh, this message translates to:
  /// **'还有'**
  String get festRemain;

  /// No description provided for @festNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有叫「{query}」的节日或节气'**
  String festNoMatch(String query);

  /// No description provided for @festEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未来一年没有可显示的节日节气'**
  String get festEmpty;

  /// No description provided for @festHiddenNotice.
  ///
  /// In zh, this message translates to:
  /// **'有 {n} 个被隐藏了，可到设置里恢复'**
  String festHiddenNotice(int n);

  /// No description provided for @festSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get festSearch;

  /// No description provided for @festCloseSearch.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get festCloseSearch;

  /// No description provided for @festSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索节日或节气'**
  String get festSearchHint;

  /// No description provided for @festBadgeJieQi.
  ///
  /// In zh, this message translates to:
  /// **'节气'**
  String get festBadgeJieQi;

  /// No description provided for @festBadgeFestival.
  ///
  /// In zh, this message translates to:
  /// **'节日'**
  String get festBadgeFestival;

  /// No description provided for @festColorfulBg.
  ///
  /// In zh, this message translates to:
  /// **'显示彩色背景'**
  String get festColorfulBg;

  /// No description provided for @festColorfulBgSub.
  ///
  /// In zh, this message translates to:
  /// **'关闭后卡片改为素色'**
  String get festColorfulBgSub;

  /// No description provided for @festShowEmoji.
  ///
  /// In zh, this message translates to:
  /// **'显示表情'**
  String get festShowEmoji;

  /// No description provided for @festShowEmojiSub.
  ///
  /// In zh, this message translates to:
  /// **'在节日名称后追加一个 emoji'**
  String get festShowEmojiSub;

  /// No description provided for @festCoverColor.
  ///
  /// In zh, this message translates to:
  /// **'封面颜色'**
  String get festCoverColor;

  /// No description provided for @festCoverRotate.
  ///
  /// In zh, this message translates to:
  /// **'轮换'**
  String get festCoverRotate;

  /// No description provided for @festCoverRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机'**
  String get festCoverRandom;

  /// No description provided for @festCoverRotateSub.
  ///
  /// In zh, this message translates to:
  /// **'按列表顺序在八种颜色里循环'**
  String get festCoverRotateSub;

  /// No description provided for @festCoverRandomSub.
  ///
  /// In zh, this message translates to:
  /// **'每天打乱一次，同一天内保持不变'**
  String get festCoverRandomSub;

  /// No description provided for @festHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏的节日'**
  String get festHiddenTitle;

  /// No description provided for @festHiddenNone.
  ///
  /// In zh, this message translates to:
  /// **'当前没有隐藏任何节日'**
  String get festHiddenNone;

  /// No description provided for @festHiddenCount.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏 {n} 项'**
  String festHiddenCount(int n);

  /// No description provided for @festGroupVisible.
  ///
  /// In zh, this message translates to:
  /// **'可显示（{n}）'**
  String festGroupVisible(int n);

  /// No description provided for @festGroupHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏（{n}）'**
  String festGroupHidden(int n);

  /// No description provided for @calViewYear.
  ///
  /// In zh, this message translates to:
  /// **'年视图'**
  String get calViewYear;

  /// No description provided for @calViewMonth.
  ///
  /// In zh, this message translates to:
  /// **'月视图'**
  String get calViewMonth;

  /// No description provided for @calViewWeek.
  ///
  /// In zh, this message translates to:
  /// **'周视图'**
  String get calViewWeek;

  /// No description provided for @calViewDay.
  ///
  /// In zh, this message translates to:
  /// **'日视图'**
  String get calViewDay;

  /// No description provided for @calWeekHeader.
  ///
  /// In zh, this message translates to:
  /// **'日一二三四五六'**
  String get calWeekHeader;

  /// No description provided for @calYearTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year}年'**
  String calYearTitle(int year);

  /// No description provided for @calPrev.
  ///
  /// In zh, this message translates to:
  /// **'上一{tag}'**
  String calPrev(String tag);

  /// No description provided for @calNext.
  ///
  /// In zh, this message translates to:
  /// **'下一{tag}'**
  String calNext(String tag);

  /// No description provided for @calUnitYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get calUnitYear;

  /// No description provided for @calUnitMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get calUnitMonth;

  /// No description provided for @calUnitWeek.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get calUnitWeek;

  /// No description provided for @calUnitDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get calUnitDay;

  /// No description provided for @calMonthTitle.
  ///
  /// In zh, this message translates to:
  /// **'{month}月'**
  String calMonthTitle(String month);

  /// No description provided for @calDaysCount.
  ///
  /// In zh, this message translates to:
  /// **'{days}天'**
  String calDaysCount(int days);

  /// No description provided for @calFestival.
  ///
  /// In zh, this message translates to:
  /// **'节日'**
  String get calFestival;

  /// No description provided for @calDistance.
  ///
  /// In zh, this message translates to:
  /// **'距今'**
  String get calDistance;

  /// No description provided for @calPassedDays.
  ///
  /// In zh, this message translates to:
  /// **'已过 {days} 天'**
  String calPassedDays(int days);

  /// No description provided for @scanTitlePair.
  ///
  /// In zh, this message translates to:
  /// **'扫码配对'**
  String get scanTitlePair;

  /// No description provided for @scanTitleOcr.
  ///
  /// In zh, this message translates to:
  /// **'OCR 识别'**
  String get scanTitleOcr;

  /// No description provided for @scanTitleScan.
  ///
  /// In zh, this message translates to:
  /// **'扫一扫'**
  String get scanTitleScan;

  /// No description provided for @scanTakePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get scanTakePhoto;

  /// No description provided for @scanPickGallery.
  ///
  /// In zh, this message translates to:
  /// **'相册选图'**
  String get scanPickGallery;

  /// No description provided for @scanPickImage.
  ///
  /// In zh, this message translates to:
  /// **'选图'**
  String get scanPickImage;

  /// No description provided for @scanActionOcr.
  ///
  /// In zh, this message translates to:
  /// **'识别文字 OCR'**
  String get scanActionOcr;

  /// No description provided for @scanActionBarcode.
  ///
  /// In zh, this message translates to:
  /// **'扫二维码/条形码'**
  String get scanActionBarcode;

  /// No description provided for @scanStageRead.
  ///
  /// In zh, this message translates to:
  /// **'读取图片'**
  String get scanStageRead;

  /// No description provided for @scanStagePrepareModel.
  ///
  /// In zh, this message translates to:
  /// **'准备 OCR 模型（首次约 140MB）'**
  String get scanStagePrepareModel;

  /// No description provided for @scanStageRecognizing.
  ///
  /// In zh, this message translates to:
  /// **'正在识别文字'**
  String get scanStageRecognizing;

  /// No description provided for @scanStageDone.
  ///
  /// In zh, this message translates to:
  /// **'识别完成'**
  String get scanStageDone;

  /// No description provided for @scanStageDecoding.
  ///
  /// In zh, this message translates to:
  /// **'正在解码二维码/条形码'**
  String get scanStageDecoding;

  /// No description provided for @scanStageDecoded.
  ///
  /// In zh, this message translates to:
  /// **'解码完成'**
  String get scanStageDecoded;

  /// No description provided for @scanFailed.
  ///
  /// In zh, this message translates to:
  /// **'识别失败 · {stage}：{error}'**
  String scanFailed(String stage, String error);

  /// No description provided for @scanNoCode.
  ///
  /// In zh, this message translates to:
  /// **'没识别出码——试试正对屏幕、避开反光、靠近一点'**
  String get scanNoCode;

  /// No description provided for @scanSavedDevice.
  ///
  /// In zh, this message translates to:
  /// **'已保存设备 {name} ({ip})'**
  String scanSavedDevice(String name, String ip);

  /// No description provided for @scanOcrResult.
  ///
  /// In zh, this message translates to:
  /// **'OCR 结果'**
  String get scanOcrResult;

  /// No description provided for @scanNoText.
  ///
  /// In zh, this message translates to:
  /// **'（未识别到文字）'**
  String get scanNoText;

  /// No description provided for @scanDecodeResult.
  ///
  /// In zh, this message translates to:
  /// **'解码结果'**
  String get scanDecodeResult;

  /// No description provided for @scanStagePercent.
  ///
  /// In zh, this message translates to:
  /// **'{stage}（{percent}%）'**
  String scanStagePercent(String stage, int percent);

  /// No description provided for @qrTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成二维码 / 条形码'**
  String get qrTitle;

  /// No description provided for @qrTemplateTitle.
  ///
  /// In zh, this message translates to:
  /// **'内容模板'**
  String get qrTemplateTitle;

  /// No description provided for @qrPreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get qrPreview;

  /// No description provided for @qrGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get qrGenerate;

  /// No description provided for @qrGenerating.
  ///
  /// In zh, this message translates to:
  /// **'生成中…'**
  String get qrGenerating;

  /// No description provided for @qrNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get qrNotSet;

  /// No description provided for @qrGroupMatrix.
  ///
  /// In zh, this message translates to:
  /// **'二维码 / 矩阵码'**
  String get qrGroupMatrix;

  /// No description provided for @qrGroupStacked.
  ///
  /// In zh, this message translates to:
  /// **'堆叠二维'**
  String get qrGroupStacked;

  /// No description provided for @qrGroupRetail.
  ///
  /// In zh, this message translates to:
  /// **'商品条码'**
  String get qrGroupRetail;

  /// No description provided for @qrGroupIndustrial.
  ///
  /// In zh, this message translates to:
  /// **'物流 / 工业'**
  String get qrGroupIndustrial;

  /// No description provided for @qrGroupOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get qrGroupOther;

  /// No description provided for @qrNameQrCode.
  ///
  /// In zh, this message translates to:
  /// **'二维码'**
  String get qrNameQrCode;

  /// No description provided for @qrDim2.
  ///
  /// In zh, this message translates to:
  /// **'二维'**
  String get qrDim2;

  /// No description provided for @qrDim1.
  ///
  /// In zh, this message translates to:
  /// **'一维'**
  String get qrDim1;

  /// No description provided for @qrHintQrCode.
  ///
  /// In zh, this message translates to:
  /// **'任意文本、网址、中文都可以'**
  String get qrHintQrCode;

  /// No description provided for @qrHintDataMatrix.
  ///
  /// In zh, this message translates to:
  /// **'任意文本，体积小，常印在小零件上'**
  String get qrHintDataMatrix;

  /// No description provided for @qrHintAztec.
  ///
  /// In zh, this message translates to:
  /// **'任意文本，常见于登机牌、火车票'**
  String get qrHintAztec;

  /// No description provided for @qrHintPdf417.
  ///
  /// In zh, this message translates to:
  /// **'任意文本，可存较长内容，常见于各类证件'**
  String get qrHintPdf417;

  /// No description provided for @qrHintEan13.
  ///
  /// In zh, this message translates to:
  /// **'12 或 13 位数字，末位是校验位'**
  String get qrHintEan13;

  /// No description provided for @qrHintEan8.
  ///
  /// In zh, this message translates to:
  /// **'7 或 8 位数字'**
  String get qrHintEan8;

  /// No description provided for @qrHintUpcA.
  ///
  /// In zh, this message translates to:
  /// **'11 或 12 位数字'**
  String get qrHintUpcA;

  /// No description provided for @qrHintUpcE.
  ///
  /// In zh, this message translates to:
  /// **'7 或 8 位数字，首位须为 0 或 1'**
  String get qrHintUpcE;

  /// No description provided for @qrHintCode128.
  ///
  /// In zh, this message translates to:
  /// **'任意 ASCII 文本，快递单最常用'**
  String get qrHintCode128;

  /// No description provided for @qrHintCode39.
  ///
  /// In zh, this message translates to:
  /// **'限 0-9 A-Z 与 - . \$ / + % 和空格'**
  String get qrHintCode39;

  /// No description provided for @qrHintCode93.
  ///
  /// In zh, this message translates to:
  /// **'任意 ASCII 文本'**
  String get qrHintCode93;

  /// No description provided for @qrHintItf.
  ///
  /// In zh, this message translates to:
  /// **'偶数位数字，常见于外箱包装'**
  String get qrHintItf;

  /// No description provided for @qrHintCodabar.
  ///
  /// In zh, this message translates to:
  /// **'数字加 A/B/C/D 作起止符，如 A123456B'**
  String get qrHintCodabar;

  /// No description provided for @qrHintTelepen.
  ///
  /// In zh, this message translates to:
  /// **'任意 ASCII 文本，较少使用'**
  String get qrHintTelepen;

  /// No description provided for @qrTplCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get qrTplCustom;

  /// No description provided for @qrTplWifi.
  ///
  /// In zh, this message translates to:
  /// **'WiFi'**
  String get qrTplWifi;

  /// No description provided for @qrTplUrl.
  ///
  /// In zh, this message translates to:
  /// **'网址'**
  String get qrTplUrl;

  /// No description provided for @qrTplVcard.
  ///
  /// In zh, this message translates to:
  /// **'名片'**
  String get qrTplVcard;

  /// No description provided for @qrTplPhone.
  ///
  /// In zh, this message translates to:
  /// **'电话'**
  String get qrTplPhone;

  /// No description provided for @qrTplSms.
  ///
  /// In zh, this message translates to:
  /// **'短信'**
  String get qrTplSms;

  /// No description provided for @qrTplEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮件'**
  String get qrTplEmail;

  /// No description provided for @qrTplCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get qrTplCalendar;

  /// No description provided for @qrTplGeo.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get qrTplGeo;

  /// No description provided for @qrFormatLabel.
  ///
  /// In zh, this message translates to:
  /// **'{name}（{dim}）'**
  String qrFormatLabel(String name, String dim);

  /// No description provided for @qrContentReq.
  ///
  /// In zh, this message translates to:
  /// **'内容要求：{hint}'**
  String qrContentReq(String hint);

  /// No description provided for @qrSelfOnly.
  ///
  /// In zh, this message translates to:
  /// **'注意：{name} 只能生成，本应用的扫一扫识别不了，用其他扫码工具可以正常扫。'**
  String qrSelfOnly(String name);

  /// No description provided for @qrRequirement.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」要求：{hint}'**
  String qrRequirement(String name, String hint);

  /// No description provided for @qrFillField.
  ///
  /// In zh, this message translates to:
  /// **'请填写{label}'**
  String qrFillField(String label);

  /// No description provided for @qrFillContent.
  ///
  /// In zh, this message translates to:
  /// **'请填写内容'**
  String get qrFillContent;

  /// No description provided for @qrNoDigits.
  ///
  /// In zh, this message translates to:
  /// **'{label}里没有可用数字'**
  String qrNoDigits(String label);

  /// No description provided for @qrPickStart.
  ///
  /// In zh, this message translates to:
  /// **'请选择开始时间'**
  String get qrPickStart;

  /// No description provided for @qrGeoNotNumber.
  ///
  /// In zh, this message translates to:
  /// **'经纬度必须是数字'**
  String get qrGeoNotNumber;

  /// No description provided for @qrFieldContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get qrFieldContent;

  /// No description provided for @qrFieldSsid.
  ///
  /// In zh, this message translates to:
  /// **'网络名称 (SSID)'**
  String get qrFieldSsid;

  /// No description provided for @qrFieldPass.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get qrFieldPass;

  /// No description provided for @qrPassHint.
  ///
  /// In zh, this message translates to:
  /// **'加密方式选「无密码」时留空'**
  String get qrPassHint;

  /// No description provided for @qrFieldSecurity.
  ///
  /// In zh, this message translates to:
  /// **'加密方式'**
  String get qrFieldSecurity;

  /// No description provided for @qrEncNone.
  ///
  /// In zh, this message translates to:
  /// **'无密码'**
  String get qrEncNone;

  /// No description provided for @qrFieldUrl.
  ///
  /// In zh, this message translates to:
  /// **'网址'**
  String get qrFieldUrl;

  /// No description provided for @qrUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 example.com，不写开头会自动补 https://'**
  String get qrUrlHint;

  /// No description provided for @qrFieldName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get qrFieldName;

  /// No description provided for @qrFieldMobile.
  ///
  /// In zh, this message translates to:
  /// **'手机'**
  String get qrFieldMobile;

  /// No description provided for @qrFieldEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get qrFieldEmail;

  /// No description provided for @qrFieldOrg.
  ///
  /// In zh, this message translates to:
  /// **'公司'**
  String get qrFieldOrg;

  /// No description provided for @qrFieldJob.
  ///
  /// In zh, this message translates to:
  /// **'职位'**
  String get qrFieldJob;

  /// No description provided for @qrFieldPhoneNumber.
  ///
  /// In zh, this message translates to:
  /// **'电话号码'**
  String get qrFieldPhoneNumber;

  /// No description provided for @qrPhoneHint.
  ///
  /// In zh, this message translates to:
  /// **'空格、横线会被自动去掉'**
  String get qrPhoneHint;

  /// No description provided for @qrFieldSmsTo.
  ///
  /// In zh, this message translates to:
  /// **'收件号码'**
  String get qrFieldSmsTo;

  /// No description provided for @qrFieldSmsBody.
  ///
  /// In zh, this message translates to:
  /// **'短信内容'**
  String get qrFieldSmsBody;

  /// No description provided for @qrFieldMailTo.
  ///
  /// In zh, this message translates to:
  /// **'收件邮箱'**
  String get qrFieldMailTo;

  /// No description provided for @qrFieldSubject.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get qrFieldSubject;

  /// No description provided for @qrFieldBody.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get qrFieldBody;

  /// No description provided for @qrFieldCalTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get qrFieldCalTitle;

  /// No description provided for @qrStartTime.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get qrStartTime;

  /// No description provided for @qrEndTime.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get qrEndTime;

  /// No description provided for @qrEndHint.
  ///
  /// In zh, this message translates to:
  /// **'不选结束时间则按开始后 1 小时计算'**
  String get qrEndHint;

  /// No description provided for @qrFieldLocation.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get qrFieldLocation;

  /// No description provided for @qrFieldLat.
  ///
  /// In zh, this message translates to:
  /// **'纬度'**
  String get qrFieldLat;

  /// No description provided for @qrFieldLng.
  ///
  /// In zh, this message translates to:
  /// **'经度'**
  String get qrFieldLng;

  /// No description provided for @lanTitle.
  ///
  /// In zh, this message translates to:
  /// **'局域网传输'**
  String get lanTitle;

  /// No description provided for @lanReceiver.
  ///
  /// In zh, this message translates to:
  /// **'接收端'**
  String get lanReceiver;

  /// No description provided for @lanSender.
  ///
  /// In zh, this message translates to:
  /// **'发送端'**
  String get lanSender;

  /// No description provided for @lanStartServer.
  ///
  /// In zh, this message translates to:
  /// **'启动服务'**
  String get lanStartServer;

  /// No description provided for @lanStopServer.
  ///
  /// In zh, this message translates to:
  /// **'停止服务'**
  String get lanStopServer;

  /// No description provided for @lanServerKeepAlive.
  ///
  /// In zh, this message translates to:
  /// **'退出本页面服务仍会保持运行，对端可以继续连'**
  String get lanServerKeepAlive;

  /// No description provided for @lanQrHint.
  ///
  /// In zh, this message translates to:
  /// **'用另一台设备扫描此二维码配对'**
  String get lanQrHint;

  /// No description provided for @lanUnpaired.
  ///
  /// In zh, this message translates to:
  /// **'未配对设备'**
  String get lanUnpaired;

  /// No description provided for @lanPeerInfo.
  ///
  /// In zh, this message translates to:
  /// **'目标: {name} ({addr})'**
  String lanPeerInfo(String name, String addr);

  /// No description provided for @lanPair.
  ///
  /// In zh, this message translates to:
  /// **'扫码配对'**
  String get lanPair;

  /// No description provided for @lanTest.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get lanTest;

  /// No description provided for @lanTextContent.
  ///
  /// In zh, this message translates to:
  /// **'文本内容'**
  String get lanTextContent;

  /// No description provided for @lanSendText.
  ///
  /// In zh, this message translates to:
  /// **'发送文本'**
  String get lanSendText;

  /// No description provided for @lanSendFile.
  ///
  /// In zh, this message translates to:
  /// **'发送文件'**
  String get lanSendFile;

  /// No description provided for @lanLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get lanLogTitle;

  /// No description provided for @lanLsTitle.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 设备'**
  String get lanLsTitle;

  /// No description provided for @lanLsOff.
  ///
  /// In zh, this message translates to:
  /// **'兼容层未运行'**
  String get lanLsOff;

  /// No description provided for @lanLsPortInfo.
  ///
  /// In zh, this message translates to:
  /// **'端口 {port}，与官方 LocalSend 自动互通'**
  String lanLsPortInfo(int port);

  /// No description provided for @lanLsNotice.
  ///
  /// In zh, this message translates to:
  /// **'注意：{error}'**
  String lanLsNotice(String error);

  /// No description provided for @lanNoDevice.
  ///
  /// In zh, this message translates to:
  /// **'未发现设备。确认两台设备连的是同一个网络，稍等几秒'**
  String get lanNoDevice;

  /// No description provided for @lanSendToAlias.
  ///
  /// In zh, this message translates to:
  /// **'发送文件到 {alias}'**
  String lanSendToAlias(String alias);

  /// No description provided for @lanSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败：{error}'**
  String lanSendFailed(String error);

  /// No description provided for @lanSnackSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送 {name}'**
  String lanSnackSent(String name);

  /// No description provided for @lanLogLsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 兼容层已按设置关闭'**
  String get lanLogLsDisabled;

  /// No description provided for @lanLogLsStarted.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 兼容层已启动，端口 {port}，官方 LocalSend 可自动发现本机'**
  String lanLogLsStarted(int port);

  /// No description provided for @lanLogLsStartedNoMcast.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 兼容层已启动（端口 {port}），但多播不可用：{reason}，只能被主动扫描发现'**
  String lanLogLsStartedNoMcast(int port, String reason);

  /// No description provided for @lanLogLsStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 兼容层启动失败：{error}'**
  String lanLogLsStartFailed(String error);

  /// No description provided for @lanMcastUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'多播不可用'**
  String get lanMcastUnavailable;

  /// No description provided for @lanUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知原因'**
  String get lanUnknown;

  /// No description provided for @lanLogLsDiscovered.
  ///
  /// In zh, this message translates to:
  /// **'发现 LocalSend 设备：{alias}（{addr}）'**
  String lanLogLsDiscovered(String alias, String addr);

  /// No description provided for @lanLogLsRegistered.
  ///
  /// In zh, this message translates to:
  /// **'{alias} 通过 LocalSend 协议注册到本机（{ip}）'**
  String lanLogLsRegistered(String alias, String ip);

  /// No description provided for @lanLogLsIncoming.
  ///
  /// In zh, this message translates to:
  /// **'{alias} 请求推送 {n} 个文件（{ip}，共 {size}）'**
  String lanLogLsIncoming(String alias, int n, String ip, String size);

  /// No description provided for @lanLogLsReceived.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 收到文件：{name}'**
  String lanLogLsReceived(String name);

  /// No description provided for @lanLogLsRecvFailed.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 文件接收失败：{name}（{error}）'**
  String lanLogLsRecvFailed(String name, String error);

  /// No description provided for @lanLogLsSessionEnd.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 会话结束：成功 {ok}，失败 {fail}'**
  String lanLogLsSessionEnd(int ok, int fail);

  /// No description provided for @lanLogLsError.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend：{message}'**
  String lanLogLsError(String message);

  /// No description provided for @lanLogTextReceived.
  ///
  /// In zh, this message translates to:
  /// **'收到文本 [{kind}] 来自 {from}:\n{text}'**
  String lanLogTextReceived(String kind, String from, String text);

  /// No description provided for @lanLogReverseRegistered.
  ///
  /// In zh, this message translates to:
  /// **'✓ {name} 已反向注册，现在可以互相发送\n{addr}'**
  String lanLogReverseRegistered(String name, String addr);

  /// No description provided for @lanLogServerStarted.
  ///
  /// In zh, this message translates to:
  /// **'服务已启动：{addr}'**
  String lanLogServerStarted(String addr);

  /// No description provided for @lanLogServerPort.
  ///
  /// In zh, this message translates to:
  /// **'服务已启动，端口 {port}'**
  String lanLogServerPort(int port);

  /// No description provided for @lanLogServerAlts.
  ///
  /// In zh, this message translates to:
  /// **'备选地址: {list}'**
  String lanLogServerAlts(String list);

  /// No description provided for @lanLogServerStopped.
  ///
  /// In zh, this message translates to:
  /// **'服务已停止'**
  String get lanLogServerStopped;

  /// No description provided for @lanLogStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动失败: {error}'**
  String lanLogStartFailed(String error);

  /// No description provided for @lanLogSavedDownloads.
  ///
  /// In zh, this message translates to:
  /// **'\n已存入系统\"下载\"目录'**
  String get lanLogSavedDownloads;

  /// No description provided for @lanLogSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'\n⚠ 存入下载目录失败（{error}），文件仍留在应用私有目录'**
  String lanLogSaveFailed(String error);

  /// No description provided for @lanLogFileReceived.
  ///
  /// In zh, this message translates to:
  /// **'收到来自 {from} 的文件 {name}（{size}）\n已保存: {path}{note}'**
  String lanLogFileReceived(
    String from,
    String name,
    String size,
    String path,
    String note,
  );

  /// No description provided for @lanLogTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试连接出错: {error}'**
  String lanLogTestFailed(String error);

  /// No description provided for @lanLogPeerUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 连不上 {name}（尝试了 {ips}）。\n请确认两台设备连的是同一个 Wi-Fi/局域网，且对方已启动接收服务'**
  String lanLogPeerUnreachable(String name, String ips);

  /// No description provided for @lanLogConnOk.
  ///
  /// In zh, this message translates to:
  /// **'✓ 连接正常 {addr}'**
  String lanLogConnOk(String addr);

  /// No description provided for @lanLogConnOkAlt.
  ///
  /// In zh, this message translates to:
  /// **'✓ 连接正常，改用可达地址 {addr}（二维码首选的 {preferred} 连不上）'**
  String lanLogConnOkAlt(String addr, String preferred);

  /// No description provided for @lanLogNeedServer.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 本机接收服务未运行，{name} 还不能给本机发送。\n点上方「启动服务」后，请对方重新扫一次你的二维码'**
  String lanLogNeedServer(String name);

  /// No description provided for @lanLogToldPeer.
  ///
  /// In zh, this message translates to:
  /// **'✓ 已把本机地址告诉 {name}，现在双方都能互发'**
  String lanLogToldPeer(String name);

  /// No description provided for @lanLogReverseFailed.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 无法反向注册给 {name}：{error}'**
  String lanLogReverseFailed(String name, String error);

  /// No description provided for @lanLogPaired.
  ///
  /// In zh, this message translates to:
  /// **'已配对设备: {name} ({addr})'**
  String lanLogPaired(String name, String addr);

  /// No description provided for @lanLogTextSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送文本到 {name}'**
  String lanLogTextSent(String name);

  /// No description provided for @lanLogSendTextFailed.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 发送文本失败：{error}'**
  String lanLogSendTextFailed(String error);

  /// No description provided for @lanLogFileSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送文件 {name} 到 {to}'**
  String lanLogFileSent(String name, String to);

  /// No description provided for @lanLogSendFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 发送文件失败：{error}'**
  String lanLogSendFileFailed(String error);

  /// No description provided for @lanLogLsSent.
  ///
  /// In zh, this message translates to:
  /// **'已通过 LocalSend 发送 {name} 到 {alias}'**
  String lanLogLsSent(String name, String alias);

  /// No description provided for @lanLogLsSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'LocalSend 发送失败：{error}'**
  String lanLogLsSendFailed(String error);

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutNoLan.
  ///
  /// In zh, this message translates to:
  /// **'未检测到局域网地址'**
  String get aboutNoLan;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version} ({build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'信息读取失败'**
  String get aboutLoadFailed;

  /// No description provided for @aboutSectionDevice.
  ///
  /// In zh, this message translates to:
  /// **'本机信息'**
  String get aboutSectionDevice;

  /// No description provided for @aboutLocalIp.
  ///
  /// In zh, this message translates to:
  /// **'本地 IP'**
  String get aboutLocalIp;

  /// No description provided for @aboutListenPort.
  ///
  /// In zh, this message translates to:
  /// **'监听端口'**
  String get aboutListenPort;

  /// No description provided for @aboutFingerprint.
  ///
  /// In zh, this message translates to:
  /// **'设备指纹'**
  String get aboutFingerprint;

  /// No description provided for @aboutFingerprintHint.
  ///
  /// In zh, this message translates to:
  /// **'启用 LocalSend 兼容后生成，对方据此识别本机身份'**
  String get aboutFingerprintHint;

  /// No description provided for @aboutSectionLicense.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get aboutSectionLicense;

  /// No description provided for @aboutLicenseTitle.
  ///
  /// In zh, this message translates to:
  /// **'本项目采用 Apache License 2.0'**
  String get aboutLicenseTitle;

  /// No description provided for @aboutLicenseBody.
  ///
  /// In zh, this message translates to:
  /// **'允许商业使用、修改与分发。分发本软件的副本时，\n请保留仓库中的 LICENSE 与 NOTICE 文件。\n\n完整许可文本见项目根目录的 LICENSE 文件。'**
  String get aboutLicenseBody;

  /// No description provided for @aboutSectionThirdParty.
  ///
  /// In zh, this message translates to:
  /// **'第三方组件'**
  String get aboutSectionThirdParty;

  /// No description provided for @commonSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get commonSaved;

  /// No description provided for @commonSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String commonSaveFailed(String error);

  /// No description provided for @setConfigLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'配置读取失败'**
  String get setConfigLoadFailed;

  /// No description provided for @setSectionTransfer.
  ///
  /// In zh, this message translates to:
  /// **'互传'**
  String get setSectionTransfer;

  /// No description provided for @setDeviceName.
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get setDeviceName;

  /// No description provided for @setDeviceNameHelp.
  ///
  /// In zh, this message translates to:
  /// **'对方设备列表里显示的名字'**
  String get setDeviceNameHelp;

  /// No description provided for @setPortLabel.
  ///
  /// In zh, this message translates to:
  /// **'监听端口'**
  String get setPortLabel;

  /// No description provided for @setPortHelp.
  ///
  /// In zh, this message translates to:
  /// **'默认 {port}。被占用时会自动改用其他端口，不影响互传'**
  String setPortHelp(int port);

  /// No description provided for @setPinLabel.
  ///
  /// In zh, this message translates to:
  /// **'传输 PIN（可选）'**
  String get setPinLabel;

  /// No description provided for @setPinHelp.
  ///
  /// In zh, this message translates to:
  /// **'留空表示不校验。设置后，对方必须输入才能推送文件'**
  String get setPinHelp;

  /// No description provided for @setVerifyHash.
  ///
  /// In zh, this message translates to:
  /// **'校验文件哈希'**
  String get setVerifyHash;

  /// No description provided for @setVerifyHashSub.
  ///
  /// In zh, this message translates to:
  /// **'收到文件后比对发送方提供的 SHA-256'**
  String get setVerifyHashSub;

  /// No description provided for @setLsCompat.
  ///
  /// In zh, this message translates to:
  /// **'启用 LocalSend 兼容'**
  String get setLsCompat;

  /// No description provided for @setLsCompatSub.
  ///
  /// In zh, this message translates to:
  /// **'与官方 LocalSend 同一网络自动互通：不用扫码，进入传输页就会自动发现'**
  String get setLsCompatSub;

  /// No description provided for @setSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get setSectionAbout;

  /// No description provided for @setAboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于互传助手'**
  String get setAboutTitle;

  /// No description provided for @setAboutSub.
  ///
  /// In zh, this message translates to:
  /// **'版本、开源许可与第三方组件'**
  String get setAboutSub;

  /// No description provided for @onBcLabel.
  ///
  /// In zh, this message translates to:
  /// **'前{year}'**
  String onBcLabel(int year);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
