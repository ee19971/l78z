package com.example.l78z.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.TextView
import com.example.l78z.R

/**
 * 单日部件的配置页——**原生 Activity，不是 Flutter 页**。
 *
 * 系统在用户把部件拖到桌面时拉起它，必须在几百毫秒内画出来；起一个
 * FlutterEngine 会先白屏一下，还得为「只显示几行列表」付上一整套渲染开销。
 *
 * 两个硬性要求，缺一个部件就加不上：
 *  1. Manifest 里 `exported="true"` 并带 `APPWIDGET_CONFIGURE` 过滤器；
 *  2. 用户确认后必须 `setResult(RESULT_OK, Intent 含 EXTRA_APPWIDGET_ID)`
 *     再 finish——系统靠这个返回值判断配置是否完成。
 */
class SingleDayConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    /** 用户选中的事件 id；没选时为 null，确认后就不做绑定，让部件按默认规则取。 */
    private var selectedId: String? = null

    private lateinit var events: List<CountdownStore.Event>
    private lateinit var adapter: RowAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 先声明「取消」：若中途异常退出或用户按返回，系统会当成配置未完成，
        // 部件不会被添加到桌面。这是 Android 配置页的默认约定。
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.single_day_config_activity)

        events = CountdownStore.events(this)
        // 默认选中：这个 widget 上次绑过的（重复进入配置页时），否则置顶的，再退回第一条。
        selectedId = CountdownStore.pickForWidget(this, appWidgetId)?.id

        val empty = findViewById<TextView>(R.id.empty_hint)
        val list = findViewById<ListView>(R.id.event_list)
        if (events.isEmpty()) {
            list.visibility = View.GONE
            empty.visibility = View.VISIBLE
        }

        adapter = RowAdapter()
        list.adapter = adapter
        list.setOnItemClickListener { _, _, position, _ ->
            selectedId = events[position].id
            adapter.notifyDataSetChanged()
        }

        findViewById<Button>(R.id.btn_confirm).setOnClickListener { confirm() }
    }

    private fun confirm() {
        selectedId?.let { CountdownStore.bindWidget(this, appWidgetId, it) }

        // 把 widget id 原样带回给系统，否则它判定配置没完成，部件不会真正添加。
        val data = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, data)

        // 立刻画一次，让部件在配置页消失的瞬间就有内容，而不是等下一次广播。
        AppWidgetManager.getInstance(this)?.let { mgr ->
            SingleDayWidget.updateOne(this, mgr, appWidgetId)
        }
        finish()
    }

    /** 行视图：选中的那条右侧亮出对勾。 */
    private inner class RowAdapter : BaseAdapter() {

        override fun getCount() = events.size

        override fun getItem(position: Int) = events[position]

        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val view = convertView
                ?: layoutInflater.inflate(R.layout.countdown_config_item, parent, false)
            val ev = events[position]

            view.findViewById<TextView>(R.id.item_title).text = ev.title
            view.findViewById<TextView>(R.id.item_meta).text =
                "${CountdownStore.dayNumber(ev)} 天 · ${CountdownStore.statusLabel(ev)} · ${ev.date}"
            view.findViewById<TextView>(R.id.item_check).visibility =
                if (ev.id == selectedId) View.VISIBLE else View.GONE
            return view
        }
    }
}
