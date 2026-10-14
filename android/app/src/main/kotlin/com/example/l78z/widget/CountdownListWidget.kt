package com.example.l78z.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.example.l78z.MainActivity
import com.example.l78z.R

/**
 * 倒数日列表部件。
 *
 * RemoteViews 只是一串跨进程指令，launcher 拿不到本应用的 List 对象，
 * 所以 ListView 必须由 [CountdownListService] 逐行供数——见该类注释。
 */
class CountdownListWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateOne(context, mgr, id)
    }

    companion object {

        private const val LIST_LAYOUT = R.layout.countdown_list_widget

        /** 刷新所有已添加的列表部件。 */
        fun updateAll(context: Context, mgr: AppWidgetManager) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, CountdownListWidget::class.java))
            for (id in ids) updateOne(context, mgr, id)
        }

        fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            // 异常冒泡到 launcher = 系统的「载入窗口小部件时出现问题」，
            // 统一走 WidgetSafety 兜底（onUpdate / updateAll 都经由这里）。
            WidgetSafety.guard(context, mgr, id, LIST_LAYOUT) {
                val views = RemoteViews(context.packageName, LIST_LAYOUT)

                // Intent 必须带互不相同的 data URI：多个部件用同一个（action+component
                // 相同）Intent 时，系统会把它们当成同一个 Service 绑定，A 部件就会
                // 读到 B 部件的 appWidgetId。
                val serviceIntent = Intent(context, CountdownListService::class.java).apply {
                    data = Uri.parse("countdown-widget://list/$id")
                }
                views.setRemoteAdapter(R.id.list_view, serviceIntent)
                views.setEmptyView(R.id.list_view, R.id.empty_view)

                // 整行点击的模板 PendingIntent。列表项那边用 setOnClickFillInIntent
                // 填充进来；模板本身指向应用主页，点任何一行都打开应用。
                val openApp = PendingIntent.getActivity(
                    context,
                    id + 0x2000, // 与单日/进度部件错开 requestCode，避免互相覆盖
                    Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setPendingIntentTemplate(R.id.list_view, openApp)

                mgr.updateAppWidget(id, views)
                // 数据可能已经变了，让 Service 重新 onDataSetChanged()。
                mgr.notifyAppWidgetViewDataChanged(id, R.id.list_view)
            }
        }
    }
}
