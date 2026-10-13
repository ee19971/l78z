package com.example.l78z.widget

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 倒数日数据的原生读取层。
 *
 * 数据的真正来源是 Rust 侧的 JSON，由 Dart 经 FRB 写入；桌面部件跑在
 * launcher 进程里调不到 Rust，只能直接读同一个文件
 * （`filesDir.parentFile/app_flutter/countdown-events.json`——Android 上
 * 这正是 `getApplicationDocumentsDirectory()` 返回的目录）。
 *
 * **字段名与日期格式是与 `rust/src/api/countdown.rs` 的契约**：那边一改，
 * 这边必须同步，否则部件会静默读成空列表。
 *
 * 之所以不用 `java.time.LocalDate`：它要 API 26+，而本项目 minSdk 由
 * Flutter 默认值决定，可能更低。`Calendar` + 手动归零到当天 0 点，
 * 再对 DST 造成的非整天差值做四舍五入，足以覆盖所有版本。
 */
object CountdownStore {

    private const val FILE_NAME = "countdown-events.json"
    private const val DATE_PATTERN = "yyyy-MM-dd"

    /// 与 Rust 侧 `default_color` 一致的兜底色。
    private const val DEFAULT_COLOR = "#6750A4"

    /// 与 Rust 侧 `default_quote` 一致的默认格言。
    private const val DEFAULT_QUOTE = "今天不走，明天要跑。"

    /** 单条倒数日，字段与 Rust 侧 `CountdownEvent` 对应。 */
    data class Event(
        val id: String,
        val title: String,
        val date: String,
        /** countdown / countup / yearly，取自 Rust 的 `CountMode`。 */
        val mode: String,
        val color: String,
        val pinned: Boolean,
        val note: String,
        /** 距目标日的天数：正=还剩，负=已过，0=当天。由本类算出，不信任文件里的值。 */
        val daysLeft: Long,
    )

    /** 人生进度参数，对应 Rust 侧 `LifeProfile`。 */
    data class Life(val birthday: String, val lifespan: Int, val quote: String)

    /** 数据文件的绝对路径。 */
    fun file(context: Context): File =
        File(context.filesDir.parentFile, "app_flutter/$FILE_NAME")

    /** 读全部事件，已按「置顶优先、近者在前」排好序并算好天数。 */
    fun events(context: Context): List<Event> {
        val f = file(context)
        // 文件不存在是首次使用的正常情况；损坏则当成空，绝不抛给上层——
        // 部件崩在 launcher 里比显示空白难看得多。
        if (!f.exists()) return emptyList()
        val text = try {
            f.readText(Charsets.UTF_8)
        } catch (e: Exception) {
            return emptyList()
        }

        val root = try {
            JSONObject(text)
        } catch (e: Exception) {
            return emptyList()
        }

        val arr = root.optJSONArray("events") ?: return emptyList()
        val today = todayCalendar()
        val list = mutableListOf<Event>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val date = o.optString("date", "")
            val mode = o.optString("mode", "countdown")
            list.add(
                Event(
                    id = o.optString("id", ""),
                    title = o.optString("title", ""),
                    date = date,
                    mode = mode,
                    color = o.optString("color", DEFAULT_COLOR).ifBlank { DEFAULT_COLOR },
                    pinned = o.optBoolean("pinned", false),
                    note = o.optString("note", ""),
                    daysLeft = daysLeft(date, mode, today),
                ),
            )
        }
        // 置顶优先，其次按「离今天多远」升序——与 Rust 侧 sort_events 保持一致，
        // 否则应用内列表和桌面部件的顺序会不一样。
        list.sortWith(
            compareByDescending<Event> { it.pinned }
                .thenBy { Math.abs(it.daysLeft) },
        )
        return list
    }

    /** 读人生进度参数；没设置过或读不出来返回 null。 */
    fun life(context: Context): Life? {
        val f = file(context)
        if (!f.exists()) return null
        val text = try {
            f.readText(Charsets.UTF_8)
        } catch (e: Exception) {
            return null
        }
        val root = try {
            JSONObject(text)
        } catch (e: Exception) {
            return null
        }
        val o = root.optJSONObject("life") ?: return null
        val birthday = o.optString("birthday", "")
        val lifespan = o.optInt("lifespan", 0)
        if (birthday.isBlank() || lifespan <= 0) return null
        // 字段缺失才用默认；空串是用户明确清空，原样保留——
        // 与 Rust 侧 `#[serde(default = ...)]` 的语义一致，
        // 否则两边会对「到底有没有格言」各说各话。
        val quote = if (o.has("quote")) o.optString("quote", "") else DEFAULT_QUOTE
        return Life(birthday, lifespan, quote)
    }

    /** 按 id 找一条事件。 */
    fun eventById(context: Context, id: String): Event? =
        events(context).find { it.id == id }

    /**
     * 单日部件该显示哪一条：
     * 用户在配置页指定过就用指定的；否则退回置顶的；再没有就取排在最前的。
     */
    fun pickForWidget(context: Context, appWidgetId: Int): Event? {
        val all = events(context)
        if (all.isEmpty()) return null

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wanted = prefs.getString(keyFor(appWidgetId), null)
        if (!wanted.isNullOrBlank()) {
            all.find { it.id == wanted }?.let { return it }
        }
        // 用户删掉了配置页选中的那条：退回置顶的，再退回最近的。
        return all.firstOrNull { it.pinned } ?: all.first()
    }

    /** 记住某个部件显示哪一条事件。 */
    fun bindWidget(context: Context, appWidgetId: Int, eventId: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(keyFor(appWidgetId), eventId)
            .apply()
    }

    /** 部件被移除时清掉它的选择，免得 SharedPreferences 无限堆积。 */
    fun unbindWidget(context: Context, appWidgetId: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(keyFor(appWidgetId))
            .apply()
    }

    private fun keyFor(appWidgetId: Int): String = "single_event_$appWidgetId"

    /**
     * 「目标日减今天」的天数差：正=还剩，负=已过，0=当天。
     *
     * yearly 只认月日，指向不早于今天的那个周年。
     * 这段逻辑必须与 Rust 侧 `with_days` 一致，否则应用内和桌面会各说各话。
     */
    fun daysLeft(date: String, mode: String, today: Calendar = todayCalendar()): Long {
        val target = parseDate(date) ?: return 0L
        val real = if (mode == "yearly") nextAnniversary(today, target) else target
        return daysBetween(today, real)
    }

    /** 下一个周年，不早于 today。 */
    private fun nextAnniversary(today: Calendar, target: Calendar): Calendar {
        val month = target.get(Calendar.MONTH)
        val day = target.get(Calendar.DAY_OF_MONTH)
        val thisYear = anniversaryIn(today.get(Calendar.YEAR), month, day)
        return if (!thisYear.before(today)) {
            thisYear
        } else {
            anniversaryIn(today.get(Calendar.YEAR) + 1, month, day)
        }
    }

    /**
     * 指定年份的周年日期。
     *
     * 2 月 29 日在平年不存在，`Calendar.set` 会自动进位成 3 月 1 日，
     * 这里检查月日是否被进位改写，改写了就退回 2 月 28 日。
     */
    private fun anniversaryIn(year: Int, month: Int, day: Int): Calendar {
        val c = Calendar.getInstance()
        c.set(year, month, day, 0, 0, 0)
        c.set(Calendar.MILLISECOND, 0)
        if (c.get(Calendar.MONTH) != month || c.get(Calendar.DAY_OF_MONTH) != day) {
            c.set(year, Calendar.FEBRUARY, 28, 0, 0, 0)
            c.set(Calendar.MILLISECOND, 0)
        }
        return c
    }

    /**
     * 两个日期相差多少天。
     *
     * 先把两者都归零到当天 0 点再相减；夏令时切换会让某天多出或少掉一小时，
     * 直接整除会得到 23 或 25 小时的偏差，所以最后四舍五入。
     */
    private fun daysBetween(from: Calendar, to: Calendar): Long {
        val a = atMidnight(from)
        val b = atMidnight(to)
        val diff = b.timeInMillis - a.timeInMillis
        return Math.round(diff.toDouble() / (24.0 * 3600 * 1000))
    }

    private fun atMidnight(c: Calendar): Calendar {
        val copy = c.clone() as Calendar
        copy.set(Calendar.HOUR_OF_DAY, 0)
        copy.set(Calendar.MINUTE, 0)
        copy.set(Calendar.SECOND, 0)
        copy.set(Calendar.MILLISECOND, 0)
        return copy
    }

    /** 当天 0 点。 */
    fun todayCalendar(): Calendar = atMidnight(Calendar.getInstance())

    /** 大数字：按模式取绝对值。与 Dart 侧 `_dayNumber` 一致。 */
    fun dayNumber(ev: Event): String = Math.abs(ev.daysLeft).toString()

    /**
     * 状态词：还剩 / 已过 / 还有 / 距下次 / 就是今天。
     *
     * 与 Dart 侧 `_statusLabel` 逐字对应——应用内列表和桌面部件说的是同一句话，
     * 改文案必须两边一起改。
     */
    fun statusLabel(ev: Event): String {
        val d = ev.daysLeft
        return when (ev.mode) {
            "countup" -> when {
                d < 0 -> "已过"
                d == 0L -> "就是今天"
                else -> "还有"
            }
            "yearly" -> if (d > 0) "距下次" else "就是今天"
            else -> when {
                d > 0 -> "还剩"
                d == 0L -> "就是今天"
                else -> "已过"
            }
        }
    }

    /** 人生进度的计算结果，字段与 Rust 侧 `LifeProgress` 对应。 */
    data class LifeProgress(
        val livedDays: Long,
        val totalDays: Double,
        val percent: Double,
        val daysLeft: Long,
    )

    /**
     * 计算人生进度；生日解析不了或明显不合理时返回 null。
     *
     * 总天数用 365.2425（回归年平均长度）折算，与 Rust 侧一致——直接乘 365
     * 会让每四年少算的那一天累积成肉眼可见的误差。
     */
    fun lifeProgress(life: Life, today: Calendar = todayCalendar()): LifeProgress? {
        val born = parseDate(life.birthday) ?: return null
        // 出生日期晚于今天说明数据是错的，算出来的负天数没有任何意义。
        if (born.after(today) || life.lifespan <= 0) return null
        val lived = daysBetween(born, today)
        val total = life.lifespan * 365.2425
        // 超过预期寿命时允许大于 100——那本身是有意义的信息。
        val percent = (lived.toDouble() / total * 100.0).coerceIn(0.0, 999.0)
        val left = (total - lived.toDouble()).coerceAtLeast(0.0).toLong()
        return LifeProgress(lived, total, percent, left)
    }

    /**
     * 「今天 / 本周 / 本月 / 本年」四条的已过百分比，顺序与部件布局的四行一致。
     *
     * 口径是「当前时刻落在该周期的哪个位置」，而不是「今天过了第几天」——
     * 例如 10 月 12 日 17:15 是本月第 12 天 17 小时，除以全月 744 小时得
     * 37.9%，与常见日历应用的显示一致。周从**周日**起算。
     */
    fun periodPercents(now: Calendar = Calendar.getInstance()): List<Double> {
        val today = atMidnight(now)

        val dayStart = today
        val dayEnd = addDays(today, 1)

        // Calendar.DAY_OF_WEEK 里周日 = 1，减 (dow - 1) 天正好回到本周日。
        val weekStart = addDays(today, -(today.get(Calendar.DAY_OF_WEEK) - 1))
        val weekEnd = addDays(weekStart, 7)

        val monthStart = (today.clone() as Calendar).apply {
            set(Calendar.DAY_OF_MONTH, 1)
        }
        val monthEnd = addDays(monthStart, 0).apply { add(Calendar.MONTH, 1) }

        val yearStart = (today.clone() as Calendar).apply {
            set(Calendar.DAY_OF_YEAR, 1)
        }
        val yearEnd = (yearStart.clone() as Calendar).apply { add(Calendar.YEAR, 1) }

        return listOf(
            percentBetween(dayStart, dayEnd, now),
            percentBetween(weekStart, weekEnd, now),
            percentBetween(monthStart, monthEnd, now),
            percentBetween(yearStart, yearEnd, now),
        )
    }

    /** 当前时刻在 [start, end) 内已过去的百分比；区间退化时返回 0。 */
    private fun percentBetween(start: Calendar, end: Calendar, now: Calendar): Double {
        val total = end.timeInMillis - start.timeInMillis
        if (total <= 0) return 0.0
        val done = now.timeInMillis - start.timeInMillis
        return (done.toDouble() / total * 100.0).coerceIn(0.0, 100.0)
    }

    private fun addDays(base: Calendar, days: Int): Calendar =
        (base.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, days) }

    /** 默认格言，供部件在用户没设置时兜底。与 Rust 侧 `default_quote` 同一句。 */
    fun defaultQuote(): String = DEFAULT_QUOTE

    /** 解析 `yyyy-MM-dd`；格式不对返回 null，由调用方决定怎么兜底。 */
    private fun parseDate(s: String): Calendar? {
        if (s.isBlank()) return null
        return try {
            val fmt = SimpleDateFormat(DATE_PATTERN, Locale.US)
            fmt.timeZone = TimeZone.getDefault()
            val d: Date = fmt.parse(s.trim()) ?: return null
            Calendar.getInstance().apply { time = d }.let { atMidnight(it) }
        } catch (e: Exception) {
            null
        }
    }

    private const val PREFS_NAME = "countdown_widget"
}
