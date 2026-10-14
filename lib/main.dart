import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:l78z/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'yemian/app_settings.dart';
import 'yemian/calendar.dart';
import 'yemian/countdown_page.dart';
import 'yemian/date_calc_page.dart';
import 'yemian/festivals_page.dart';
import 'yemian/main_page.dart';
import 'yemian/timezone_data.dart';
import 'yemian/tools_page.dart';

import 'l10n/app_localizations.dart';
import 'yemian/desktop_widget.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
    // 时区库要在主页面第一帧之前就绪，否则时钟会退化成本机时间。
    initTimezones();
    await _initAppSettings();
    runApp(const MyApp());
  } catch (e) {
    // 如果初始化失败，运行一个简单的错误页面，方便调试
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('初始化失败: $e\n请检查浏览器控制台或查看是否缺少 COOP/COEP 请求头'),
          ),
        ),
      ),
    );
  }
}

/// 启动时读应用设置；顺带做首装时区探测——用户从没选过城市时，
/// 按系统 locale 国家码（兜底 UTC 偏移）猜一个首都写进 prefs，
/// 装完第一次打开时钟就是当地时间。
Future<void> _initAppSettings() async {
  await AppSettingsModel.instance.load();
  final sp = await SharedPreferences.getInstance();
  if (sp.getString(kCityLocation) == null) {
    await sp.setString(kCityLocation, detectLocalCity().location);
  }
  // Windows 桌面部件自愈：开关开着但进程不在（被手动结束/异常退出）→
  // 拉起。开发环境 exe 不在时 startDesktopWidget 内部静默跳过。
  if (await desktopWidgetEnabled() && !(await isWidgetRunning())) {
    await startDesktopWidget();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // main() 里已经 load 过，这里只在热重载/测试场景兜底一次。
    if (AppSettingsModel.instance.fontScale == 1.0 &&
        AppSettingsModel.instance.locale == null) {
      AppSettingsModel.instance.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsModel.instance,
      builder: (context, _) {
        final settings = AppSettingsModel.instance;
        final family = settings.effectiveFontFamily;
        // 始终给主题：seed 是当前选的中国传统色（默认朱砂），Material3 由此
        // 派生整套配色，选中态/按钮/进度条全跟随；字体族是叠加项，选了
        // 系统默认就不动 textTheme。
        final base = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: settings.themeColor),
        );
        return MaterialApp(
          locale: settings.locale,
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          // 换字体族时同步给 textTheme 设 fontFamily；生僻字回落系统字体，
          // 靠 fontFamilyFallback 兜底，避免子集化字体缺字显示豆腐块。
          theme: family == null
              ? base
              : base.copyWith(
                  textTheme: base.textTheme.apply(
                    fontFamily: family,
                    fontFamilyFallback: const ['sans-serif'],
                  ),
                ),
          // 全局字号缩放：设置页拖滑杆即时生效，覆盖所有文本样式。
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(settings.fontScale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

/// 【优化】使用枚举管理 Tab，避免使用“魔法数字” (0, 1, 2...)
/// 顺序与底部导航栏一致，home（主页面）居中且为默认页
enum AppTab { festivals, calculator, home, tools, progress, calendar }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 【修复】去掉 final，因为需要 setState 修改它
  AppTab _currentTab = AppTab.home;

  /// 本次切换的方向：1 = 新页从右侧滑入（往右切），-1 = 从左侧滑入。
  int _slideDir = 1;

  /// 【优化】通过枚举直接映射页面，逻辑更清晰
  Widget _getPage(AppTab tab) {
    switch (tab) {
      case AppTab.festivals:
        return const FestivalsPage();
      case AppTab.calculator:
        return const DateCalcPage();
      case AppTab.home:
        return const MainPage();
      case AppTab.tools:
        return const ToolsPage();
      case AppTab.progress:
        return const CountdownPage();
      case AppTab.calendar:
        return const CalendarPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 统一在这里挡状态栏：Flutter 的 SafeArea 会把 MediaQuery.padding 归零后
      // 再往下传，所以子页面 AppBar 内部那层 SafeArea 会看到 padding.top = 0
      // 而不再叠加，不会出现双重空隙。日历页没有自己的 AppBar，以前 body 直接
      // 从屏幕顶端起算，在 Android 15（edge-to-edge 强制开启）上就压到状态栏底下了。
      body: SafeArea(
        // 底部 tab 切换动画：新页从目标方向滑入淡入，旧页向反方向滑出淡出。
        // transitionBuilder 靠 child 的 key 区分新旧页——等于当前 tab 的是
        // 新页，其余是旧页；旧页额外包 IgnorePointer，避免 220ms 过渡期间
        // 误点到还没消失的上一页按钮。
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            final isNew = child.key == ValueKey(_currentTab);
            final slide = SlideTransition(
              position: Tween<Offset>(
                begin: isNew
                    ? Offset(_slideDir.toDouble(), 0)
                    : Offset.zero,
                end: isNew ? Offset.zero : Offset(-_slideDir.toDouble(), 0),
              ).animate(animation),
              child: child,
            );
            final faded = FadeTransition(opacity: animation, child: slide);
            return isNew ? faded : IgnorePointer(child: faded);
          },
          child: KeyedSubtree(
            key: ValueKey(_currentTab),
            child: _getPage(_currentTab),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        // 【修复】使用枚举的 index
        selectedIndex: _currentTab.index,
        onDestinationSelected: (int index) {
          setState(() {
            // 点当前 tab 不重播动画，只让指示器回弹一下。
            if (index != _currentTab.index) {
              _slideDir = index > _currentTab.index ? 1 : -1;
              _currentTab = AppTab.values[index];
            }
          });
        },
        // 顺序与 AppTab 枚举保持一致
        destinations: [
          // 节日节气
          NavigationDestination(
            icon: const Icon(Icons.celebration_outlined),
            selectedIcon: const Icon(Icons.celebration),
            label: AppLocalizations.of(context)!.tabFestivals,
          ),
          // 日期计算
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: AppLocalizations.of(context)!.tabCalculator,
          ),
          // 主页面
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.tabHome,
          ),
          // 工具
          NavigationDestination(
            icon: const Icon(Icons.handyman_outlined),
            selectedIcon: const Icon(Icons.handyman),
            label: AppLocalizations.of(context)!.tabTools,
          ),
          // 倒数日
          NavigationDestination(
            icon: const Icon(Icons.hourglass_top_outlined),
            selectedIcon: const Icon(Icons.hourglass_top),
            label: AppLocalizations.of(context)!.tabCountdown,
          ),
          // 日历
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: AppLocalizations.of(context)!.tabCalendar,
          ),
        ],
      ),
    );
  }

}

// --- 页面占位组件 ---

// class CalendarPage extends StatelessWidget {
//   const CalendarPage({super.key});
//
//   @override
//   Widget build(BuildContext context) => const Center(child: Text('日历页面'));
// }
