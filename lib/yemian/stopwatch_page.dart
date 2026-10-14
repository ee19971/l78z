//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 秒表——计时、暂停、复位与计次。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 秒表模型。
///
/// 做成**单例**是这个页面的关键设计：页面 dispose 时只取消刷新用的 Timer，
/// 不碰表本身。秒表计到一半切去日历看一眼、再切回来，必须接着走——
/// 秒表最基本的预期就是它不该因为你看了一眼别处而停。
///
/// 计时用 [Stopwatch]（单调时钟，基于性能计数器），不受用户改系统时间、
/// NTP 对时影响；手机锁屏进后台后 Dart 的 Timer 会暂停，但表本身继续累，
/// 解锁回来读到的仍是真实经过的时间。
class StopwatchModel {
  StopwatchModel._();

  static final StopwatchModel instance = StopwatchModel._();

  final Stopwatch _sw = Stopwatch();

  /// 每圈的用时，存的是**相对上一圈的差值**而非累计值——
  /// 列表能直接显示，不用每次重建都从累计里减一遍。
  final List<Duration> laps = [];

  /// 已记过的累计时长，用来从总耗时里切出下一圈。
  Duration _lapSum = Duration.zero;

  bool get running => _sw.isRunning;

  /// 表是否有过读数。用来区分「还没开始」和「暂停在 00:00.00」。
  bool get started => _sw.elapsedMilliseconds > 0 || laps.isNotEmpty;

  Duration get elapsed => _sw.elapsed;

  void start() => _sw.start();
  void pause() => _sw.stop();

  void reset() {
    _sw.reset();
    laps.clear();
    _lapSum = Duration.zero;
  }

  /// 记一圈。表没在跑时不记——暂停时手滑点到「计次」不该凭空多一圈 0。
  void lap() {
    if (!running) return;
    final now = _sw.elapsed;
    laps.add(now - _lapSum);
    _lapSum = now;
  }
}

/// 秒表页。
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  final StopwatchModel _model = StopwatchModel.instance;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // 从别的页面回来时表可能还在跑，立刻恢复刷新。
    _syncTicker();
  }

  @override
  void dispose() {
    // 只停刷新，不动表——见 [StopwatchModel] 的说明。
    _refresh?.cancel();
    _refresh = null;
    super.dispose();
  }

  /// 让刷新 Timer 的开关紧跟表的运行状态：跑着才需要高频重绘，
  /// 暂停时留一个 25Hz 的空转 Timer 只是白耗电。
  void _syncTicker() {
    final shouldRun = _model.running;
    if (shouldRun && _refresh == null) {
      _refresh = Timer.periodic(const Duration(milliseconds: 40), (_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldRun && _refresh != null) {
      _refresh?.cancel();
      _refresh = null;
      // 停下来的那一下要把定格值画出来，否则屏上还留着上一帧的读数。
      if (mounted) setState(() {});
    }
  }

  /// `MM:SS.CC`。分钟不取模——跑满一小时该显示 `60:00.00` 而不是回到 `00:00.00`。
  static String _fmt(Duration d) {
    final cs = (d.inMilliseconds % 1000) ~/ 10;
    final s = d.inSeconds % 60;
    return '${d.inMinutes.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  /// 与上圈的差值：正数慢（红）、负数快（绿）。
  ///
  /// 首圈没有对比对象，返回 null 由调用方决定显示什么。
  String? _delta(int index) {
    if (index == 0) return null;
    final diff = _model.laps[index] - _model.laps[index - 1];
    final sign = diff.isNegative ? '-' : '+';
    final cs = (diff.inMilliseconds.abs() % 1000) ~/ 10;
    final s = diff.inSeconds.abs() % 60;
    return '$sign${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  // -----------------------------------------------------------------------
  // 按钮
  // -----------------------------------------------------------------------

  Widget _primary(String label, VoidCallback? onPressed) {
    return Expanded(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          // 主操作按钮等宽，跑表过程中文字从「开始」变成「暂停」时
          // 按钮宽度不变，底下一排不会跟着抖。
          minimumSize: const Size(0, 48),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _secondary(String label, VoidCallback? onPressed) {
    return Expanded(
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(0, 48),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  /// 按钮随状态三态切换：未开始 / 运行中 / 暂停。
  Widget _controls() {
    final l10n = AppLocalizations.of(context)!;
    if (!_model.started) {
      return Row(
        children: [
          _primary(l10n.swStart, () {
            _model.start();
            _syncTicker();
          }),
        ],
      );
    }
    if (_model.running) {
      return Row(
        children: [
          _secondary(l10n.swLap, () {
            _model.lap();
            setState(() {});
          }),
          const SizedBox(width: 12),
          _primary(l10n.swPause, () {
            _model.pause();
            _syncTicker();
          }),
        ],
      );
    }
    return Row(
      children: [
        _secondary(l10n.swReset, () {
          _model.reset();
          setState(() {});
        }),
        const SizedBox(width: 12),
        _primary(l10n.swResume, () {
          _model.start();
          _syncTicker();
        }),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // 计次列表
  // -----------------------------------------------------------------------

  Widget _lapsList() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_model.laps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(l10n.swHint,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }

    // 最新一圈放最上面，和 iOS 秒表一致——计次时视线就在列表顶部。
    final rows = <Widget>[];
    for (var i = _model.laps.length - 1; i >= 0; i--) {
      final delta = _delta(i);
      final deltaColor = delta == null
          ? theme.colorScheme.onSurfaceVariant
          : (delta.startsWith('-')
              ? Colors.green.shade700
              : Colors.red.shade700);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(l10n.swLapN(i + 1),
                    style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Text(
                  _fmt(_model.laps[i]),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  delta ?? '—',
                  textAlign: TextAlign.right,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: deltaColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(l10n.swTotal,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(
                  _fmt(_model.elapsed),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 76),
            ],
          ),
        ),
        ...rows,
      ],
    );
  }

  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.swTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                _fmt(_model.elapsed),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          _controls(),
          const SizedBox(height: 8),
          _lapsList(),
        ],
      ),
    );
  }
}
