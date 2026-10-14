package com.example.l78z.widget

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.example.l78z.R

/**
 * 倒数日列表部件的供数 Service。
 *
 * 为什么不能直接 setText：RemoteViews 跨进程只传「操作指令」，不传对象；
 * ListView 的每一行长什么样只能由持有真实数据的这一侧（我们这个进程）
 * 造出来交给它。所以必须实现 [RemoteViewsService]，由 launcher 反复回调
 * [RemoteViewsFactory.getViewAt] 来取行。
 *
 * `BIND_REMOTEVIEWS` 权限在 Manifest 里声明——没有它，系统会拒绝绑定。
 */
class CountdownListService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    private inner class Factory(private val ctx: Context) : RemoteViewsFactory {

        /** 当前显示的数据。onDataSetChanged 在后台线程跑，这里读文件没问题。 */
        private var data: List<CountdownStore.Event> = emptyList()

        override fun onCreate() = Unit

        override fun onDataSetChanged() {
            // 数据层已全程兜底，这里是最后的保险丝：列表部件绝不能因数据
            // 异常在 launcher 侧崩掉。
            data = try {
                CountdownStore.events(ctx)
            } catch (t: Throwable) {
                emptyList()
            }
        }

        override fun onDestroy() {
            data = emptyList()
        }

        override fun getCount() = data.size

        override fun getViewAt(position: Int): RemoteViews? {
            val ev = data.getOrNull(position) ?: return null
            return try {
                val views = RemoteViews(ctx.packageName, R.layout.countdown_list_item)
                views.setTextViewText(R.id.item_number, CountdownStore.dayNumber(ev))
                views.setTextViewText(R.id.item_title, ev.title)
                views.setTextViewText(
                    R.id.item_meta,
                    "${CountdownStore.statusLabel(ev)} · ${ev.date}",
                )
                // 必须给每行一个 fillInIntent，否则点击整行没有反应：
                // 它会和 Provider 侧的模板 PendingIntent 合并成最终的点击行为。
                views.setOnClickFillInIntent(R.id.row, Intent())
                views
            } catch (t: Throwable) {
                // 单行渲染失败就跳过该行，别把整个列表带崩。
                null
            }
        }

        /** 没有骨架屏时返回 null，列表会用普通的空行占位。 */
        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount() = 1

        override fun getItemId(position: Int) = position.toLong()

        override fun hasStableIds() = true
    }
}
