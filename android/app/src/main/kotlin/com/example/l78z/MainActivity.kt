package com.example.l78z

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException

class MainActivity : FlutterActivity() {

    /** 等待系统相机返回时暂存的结果回调。 */
    private var cameraResult: MethodChannel.Result? = null

    /** 相机要写入的目标文件，回调时用来校验是否真的拍到了。 */
    private var cameraOutput: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePicture" -> takePicture(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refresh" -> {
                        // 应用内改完倒数日数据后由 Dart 敲一下，把变更同步到桌面。
                        // 桌面部件跑在 launcher 进程，看不见 Rust 的写入动作，
                        // 不敲这一下它会一直挂着改之前的天数。
                        // 刷新失败也不该让 Dart 侧已经落盘的保存回滚，所以照常 success。
                        try {
                            com.example.l78z.widget.WidgetRefresher.refreshAll(this)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        if (path.isNullOrBlank() || name.isNullOrBlank()) {
                            result.error("ARGS", "缺少 path/name 参数", null)
                        } else {
                            try {
                                result.success(saveToDownloads(path, name))
                            } catch (e: Exception) {
                                result.error("SAVE", e.message ?: e.javaClass.simpleName, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 调起系统相机拍一张照，存进应用缓存目录，返回文件路径。
     *
     * 用系统相机而不是应用内实时预览：省掉一整套相机权限申请与预览生命周期，
     * 拍出来的照片分辨率也远高于预览帧——二维码、小字识别都需要原始清晰度。
     */
    private fun takePicture(result: MethodChannel.Result) {
        if (cameraResult != null) {
            result.error("BUSY", "上一次拍照还没返回", null)
            return
        }

        val dir = File(cacheDir, "l78z_camera")
        if (!dir.exists() && !dir.mkdirs()) {
            result.error("IO", "无法创建拍照目录: $dir", null)
            return
        }
        val file = File(dir, "shot_${System.currentTimeMillis()}.jpg")
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)

        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        if (intent.resolveActivity(packageManager) == null) {
            result.error("NO_CAMERA", "这台设备上找不到可用的相机应用", null)
            return
        }

        cameraResult = result
        cameraOutput = file
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQ_CAPTURE)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_CAPTURE) return

        val result = cameraResult ?: return
        cameraResult = null
        val file = cameraOutput
        cameraOutput = null

        if (resultCode == RESULT_OK && file != null && file.exists() && file.length() > 0) {
            result.success(file.absolutePath)
        } else {
            // 用户按返回取消了，或者相机压根没把文件写出来
            file?.delete()
            result.error("CANCELLED", "拍照未完成", null)
        }
    }

    /**
     * 把 [srcPath] 搬进系统「下载/l78z」目录，返回最终可读路径。
     *
     * Rust 侧只能写应用私有目录，而私有目录在文件管理器里是看不到的，
     * 所以收到文件后立刻搬到公共下载目录，成功后删除源文件。
     */
    private fun saveToDownloads(srcPath: String, fileName: String): String {
        val src = File(srcPath)
        if (!src.exists()) throw FileNotFoundException("源文件不存在: $srcPath")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(src, fileName)
        } else {
            saveLegacy(src, fileName)
        }
    }

    /** Android 10+：MediaStore.Downloads，无需任何存储权限。 */
    private fun saveViaMediaStore(src: File, fileName: String): String {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeTypeOf(fileName))
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/l78z")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri: Uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("创建下载记录失败")

        try {
            contentResolver.openOutputStream(uri)?.use { out ->
                src.inputStream().use { it.copyTo(out) }
            } ?: throw IOException("无法打开输出流")
            contentResolver.update(
                uri,
                ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                null,
                null
            )
        } catch (e: Exception) {
            runCatching { contentResolver.delete(uri, null, null) }
            throw e
        }

        // 重名时 MediaStore 会自动改名，必须回查真实路径，否则日志里指向的文件不存在
        val dest = queryDataPath(uri) ?: "${Environment.DIRECTORY_DOWNLOADS}/l78z/$fileName"
        src.delete()
        return dest
    }

    /** Android 9 及以下：直接写公共下载目录（需 WRITE_EXTERNAL_STORAGE）。 */
    @Suppress("DEPRECATION")
    private fun saveLegacy(src: File, fileName: String): String {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "l78z"
        )
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("无法创建目录（缺少 WRITE_EXTERNAL_STORAGE 权限）: $dir")
        }
        val dest = File(dir, fileName)
        src.copyTo(dest, overwrite = true)
        src.delete()
        return dest.absolutePath
    }

    @Suppress("DEPRECATION")
    private fun queryDataPath(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null
            }

    private fun mimeTypeOf(name: String): String {
        return when (name.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "bmp" -> "image/bmp"
            "svg" -> "image/svg+xml"
            "mp4" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "wav" -> "audio/wav"
            "pdf" -> "application/pdf"
            "txt" -> "text/plain"
            "zip" -> "application/zip"
            "7z" -> "application/x-7z-compressed"
            "rar" -> "application/vnd.rar"
            "gz" -> "application/gzip"
            "apk" -> "application/vnd.android.package-archive"
            "json" -> "application/json"
            "html", "htm" -> "text/html"
            "csv" -> "text/csv"
            else -> "application/octet-stream"
        }
    }

    companion object {
        private const val CHANNEL = "com.example.l78z/storage"
        private const val CAMERA_CHANNEL = "com.example.l78z/camera"

        /** 倒数日部件的刷新通道，Dart 侧 frb_util.dart 用同一个名字。 */
        private const val WIDGET_CHANNEL = "com.example.l78z/countdown_widget"

        private const val REQ_CAPTURE = 0x4C37 // 'L7'
    }
}
