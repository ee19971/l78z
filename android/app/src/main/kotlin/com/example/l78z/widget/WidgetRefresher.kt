package com.example.l78z.widget

import android.appwidget.AppWidgetManager
import android.content.Context

/**
 * 一次性刷新全部倒数日部件。
 *
 * 三条链路都汇到这里：
 *  1. 应用内改数据 → Dart 调 MethodChannel → MainActivity 调这里；
 *  2. 跨天 / 改时区 / 改系统时间 → [CountdownRefreshReceiver]；
 *  3. 开机 → 同一个 receiver 收 `BOOT_COMPLETED`。
 *
 * 三条缺一不可：只靠 1 的话，明天桌面还是旧天数；只靠 2 的话，
 * 用户在应用里加的那条要等到下一次跨天才会上桌。
 */
object WidgetRefresher {

    fun refreshAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context) ?: return
        SingleDayWidget.updateAll(context, mgr)
        ListWidget.updateAll(context, mgr)
        LifeProgressWidget.updateAll(context, mgr)
    }
}
