package com.example.l78z.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.l78z.MainActivity
import com.example.l78z.R

/**
 * 单日倒数部件：桌面只显示一条事件的天数。
 *
 * 哪一条由用户在 [SingleDayConfigActivity] 里选定，按 widget id 记在
 * SharedPreferences 里；没选过就退回置顶的、再退回最靠前的那条。
 *
 * 数据来自 [CountdownStore] 直接读 Rust 写的 JSON——本进程调不到 Rust，
 * 也不需要调，读的是同一个文件。
 */
class SingleDayWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateOne(context, mgr, id)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // 部件被拖走时清掉它记住的选择，否则 SharedPreferences 只增不减。
        for (id in appWidgetIds) CountdownStore.unbindWidget(context, id)
    }

    companion object {

        /** 刷新所有已添加的单日部件（应用内数据变更、跨天、开机都走这里）。 */
        fun updateAll(context: Context, mgr: AppWidgetManager) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, SingleDayWidget::class.java))
            for (id in ids) updateOne(context, mgr, id)
        }

        fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            // 异常冒泡到 launcher 就是系统的「载入窗口小部件时出现问题」，
            // 统一走 WidgetSafety 兜底（onUpdate / updateAll / 配置页确认
            // 全部经由这里，一处兜住三条链路）。
            WidgetSafety.guard(context, mgr, id, R.layout.single_day_widget) {
                val views = RemoteViews(context.packageName, R.layout.single_day_widget)
                val ev = CountdownStore.pickForWidget(context, id)

                if (ev == null) {
                    // 一条都没有：把选择引导写上去，比留一片空白有用。
                    views.setTextViewText(R.id.title, context.getString(R.string.widget_config_title))
                    views.setTextViewText(R.id.number, "—")
                    views.setTextViewText(R.id.caption, "")
                    views.setTextViewText(R.id.date, context.getString(R.string.widget_config_empty))
                } else {
                    views.setTextViewText(R.id.title, ev.title)
                    views.setTextViewText(R.id.number, CountdownStore.dayNumber(ev))
                    views.setTextViewText(R.id.caption, "天")
                    views.setTextViewText(
                        R.id.date,
                        "${CountdownStore.statusLabel(ev)} · ${ev.date}",
                    )
                }

                // 点部件打开应用。按 widget id 各建一个 PendingIntent：
                // 多个部件共用同一个 requestCode 的话，后建的会把前一个覆盖掉。
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pi = PendingIntent.getActivity(
                    context,
                    id,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
                mgr.updateAppWidget(id, views)
            }
        }
    }
}
