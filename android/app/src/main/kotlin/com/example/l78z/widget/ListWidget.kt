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
 * 倒数日列表部件。
 *
 * 整份列表拼成一个 TextView 的多行文本，只走 [RemoteViews.setTextViewText]
 * 这一条指令。这里踩过三个坑，前两个是 HyperOS 桌面（Flutter/Rust 渲染，
 * 只实现了基础 RemoteViews 指令子集）不认：
 *  1. ListView + RemoteViewsService（setRemoteAdapter 供数）→ 部件位置直接
 *     显示「载入窗口小部件时出现问题」；
 *  2. RemoteViews.addView 动态拼子行 → 同样报错；
 *  3. ⚠ 布局引用**绝不能**抽成 `const val`：曾经写
 *     `const val LIST_LAYOUT = R.layout.countdown_list_widget`，R8 优化后
 *     该常量字段的值出错（dex 里连真实资源 id 的字节都搜不到），
 *     RemoteViews 拿到 layoutId=0，launcher INFLATE 直接失败——
 *     这个坑排查了很久，因为刷新路径「看起来能用」而 picker 添加必炸。
 *     必须像单日/人生部件那样直接写 `R.layout.countdown_list_widget`，
 *     让 R8 把正确值内联进字节码。
 *
 * 部件类名是 ListWidget（非 CountdownListWidget）：排查过程中为排除
 * 「HyperOS 按组件名拉黑」假说而改名，假说虽被否定，但桌面实例已按新
 * 组件名工作，改回旧名只会让用户重新删卡重加，故保留。
 */
class ListWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateOne(context, mgr, id)
    }

    companion object {

        /** 刷新所有已添加的列表部件。 */
        fun updateAll(context: Context, mgr: AppWidgetManager) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, ListWidget::class.java))
            for (id in ids) updateOne(context, mgr, id)
        }

        fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            // 异常冒泡到 launcher = 系统的「载入窗口小部件时出现问题」，
            // 统一走 WidgetSafety 兜底（onUpdate / updateAll 都经由这里）。
            // ⚠ 布局引用必须直接写 R.layout.countdown_list_widget，与单日/
            // 人生部件同款：曾经抽成 `const val` 后 R8 优化出错的常量值，
            // RemoteViews 拿到 layoutId=0，HyperOS launcher INFLATE 直接
            // 失败——详见类注释第 3 条坑。
            WidgetSafety.guard(context, mgr, id, R.layout.countdown_list_widget) {
                val views = RemoteViews(context.packageName, R.layout.countdown_list_widget)

                // 按当前高度算放得下几行：标题 + 上下 padding 约占 44dp，
                // 每行文字约 18dp + 行距 6dp ≈ 24dp，留点余量按 28dp 算；
                // resize 后系统会再回调 onUpdate 重算。
                val hDp = mgr.getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 150)
                val rows = ((hDp - 44) / 28).coerceIn(1, 8)

                views.setTextViewText(
                    R.id.list_text,
                    buildListText(context, CountdownStore.events(context).take(rows)),
                )

                // 整个部件点击打开应用（多行文本无法逐行命中，整卡响应最稳）。
                val pi = PendingIntent.getActivity(
                    context,
                    id + 0x2000, // 与单日/进度部件错开 requestCode，避免互相覆盖
                    Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)

                mgr.updateAppWidget(id, views)
            }
        }

        /**
         * 拼多行列表文本：每行「天数 + 全角空格 + 状态 · 日期」。
         *
         * 返回纯 String，**绝不能带 Spannable 富文本**：HyperOS launcher 用
         * 自己的 Rust 解析器处理 RemoteViews，只认纯字符串序列化，
         * 带 span 的 CharSequence 会让整个部件渲染失败（错误卡）。
         * 单日/人生进度部件能正常显示，正是因为它们传的都是纯 String。
         * 空列表时给引导文案。
         */
        private fun buildListText(
            context: Context,
            events: List<CountdownStore.Event>,
        ): String {
            if (events.isEmpty()) return context.getString(R.string.widget_config_empty)
            return events.joinToString("\n") { ev ->
                "${CountdownStore.dayNumber(ev)}　　${CountdownStore.statusLabel(ev)} · ${ev.date}"
            }
        }
    }
}
