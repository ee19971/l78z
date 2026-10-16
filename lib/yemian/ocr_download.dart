/// OCR 模型文件的下载与就位。
///
/// 安装包只带字典和分类小模型，两个大 onnx（约 132MB）在首次使用 OCR 时
/// 从 ModelScope 官方直链下载（见 README「OCR 模型说明」）。规则：
/// - 始终写 `.part` 临时文件，整文件 SHA-256 校验通过才改名成成品，
///   任何时刻中断都不会留下半截「成品」；
/// - 已有 `.part` 时带 `Range` 头断点续传，服务器不支持（回 200）则
///   自动从头下载，416 则交给校验环节处置；
/// - 校验和来自 Rust 侧 rapidocr-core 官方常量，与 `ocr_status`
///   检查的是同一批文件，下载完成后 Rust 侧直接认。
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../src/rust/api/ocr.dart';

/// 各模型文件的字节数，用于进度折算与「长度快检」。
///
/// Rust 侧的下载规格没有字节数字段，这里补上。数字失配最多让进度条
/// 比例不对（下载器会因长度不符自动重下），最终以 SHA-256 为准。
const Map<String, int> ocrAssetSizes = {
  'PP-OCRv6_det_medium.onnx': 62119454,
  'PP-OCRv6_rec_medium.onnx': 76629984,
  'ch_ppocr_mobile_v2.0_cls_mobile.onnx': 585532,
  'ppocrv6_dict.txt': 74947,
};

/// 随安装包打包的小文件，首启时解包到模型目录。
const List<String> ocrBundledAssets = [
  'ch_ppocr_mobile_v2.0_cls_mobile.onnx',
  'ppocrv6_dict.txt',
];

/// 需要联网下载的大模型文件（不进安装包）。
const List<String> ocrDownloadableAssets = [
  'PP-OCRv6_det_medium.onnx',
  'PP-OCRv6_rec_medium.onnx',
];

/// 单个模型文件的下载规格。
class OcrAssetSpec {
  final String filename;
  final String url;

  /// SHA-256 十六进制小写；空串表示无校验和（跳过哈希，只做长度检查）。
  final String sha256;

  /// 预期字节数，0 表示未知。
  final int bytes;

  const OcrAssetSpec({
    required this.filename,
    required this.url,
    required this.sha256,
    required this.bytes,
  });

  /// 下载总量（字节），进度折算的分母。
  int get size => bytes > 0 ? bytes : 0;
}

/// 从 Rust 侧取官方下载规格，只保留需要联网下载的大模型。
Future<List<OcrAssetSpec>> downloadableOcrSpecs() async {
  final raw = await ocrModelSpecs();
  return [
    for (final s in raw)
      if (ocrDownloadableAssets.contains(s.filename))
        OcrAssetSpec(
          filename: s.filename,
          url: s.url,
          sha256: s.sha256,
          bytes: ocrAssetSizes[s.filename] ?? 0,
        ),
  ];
}

/// 列出 [dir] 中缺失或尺寸不对、需要下载的大模型文件。
Future<List<OcrAssetSpec>> missingOcrAssets(String dir) async =>
    findMissingOcrAssets(dir, await downloadableOcrSpecs());

/// 从 [specs] 中挑出 [dir] 里缺失或损坏的——纯文件检查，便于单测。
///
/// 长度对不上的文件视为损坏，当场删除（随后由下载器重新拉取）。
/// 文件存在且长度正确即认为可用：下载时已经做过 SHA-256 校验，
/// 每次进扫描页再算 132MB 的哈希不值得。
List<OcrAssetSpec> findMissingOcrAssets(
  String dir,
  List<OcrAssetSpec> specs,
) {
  final missing = <OcrAssetSpec>[];
  for (final spec in specs) {
    final f = File(_join(dir, spec.filename));
    if (f.existsSync()) {
      if (spec.bytes == 0 || f.lengthSync() == spec.bytes) continue;
      f.deleteSync();
    }
    missing.add(spec);
  }
  return missing;
}

/// 把 [assets] 下载到 [dir]；已有合格成品的文件会自动跳过。
///
/// [onProgress] 以全部 [assets] 的字节为分母回调 0.0~1.0，
/// [onFileStart] 在每个文件开始时回调其文件名。
Future<void> downloadOcrAssets({
  required String dir,
  required List<OcrAssetSpec> assets,
  void Function(double progress)? onProgress,
  void Function(String filename)? onFileStart,
}) async {
  if (assets.isEmpty) return;
  await Directory(dir).create(recursive: true);

  final total = assets.fold<int>(0, (a, s) => a + math.max(s.size, 1));
  var done = 0;
  final client = http.Client();
  try {
    for (final spec in assets) {
      onFileStart?.call(spec.filename);
      await _downloadOne(client, dir, spec, (p) {
        onProgress?.call(
          ((done + spec.size * p) / total).clamp(0.0, 1.0),
        );
      });
      done += math.max(spec.size, 1);
      onProgress?.call((done / total).clamp(0.0, 1.0));
    }
  } finally {
    client.close();
  }
}

String _join(String dir, String name) =>
    '$dir${Platform.pathSeparator}$name';

/// 单个文件：带重试地拉取 `.part`，校验通过后改名成成品。
Future<void> _downloadOne(
  http.Client client,
  String dir,
  OcrAssetSpec spec,
  void Function(double) onPart,
) async {
  // 数据来自 Rust 常量，正常不含分隔符；纯防御，避免写到目录外。
  if (spec.filename.contains('/') || spec.filename.contains(r'\')) {
    throw StateError('非法模型文件名: ${spec.filename}');
  }
  final target = File(_join(dir, spec.filename));
  final part = File('${target.path}.part');

  // 三次尝试：网络抖动、5xx、超时都会走到这里，逐次退避 1s、2s。
  // 每次尝试都从当前 .part 续传，中断点不浪费。
  Object? lastErr;
  for (var attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
    }
    try {
      await _fetchPart(client, spec, part, onPart);
      lastErr = null;
      break;
    } catch (e) {
      lastErr = e;
    }
  }
  if (lastErr != null) throw lastErr;

  if (!await part.exists()) {
    throw StateError('模型下载不完整: ${spec.filename}（临时文件丢失）');
  }

  // 整文件校验，通过才改名成成品——这是「半截模型永远进不了引擎」的关键。
  if (spec.sha256.isNotEmpty) {
    final digest = await _sha256File(part);
    if ('$digest' != spec.sha256.toLowerCase()) {
      await part.delete();
      throw StateError('模型校验失败: ${spec.filename}（SHA-256 不匹配）');
    }
  }
  if (await target.exists()) await target.delete();
  await part.rename(target.path);
}

/// 拉取一次（不校验）：优先 Range 续传，服务器不配合就整段覆盖。
Future<void> _fetchPart(
  http.Client client,
  OcrAssetSpec spec,
  File part,
  void Function(double) onPart,
) async {
  final offset = await part.exists() ? await part.length() : 0;
  // 临时文件已经够长：上次可能下完没来得及改名，交给校验环节。
  if (spec.bytes > 0 && offset >= spec.bytes) return;

  final req = http.Request('GET', Uri.parse(spec.url));
  if (offset > 0) {
    req.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
  }
  final resp = await client
      .send(req)
      .timeout(const Duration(seconds: 30));

  if (resp.statusCode == 200) {
    // 服务器忽略 Range 或本来就没带：整个文件覆盖重写。
    await _pipe(
      part,
      resp.stream,
      append: false,
      received: 0,
      total: spec.bytes,
      onPart: onPart,
    );
  } else if (resp.statusCode == 206) {
    await _pipe(
      part,
      resp.stream,
      append: true,
      received: offset,
      total: spec.bytes,
      onPart: onPart,
    );
  } else if (resp.statusCode == 416 && offset > 0) {
    // Range 越界：.part 多半已完整，交校验；校验不过会删掉重来。
    return;
  } else {
    // 非 2xx 先把响应体读掉归还连接，再报错（外层会退避重试）。
    try {
      await resp.stream.drain<void>();
    } catch (_) {
      // 读流失败无所谓，连接会被关闭。
    }
    throw HttpException('下载失败 HTTP ${resp.statusCode}: ${spec.filename}');
  }
}

/// 把响应流写进 `.part`。30 秒收不到任何数据视为连接挂掉，
/// 抛给外层重试（下次带 Range 从已写字节续传）。
Future<void> _pipe(
  File part,
  Stream<List<int>> stream, {
  required bool append,
  required int received,
  required int total,
  required void Function(double) onPart,
}) async {
  final sink = part.openWrite(
    mode: append ? FileMode.append : FileMode.write,
  );
  var got = received;
  var lastEmit = DateTime.now();
  try {
    await for (final chunk
        in stream.timeout(const Duration(seconds: 30))) {
      sink.add(chunk);
      got += chunk.length;
      final now = DateTime.now();
      if (now.difference(lastEmit).inMilliseconds > 100) {
        lastEmit = now;
        if (total > 0) onPart((got / total).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
  if (total > 0) onPart((got / total).clamp(0.0, 1.0));
}

/// 分块算文件 SHA-256，不把几十 MB 一次性读进内存。
Future<Digest> _sha256File(File f) async {
  final acc = _DigestCollector();
  final input = sha256.startChunkedConversion(acc);
  await for (final chunk in f.openRead()) {
    input.add(chunk);
  }
  input.close();
  return acc.value!;
}

/// 收集 chunked 哈希结果的小容器（`AccumulatorSink` 在 package:convert，
/// 为一个字段引依赖不值当）。
class _DigestCollector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
