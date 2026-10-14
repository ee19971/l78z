/// Windows 桌面小组件（倒数日贴桌面）的进程与开机自启管理。
///
/// 部件是独立 exe `l78z_widget.exe`，与主程序同目录；开关状态存
/// SharedPreferences（[`kDesktopWidgetEnabled`]），开机自启走
/// HKCU\...\Run 注册表键。全部用原生 `Process.run`，不经过 Rust/FRB，
/// 零 codegen 变更。
library;

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// 开关状态在 prefs 里的 key。true = 部件应常驻（开机自启 + 立即运行）。
const kDesktopWidgetEnabled = 'desktop_widget_enabled';

/// Run 键值名（HKCU\Software\Microsoft\Windows\CurrentVersion\Run）。
const _runValueName = 'l78z-desktop-widget';

/// Run 键路径。
const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

/// 部件 exe 文件名。
const _exeName = 'l78z_widget.exe';

/// 部件可执行文件路径；非 Windows 或同目录找不到返回 null。
///
/// 开发环境（flutter run 的 Debug 目录没拷 exe）会走到 null，
/// 调用方据此提示而不是静默失败。
String? widgetExePath() {
  if (!Platform.isWindows) return null;
  final exe = File(Platform.resolvedExecutable);
  final p =
      '${exe.parent.path}${Platform.pathSeparator}$_exeName';
  return File(p).existsSync() ? p : null;
}

/// 部件进程是否在跑。
///
/// tasklist 按映像名过滤：有匹配时输出行含 exe 名；无匹配时输出
/// 「INFO: 没有运行的任务匹配指定条件」（文案随系统语言变，但不含
/// exe 名），所以 contains 判定在两种语言下都成立。
Future<bool> isWidgetRunning() async {
  if (!Platform.isWindows) return false;
  final r = await Process.run(
    'tasklist',
    ['/FI', 'IMAGENAME eq $_exeName', '/NH'],
  );
  final out = '${r.stdout}${r.stderr}';
  return out.contains(_exeName);
}

/// 后台启动部件；exe 不存在时静默返回 false。
///
/// 用 detached：主程序退出不影响部件常驻。
Future<bool> startDesktopWidget() async {
  final path = widgetExePath();
  if (path == null) return false;
  await Process.start(
    path,
    const [],
    mode: ProcessStartMode.detached,
    workingDirectory: File(path).parent.path,
  );
  return true;
}

/// 结束部件进程（不存在时 taskkill 报错也不在乎）。
Future<void> stopDesktopWidget() async {
  if (!Platform.isWindows) return;
  await Process.run('taskkill', ['/IM', _exeName, '/F']);
}

/// 写/删 Run 键，实现开机自启。
///
/// Run 键直接指向部件 exe：开机不依赖主程序先启动。
Future<void> setDesktopWidgetAutostart(bool enable) async {
  if (!Platform.isWindows) return;
  if (enable) {
    final path = widgetExePath();
    if (path == null) return;
    await Process.run('reg', [
      'add',
      _runKey,
      '/v',
      _runValueName,
      '/t',
      'REG_SZ',
      '/d',
      path,
      '/f',
    ]);
  } else {
    await Process.run('reg', ['delete', _runKey, '/v', _runValueName, '/f']);
  }
}

/// 读开关状态。
Future<bool> desktopWidgetEnabled() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(kDesktopWidgetEnabled) ?? false;
}

/// 写开关状态。
Future<void> setDesktopWidgetEnabled(bool v) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(kDesktopWidgetEnabled, v);
}
