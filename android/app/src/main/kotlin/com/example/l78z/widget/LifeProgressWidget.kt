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
 * 人生进度部件：顶部格言 + 四条彩色进度条（今天 / 本周 / 本月 / 本年）。
 *
 * 取色与应用内「人生进度」页保持一致：今天绿、本周蓝、本月橙、本年紫。
 * 进度口径是「当前时刻落在该周期的哪个位置」，见
 * [CountdownStore.periodPercents]——与应用内那页必须一致，否则用户会
 * 发现桌面和应用里同一条对不上。
 */
class LifeProgressWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateOne(context, mgr, id)
    }

    companion object {

        fun updateAll(context: Context, mgr: AppWidgetManager) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, LifeProgressWidget::class.java))
            for (id in ids) updateOne(context, mgr, id)
        }

        fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            // 异常冒泡到 launcher = 系统的「载入窗口小部件时出现问题」，
            // 统一走 WidgetSafety 兜底（onUpdate / updateAll 都经由这里）。
            WidgetSafety.guard(context, mgr, id, R.layout.life_progress_widget) {
                val views = RemoteViews(context.packageName, R.layout.life_progress_widget)
                val life = CountdownStore.life(context)
                val pcts = CountdownStore.periodPercents()

                // 格言：设置过就用用户的（空串是用户主动清空，留白即可），
                // 从没设置过才退回默认那句——留空会让部件顶部塌掉一块。
                val quote = if (life == null) {
                    CountdownStore.defaultQuote()
                } else {
                    life.quote
                }
                views.setTextViewText(R.id.quote, quote)

                // max=1000 而非 100：百分比要显示两位小数，而 setProgressBar 只吃
                // 整数，千分位才够把 0.01% 的差别体现出来。
                bindBar(views, R.id.bar_day, R.id.pct_day, pcts[0])
                bindBar(views, R.id.bar_week, R.id.pct_week, pcts[1])
                bindBar(views, R.id.bar_month, R.id.pct_month, pcts[2])
                bindBar(views, R.id.bar_year, R.id.pct_year, pcts[3])

                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pi = PendingIntent.getActivity(
                    context,
                    id + 0x1000, // 与单日/列表部件的 requestCode 错开，避免互相覆盖
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
                mgr.updateAppWidget(id, views)
            }
        }

        private fun bindBar(views: RemoteViews, barId: Int, pctId: Int, percent: Double) {
            views.setProgressBar(barId, 1000, (percent * 10).toInt(), false)
            views.setTextViewText(pctId, "%.2f%%".format(percent))
        }
    }
}
