package com.example.l78z.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 跨天与开机的部件刷新。
 *
 * `updatePeriodMillis` 的系统下限是 30 分钟，指望它「每天 0 点更新」既不准
 * 也费电。而 `ACTION_DATE_CHANGED` 在日期翻转那一刻必定送达，时区变更、
 * 手动改系统时间也各有对应广播——这三条才是「桌面天数不会过期」的真正保证。
 *
 * `BOOT_COMPLETED` 单独列出来：部分 ROM 在重启后不会重放 APPWIDGET_UPDATE，
 * 靠系统自己恢复的话，部件可能一直空着。
 *
 * 这几个 action 都是系统保护广播，第三方应用只能接收、不能发送。
 */
class CountdownRefreshReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        WidgetRefresher.refreshAll(context)
    }
}
