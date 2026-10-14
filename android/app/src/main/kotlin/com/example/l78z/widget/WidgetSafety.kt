package com.example.l78z.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.util.Log
import android.widget.RemoteViews
import com.example.l78z.R

/**
 * 部件安全网：任何异常都不许冒泡到 launcher。
 *
 * 部件跑在桌面进程里，`AppWidgetProvider.onUpdate` 一旦抛异常，用户看到的
 * 就是系统的「载入窗口小部件时出现问题」——难看且无从排查。这里统一兜底：
 * 异常时渲染该部件的初始布局（自带占位内容），至少不是报错弹窗。
 */
object WidgetSafety {

    private const val TAG = "WidgetSafety"

    /**
     * 把 [block] 包进 try-catch；异常时用 [layoutRes] 的初始布局兜底渲染。
     *
     * 兜底本身也再兜一层：连 RemoteViews 都建不出来（资源被裁剪等极端情况）
     * 就放弃更新，绝不能二次抛出。
     */
    fun guard(
        context: Context,
        mgr: AppWidgetManager,
        id: Int,
        layoutRes: Int,
        block: () -> Unit,
    ) {
        try {
            block()
        } catch (t: Throwable) {
            Log.e(TAG, "widget $id update failed, rendering fallback", t)
            try {
                mgr.updateAppWidget(id, RemoteViews(context.packageName, layoutRes))
            } catch (t2: Throwable) {
                Log.e(TAG, "widget $id fallback also failed", t2)
            }
        }
    }
}
