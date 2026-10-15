import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'calendar_prefs.dart';
import 'festivals.dart';

/// 视图层级：年 > 月 > 周 > 日
/// 双指捏合 → 换粗一档（日→周→月→年）；双指外扩 → 换细一档（年→月→周→日）
enum CalendarView { year, month, week, day }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  static const List<CalendarView> _viewOrder = [
    CalendarView.year,
    CalendarView.month,
    CalendarView.week,
    CalendarView.day,
  ];
  /// 当前视图名（标题下方的小字）。
  String _viewName(AppLocalizations l10n) => switch (_view) {
        CalendarView.year => l10n.calViewYear,
        CalendarView.month => l10n.calViewMonth,
        CalendarView.week => l10n.calViewWeek,
        CalendarView.day => l10n.calViewDay,
      };

  /// 「上一/下一」后面的单位（年/月/周/日）。
  String _viewTag(AppLocalizations l10n) => switch (_view) {
        CalendarView.year => l10n.calUnitYear,
        CalendarView.month => l10n.calUnitMonth,
        CalendarView.week => l10n.calUnitWeek,
        CalendarView.day => l10n.calUnitDay,
      };

  /// 标题里的月份：中文「2026年10月」，英文走 intl「October 2026」。
  String _monthTitle(DateTime m) {
    final loc = Localizations.localeOf(context);
    if (loc.languageCode == 'zh') {
      return DateFormat('yyyy年MM月').format(m);
    }
    return DateFormat.yMMMM(loc.toString()).format(m);
  }

  // 宽屏断点：平板横屏 / 桌面 / 折叠屏展开后左日历、右详情
  static const double _twoPaneBreakpoint = 600;
  // 桌面/大平板断点：超过它日历占 3/5，否则左右各一半
  static const double _desktopBreakpoint = 900;
  // 详情面板最大宽度，超宽屏上避免被拉长
  static const double _detailMaxWidth = 420;
  // 头部 + 星期标题的预留高度
  static const double _headerReserve = 84;
  // 窄屏给详情区预留的最小高度
  //
  // 详情不止四行——加上农历完整日期和「距今」后有六行，预留太小会把它
  // 挤成滚动条，而上方日历本来就该是「一眼扫过」的角色。
  static const double _minDetailReserve = 280;
  // 单指滑动触发距离
  static const double _swipeThreshold = 60;
  // 双指缩放幅度阈值
  static const double _pinchThreshold = 0.15;

  DateTime _focusedMonth = DateTime.now();
  late final DateTime _today;
  late DateTime _selectedDate;
  CalendarView _view = CalendarView.month;

  // 手势状态
  final Map<int, Offset> _activePointers = {};
  double _pinchBase = 0;
  Offset _dragOrigin = Offset.zero;
  bool _gestureConsumed = false;

  double get _pointerDistance {
    if (_activePointers.length < 2) return 0;
    final pts = _activePointers.values.take(2).toList();
    return (pts[0] - pts[1]).distance;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDate = _today;
    // 偏好异步读盘：首帧先按内存默认渲染，读完再刷一次（和设置页同套路）。
    CalendarPrefs.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _weekStart(DateTime date) => CalendarPrefs.weekStartMonday
      ? date.subtract(Duration(days: date.weekday - 1))
      : date.subtract(Duration(days: date.weekday % 7));

  /// 月视图首格偏移：当月 1 号落在周几（相对周起始日）。
  static int _firstWeekdayOffset(DateTime monthFirst) =>
      CalendarPrefs.weekStartMonday
          ? (monthFirst.weekday + 6) % 7
          : monthFirst.weekday % 7;

  static DateTime _sameDayIn(DateTime date, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _twoPaneBreakpoint) {
          // 折叠屏展开（600~900）左右各一半；桌面/大平板（≥900）3:2
          final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: isDesktop ? 3 : 1,
                child: LayoutBuilder(
                  builder: (context, pane) {
                    final bodyHeight = _bodyHeight(
                      pane.maxWidth,
                      pane.maxHeight - _headerReserve,
                    );
                    return _buildCalendarPane(
                      pane.maxWidth,
                      bodyHeight,
                      key: const ValueKey('calendar-pane'),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                flex: isDesktop ? 2 : 1,
                child: Padding(
                  key: const ValueKey('detail-pane'),
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _detailMaxWidth),
                      child: SingleChildScrollView(
                        child: _buildDateDetail(_selectedDate, asPanel: true),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        // 窄屏：日历在上（定高，放不下就压扁格子），详情在下（可滚动）
        final bodyHeight = _bodyHeight(
          constraints.maxWidth,
          constraints.maxHeight - _headerReserve - _minDetailReserve,
        );
        return Column(
          children: [
            _buildCalendarPane(constraints.maxWidth, bodyHeight),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDateDetail(_selectedDate),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 各视图的自然高度；放不下时按可用高度压缩（格子变扁，不滚动、不溢出）
  double _bodyHeight(double width, double available) {
    double natural;
    switch (_view) {
      case CalendarView.year:
        natural = width * 3 / 4; // 4 列 3 行
      case CalendarView.month:
        final first = _firstWeekdayOffset(
            DateTime(_focusedMonth.year, _focusedMonth.month, 1));
        final days =
            DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
        // 格子高度取宽度的 0.62 倍而不是正方形：正方形网格在手机上会吃掉
        // 近半屏，底部详情只剩一条缝。压扁后详情能完整放下六行历法信息，
        // 而日期数字和小字仍看得清——这一格本来就只需要「数字 + 一行小字」。
        natural = width * ((first + days + 6) ~/ 7) / 7 * 0.62;
      case CalendarView.week:
        natural = 7 * 56; // 7 行日程
      case CalendarView.day:
        natural = 260;
    }
    final cap = available < 20 ? 20.0 : available;
    return natural > cap ? cap : natural;
  }

  // 日历面板：头部 + 视图内容，单指滑动换年/月，双指捏合/外扩切视图
  Widget _buildCalendarPane(double width, double bodyHeight, {Key? key}) {
    return Listener(
      key: key,
      // 用 Listener 而非 GestureDetector：scale 回调在 arena 胜出后才触发
      // （带 slop 偏移），且两指 scale 基准漂移；这里直接跟踪指针坐标
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (_view == CalendarView.month) _buildWeekDays(),
            SizedBox(
              height: bodyHeight,
              // 网格切换动画：key = 视图 + 焦点粒度（见 _gridKey），
              // 换月/换年/换视图换 key → 淡入 + 轻微缩放；月视图里点选
              // 日期 key 不变 → 不闪。动画期旧网格由 IgnorePointer 挡住
              // 点击，免得 160ms 内误点到上一屏的日期。
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  final isNew = child.key == ValueKey(_gridKey());
                  final faded = FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  );
                  return isNew ? faded : IgnorePointer(child: faded);
                },
                child: KeyedSubtree(
                  key: ValueKey(_gridKey()),
                  child: _buildViewBody(width, bodyHeight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 网格动画的 key：视图 + 该视图的焦点粒度。
  ///
  /// 刻意不含月视图的选中日期——点格子选中不该让整屏闪一下；
  /// 周视图用周起始日（同周内换选中日不闪，跨周是整屏换内容，该闪）。
  String _gridKey() => switch (_view) {
        CalendarView.year => 'y${_focusedMonth.year}',
        CalendarView.month => 'm${_focusedMonth.year}-${_focusedMonth.month}',
        CalendarView.week => 'w${_weekStart(_selectedDate)}',
        CalendarView.day =>
          'd${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
      };

  Widget _buildViewBody(double width, double height) {
    switch (_view) {
      case CalendarView.year:
        return _buildYearGrid(width, height);
      case CalendarView.month:
        return _buildMonthGrid(width, height);
      case CalendarView.week:
        return _buildWeekList();
      case CalendarView.day:
        return _buildDayBody();
    }
  }

  // ---------- 手势 ----------

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointers.isEmpty) {
      _dragOrigin = event.localPosition;
      _gestureConsumed = false;
      _pinchBase = 0;
    }
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) _pinchBase = _pointerDistance;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_gestureConsumed) return;

    if (_activePointers.length >= 2) {
      // 双指：捏合（间距变小）换粗视图，外扩换细视图
      if (_pinchBase <= 0) return;
      final ratio = _pointerDistance / _pinchBase;
      if (ratio < 1 - _pinchThreshold) {
        _gestureConsumed = true;
        _stepView(-1);
      } else if (ratio > 1 + _pinchThreshold) {
        _gestureConsumed = true;
        _stepView(1);
      }
      return;
    }

    // 单指：左右划换年，上下划换月
    final delta = event.localPosition - _dragOrigin;
    if (delta.dx.abs() > _swipeThreshold && delta.dx.abs() > delta.dy.abs()) {
      _gestureConsumed = true;
      _shiftYear(delta.dx < 0 ? 1 : -1); // 左划 → 下一年
    } else if (delta.dy.abs() > _swipeThreshold) {
      _gestureConsumed = true;
      _shiftMonth(delta.dy < 0 ? 1 : -1); // 上划 → 下一月
    }
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) _pinchBase = 0;
    if (_activePointers.isEmpty) _gestureConsumed = false;
  }

  void _stepView(int delta) {
    final index = _viewOrder.indexOf(_view) + delta;
    if (index < 0 || index >= _viewOrder.length) return;
    setState(() => _view = _viewOrder[index]);
  }

  void _shiftYear(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year + delta, _focusedMonth.month);
      _selectedDate =
          _sameDayIn(_selectedDate, _focusedMonth.year, _focusedMonth.month);
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      final m = _focusedMonth.month - 1 + delta;
      final year = _focusedMonth.year + m ~/ 12;
      final month = m % 12 + 1;
      _focusedMonth = DateTime(year, month);
      _selectedDate = _sameDayIn(_selectedDate, year, month);
    });
  }

  void _shiftDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
      _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    });
  }

  // ---------- 头部（月份/年份 + 视图名 + 箭头 + 设置） ----------

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (_view) {
      CalendarView.year => l10n.calYearTitle(_focusedMonth.year),
      _ => _monthTitle(_focusedMonth),
    };
    // 左右各一簇：< > 贴着标题走，⚙ 靠最右单独一列——翻页是高频操作，
    // 该离标题近；设置是低频入口，放角落里也不容易误点。
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.calPrev(_viewTag(l10n)),
            onPressed: () => _goPrev(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题交叉淡化：换月/换年/换视图时新旧标题快速淡接，
                // key 用标题文本，同标题的重复 setState 不会重播。
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(_viewName(l10n),
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.calNext(_viewTag(l10n)),
            onPressed: () => _goNext(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.calSettings,
            onPressed: _openDisplaySettings,
          ),
        ],
      ),
    );
  }

  /// 日历显示设置：格子小字档位 + 周起始日，改完即时生效。
  Future<void> _openDisplaySettings() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(l10n.calSettings,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(l10n.calCellLabelTitle,
                    style: Theme.of(ctx).textTheme.labelMedium
                        ?.copyWith(color: Theme.of(ctx).hintColor)),
              ),
              RadioGroup<CellLabelMode>(
                groupValue: CalendarPrefs.cellLabelMode,
                onChanged: (v) async {
                  if (v == null) return;
                  await CalendarPrefs.setCellLabelMode(v);
                  if (ctx.mounted) setSheetState(() {});
                  // 换档影响整页格子小字，重建整个日历页。
                  if (mounted) setState(() {});
                },
                child: Column(
                  children: [
                    for (final mode in CellLabelMode.values)
                      RadioListTile<CellLabelMode>(
                        dense: true,
                        title: Text(_cellLabelModeLabel(l10n, mode)),
                        value: mode,
                      ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(l10n.calWeekStartTitle,
                    style: Theme.of(ctx).textTheme.labelMedium
                        ?.copyWith(color: Theme.of(ctx).hintColor)),
              ),
              RadioGroup<bool>(
                groupValue: CalendarPrefs.weekStartMonday,
                onChanged: (v) async {
                  await CalendarPrefs.setWeekStartMonday(v ?? false);
                  if (ctx.mounted) setSheetState(() {});
                  if (mounted) setState(() {});
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      dense: true,
                      title: Text(l10n.calWeekStartSunday),
                      value: false,
                    ),
                    RadioListTile<bool>(
                      dense: true,
                      title: Text(l10n.calWeekStartMonday),
                      value: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _cellLabelModeLabel(AppLocalizations l10n, CellLabelMode mode) =>
      switch (mode) {
        CellLabelMode.jieqiLunar => l10n.calCellJieqiLunar,
        CellLabelMode.full => l10n.calCellFull,
        CellLabelMode.lunarOnly => l10n.calCellLunarOnly,
        CellLabelMode.hidden => l10n.calCellHidden,
      };

  void _goPrev() {
    switch (_view) {
      case CalendarView.year:
        setState(() => _focusedMonth =
            DateTime(_focusedMonth.year - 1, _focusedMonth.month));
      case CalendarView.month:
        _shiftMonth(-1);
      case CalendarView.week:
        setState(() {
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          _focusedMonth =
              DateTime(_selectedDate.year, _selectedDate.month);
        });
      case CalendarView.day:
        _shiftDay(-1);
    }
  }

  void _goNext() {
    switch (_view) {
      case CalendarView.year:
        setState(() => _focusedMonth =
            DateTime(_focusedMonth.year + 1, _focusedMonth.month));
      case CalendarView.month:
        _shiftMonth(1);
      case CalendarView.week:
        setState(() {
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          _focusedMonth =
              DateTime(_selectedDate.year, _selectedDate.month);
        });
      case CalendarView.day:
        _shiftDay(1);
    }
  }

  Widget _buildWeekDays() {
    // 表头单字：中文「日一二三四五六」，英文窄首字母「SMTWTFS」。
    // 周一起始时整体左旋一位（「一二三四五六日」/「MTWTFSS」）。
    final raw = AppLocalizations.of(context)!.calWeekHeader;
    final header =
        (CalendarPrefs.weekStartMonday ? raw.substring(1) + raw[0] : raw)
            .split('');
    return Row(
      children: [
        for (final w in header)
          Expanded(
            child: Center(
              child: Text(w,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Theme.of(context).hintColor)),
            ),
          ),
      ],
    );
  }

  // ---------- 年视图：12 个月，每格显示该月天数 ----------

  Widget _buildYearGrid(double width, double height) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final days = DateTime(_focusedMonth.year, month + 1, 0).day;
        final isSelected = _selectedDate.year == _focusedMonth.year &&
            _selectedDate.month == month;
        return InkWell(
          onTap: () => setState(() {
            _focusedMonth = DateTime(_focusedMonth.year, month);
            _selectedDate = _sameDayIn(
                _selectedDate, _focusedMonth.year, month);
            _view = CalendarView.month;
          }),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    Localizations.localeOf(context).languageCode == 'zh'
                        ? AppLocalizations.of(context)!.calMonthTitle('$month')
                        : DateFormat.MMMM(Localizations.localeOf(context)
                                .toString())
                            .format(DateTime(_focusedMonth.year, month)),
                    style: Theme.of(context).textTheme.titleSmall),
                Text(AppLocalizations.of(context)!.calDaysCount(days),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- 月视图：网格拉伸填满给定高度（不滚动，避免抢手势） ----------

  Widget _buildMonthGrid(double width, double height) {
    final first = _firstWeekdayOffset(
        DateTime(_focusedMonth.year, _focusedMonth.month, 1));
    final days =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final rows = (first + days + 6) ~/ 7;
    final cellW = (width - 16) / 7;
    final cellH = cellW == 0 ? height : height / rows;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: cellH,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - first + 1;
        if (dayNum < 1 || dayNum > days) return const SizedBox.shrink();
        final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
        return _buildDayItem(date, compact: true);
      },
    );
  }

  // ---------- 周视图：7 行日程（当前周，周日起始） ----------

  Widget _buildWeekList() {
    final start = _weekStart(_selectedDate);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = start.add(Duration(days: index));
        return _buildDayItem(date, showWeekday: true);
      },
    );
  }

  // ---------- 日视图：单日详情大字 ----------

  Widget _buildDayBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: _buildDateDetail(_selectedDate, asPanel: true, showDate: false),
      ),
    );
  }

    // ---------- 网格/日程里的单日单元 ----------

  /// 格子小字，按 [CalendarPrefs.cellLabelMode] 档位取内容。
  ///
  /// 默认档（节气+农历日）刻意不看节日：节日名在窄格子里既挤数字，
  /// 又五颜六色抢注意力；要看节日切「完整」档或节日节气页。
  String _cellText(DayInfo info) => switch (CalendarPrefs.cellLabelMode) {
        CellLabelMode.full => info.cellLabel,
        CellLabelMode.jieqiLunar =>
          info.hasJieQi ? info.jieQi : info.lunarDayText,
        CellLabelMode.lunarOnly => info.lunarDayText,
        CellLabelMode.hidden => '',
      };

  Widget _buildDayItem(DateTime date,
      {bool compact = false, bool showWeekday = false}) {
    final info = DayInfo.of(date);
    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, _today);
    final scheme = Theme.of(context).colorScheme;
    // 小字内容与着色跟着档位走：默认档只让节气亮色，节日不再抢镜。
    final cellText = _cellText(info);
    final cellHighlight = switch (CalendarPrefs.cellLabelMode) {
      CellLabelMode.full => info.hasFestival || info.hasJieQi,
      CellLabelMode.jieqiLunar => info.hasJieQi,
      _ => false,
    };

    Widget label(String text, TextStyle? base, {Color? color}) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base?.copyWith(color: color)),
        );

    return InkWell(
      onTap: () => setState(() {
        _selectedDate = date;
        _focusedMonth = DateTime(date.year, date.month);
        if (_view == CalendarView.year) _view = CalendarView.month;
      }),
      child: Container(
        margin: compact ? const EdgeInsets.all(2) : null,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : null,
          border: isToday && !isSelected
              ? Border.all(color: scheme.primary, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(compact ? 8 : 6),
        ),
        alignment: Alignment.center,
        // 数字绝不参与缩放：这里曾把「数字 + 节日名」整体套 FittedBox，
        // 节日名一长（如「南京大屠杀死难者国家公祭日」）数字跟着一起缩小。
        // 现在数字固定字号，节日名独占 Flexible 行——格子矮/名字长时
        // 只有它自己缩（FittedBox scaleDown），数字永不让步。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showWeekday)
              label(
                info.weekText,
                Theme.of(context).textTheme.labelSmall,
                color: isSelected ? scheme.onPrimary : Theme.of(context).hintColor,
              ),
            label(
              '${date.day}',
              (compact
                      ? Theme.of(context).textTheme.labelLarge
                      : Theme.of(context).textTheme.titleSmall)
                  // 收紧行高：紧凑竖屏的格子高度极小，数字行的默认行高
                  // 本身就能占满整个格子，节日名行就一像素都挤不出来了。
                  ?.copyWith(height: 1.1),
              color: isSelected ? scheme.onPrimary : null,
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  cellText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? scheme.onPrimary
                            : cellHighlight
                                ? scheme.primary
                                : Theme.of(context).hintColor,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 详情（窄屏底部栏 / 宽屏右侧面板） ----------

  Widget _buildDateDetail(DateTime date,
      {bool asPanel = false, bool showDate = true}) {
    final info = DayInfo.of(date);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final rows = <Widget>[
      if (showDate) ...[
        Text(_dateFormat.format(date), style: textTheme.titleMedium),
        const SizedBox(height: 2),
        Text('${info.weekText} · ${info.lunarDayText}', style: textTheme.bodyMedium),
        const Divider(height: 16),
      ],
      // 「节日」行与底部汇总只在「完整」档出现——默认档的日历只讲历法，
      // 不列节日（要看节日去节日节气页）。
      if (CalendarPrefs.cellLabelMode == CellLabelMode.full)
        _detailRow(l10n.calFestival, info.festivalText),
      _detailRow(l10n.mainJieQi, info.jieQiText),
      // 农历/干支/生肖是中华文化数据本身，保持中文原样，只有标签跟界面语言。
      _detailRow(
        l10n.mainLunar,
        '${info.lunar.getYearInChinese()}年'
        '${info.lunar.getMonthInChinese()}${info.lunarDayText}',
      ),
      _detailRow(l10n.mainGanZhi, info.ganZhiText),
      _detailRow(l10n.mainZodiac, info.lunar.getYearShengXiao()),
      _detailRow(l10n.calDistance, _distanceText(date)),
      if (CalendarPrefs.cellLabelMode == CellLabelMode.full &&
          (info.hasFestival || info.hasJieQi))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            [...info.festivals, if (info.hasJieQi) info.jieQi].join(' · '),
            style: textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
        ),
    ];

    if (!asPanel) return Column(children: rows);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: rows)),
    );
  }

  /// 某个日期距今天多少天；用日历天差，不看时区和小时。
  String _distanceText(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final a = DateTime(_today.year, _today.month, _today.day);
    final b = DateTime(date.year, date.month, date.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return l10n.commonToday;
    return diff > 0 ? l10n.mainInDays(diff) : l10n.calPassedDays(-diff);
  }

  Widget _detailRow(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: textTheme.labelMedium
                    ?.copyWith(color: Theme.of(context).hintColor)),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
