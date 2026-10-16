import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/config.dart';
import '../src/rust/api/transfer.dart';
import 'ocr_download.dart';

/// 应用配置文件路径。
///
/// 配置由 Rust 侧读写（端口、设备名最终都要交给传输服务），这里只是把
/// 文件位置定下来，让设置页和其他页面用同一份数据。
Future<String> configFilePath() async {
  final docs = await getApplicationDocumentsDirectory();
  return '${docs.path}/l78z_config.json';
}

/// 读取应用配置；文件不存在时 Rust 侧返回默认值。
Future<AppConfig> loadAppConfig() async =>
    loadConfig(path: await configFilePath());

/// 保存应用配置。
Future<AppConfig> saveAppConfig(AppConfig cfg) async =>
    saveConfig(path: await configFilePath(), cfg: cfg);

/// 与原生层通信：调起系统相机。
const MethodChannel _cameraChannel = MethodChannel('com.example.l78z/camera');

/// 调起系统相机拍一张照，返回照片路径；用户取消时返回 null。
///
/// 交给系统相机而不是应用内实时预览：省掉一整套相机权限申请与预览生命周期，
/// 拍出来的照片分辨率也远高于预览帧——二维码和小字识别都吃原始清晰度。
Future<String?> takePicture() async {
  if (!Platform.isAndroid) return null;
  try {
    return await _cameraChannel.invokeMethod<String>('takePicture');
  } on PlatformException catch (e) {
    // 用户按返回取消了，不算错误，让调用方安静地结束。
    if (e.code == 'CANCELLED') return null;
    rethrow;
  }
}

/// 解码后的 RGBA 图像。
class RgbaImage {
  final Uint8List pixels;
  final int width;
  final int height;

  const RgbaImage(this.pixels, this.width, this.height);
}

/// 用 dart:ui 把图片文件解码为 RGBA8 像素（交给 Rust 侧识别/OCR）。
Future<RgbaImage> decodeRgbaFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return decodeRgbaBytes(bytes);
}

/// 用 dart:ui 把内存图片字节解码为 RGBA8 像素。
Future<RgbaImage> decodeRgbaBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) {
    throw Exception('图像解码失败');
  }
  // 只取 ByteData 声明的那段区间：底层 buffer 更大时，
  // 直接用 buffer 会多传字节，Rust 侧的长度校验会直接拒绝。
  return RgbaImage(
    bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes),
    image.width,
    image.height,
  );
}

/// 传给 Rust 的 OCR 模型目录：固定为应用文档目录下的 l78z_ocr。
///
/// 随包的小文件（字典 + 分类模型）在这里解包；两个大 onnx 不进安装包，
/// 由调用方用 `missingOcrAssets` 检查、征求用户同意后联网下载
/// （见 ocr_download.dart，字节数表也移过去了）。
///
/// [onProgress] 收到 0.0~1.0 的解包进度。小文件总量不到 1MB，进度
/// 一闪而过；真正的下载进度由 scan_page 单独呈现。
Future<String> ensureOcrModelDir({
  void Function(double progress)? onProgress,
}) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/l78z_ocr');
  await dir.create(recursive: true);

  final total = ocrBundledAssets.fold<int>(0, (a, n) => a + ocrAssetSizes[n]!);
  var done = 0;

  for (final name in ocrBundledAssets) {
    final f = File('${dir.path}/$name');
    // 已存在且长度一致才跳过，长度不对当场重解（半截文件不能留）。
    // 注意必须先写 .part 再改名：
    // 直接写目标文件时，应用中途被杀会留下半截文件，
    // 下次又因为「已存在」被跳过，之后 Rust 每次都会加载到损坏的模型。
    if (await f.exists() && await f.length() == ocrAssetSizes[name]) {
      done += ocrAssetSizes[name]!;
      onProgress?.call((done / total).clamp(0.0, 1.0));
      continue;
    }
    final data = await rootBundle.load('assets/ocr/$name');
    // 用 offsetInBytes/lengthInBytes 取真实区间，避免 ByteData 底层
    // 缓冲区比数据本身大时把多余字节一起写进模型文件。
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (bytes.isEmpty) {
      throw StateError('模型资产读取为空: assets/ocr/$name');
    }

    // 分块写入、边写边报进度。一次性写 76MB 中间没有任何反馈，
    // 正是「以为死机了」的来源。
    final part = File('${dir.path}/$name.part');
    final sink = part.openWrite();
    try {
      const chunk = 4 * 1024 * 1024;
      for (var off = 0; off < bytes.length; off += chunk) {
        final end = math.min(off + chunk, bytes.length);
        // 用 view 而不是 sublist：避免每块再复制一份 4MB
        sink.add(Uint8List.view(bytes.buffer, bytes.offsetInBytes + off, end - off));
        done += end - off;
        onProgress?.call((done / total).clamp(0.0, 1.0));
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (await f.exists()) await f.delete();
    await part.rename(f.path);
    if (await f.length() != bytes.length) {
      throw StateError('模型文件写入不完整: ${f.path}');
    }
  }
  onProgress?.call(1.0);
  return dir.path;
}

/// 倒数日数据文件路径。
///
/// 桌面小部件的 Kotlin 侧读的是同一个文件，那边拼的是
/// `filesDir.parentFile/app_flutter/countdown-events.json`——在 Android 上
/// `getApplicationDocumentsDirectory()` 正是这个目录。改路径前先确认两边
/// 仍然对得上，否则 widget 会静默读成空列表。
Future<String> countdownFilePath() async {
  final docs = await getApplicationDocumentsDirectory();
  return '${docs.path}/countdown-events.json';
}

/// 通知原生层刷新桌面小部件。
///
/// widget 跑在 launcher 进程里，看不见 Rust 的写入动作，必须由这里敲一下，
/// 否则桌面上会一直挂着改之前的天数。
Future<void> refreshCountdownWidgets() async {
  if (!Platform.isAndroid) return;
  try {
    await _widgetChannel.invokeMethod('refresh');
  } on MissingPluginException {
    // 原生侧尚未注册该 channel（或当前平台没有实现），不算错误。
  } on PlatformException {
    // 刷新失败不该回滚应用内已经完成的保存。
  }
}

/// 倒数日小部件的原生通道。
const MethodChannel _widgetChannel =
    MethodChannel('com.example.l78z/countdown_widget');

/// 扫码配对结果的全局暂存（扫码页 → 传输页）。
class PairedDevice {
  static ConnectInfo? value;
}
