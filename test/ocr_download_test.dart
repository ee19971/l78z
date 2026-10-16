import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/yemian/ocr_download.dart';

/// 本地假 CDN：支持 Range（可开关），统计命中与实际发送的字节数。
/// 下载器的所有分支都在这里演练，不依赖外网。
class _FakeCdn {
  HttpServer? _server;
  late Uint8List body;

  /// 是否支持 Range（false 时无视 Range 头回 200 全量）。
  bool supportRange = true;

  /// 收到的 Range 头，按请求顺序记录。
  final List<String?> rangeHeaders = [];

  /// 实际发出去的响应体字节数（用来断言续传真的只传了后半段）。
  int bytesServed = 0;

  Future<void> start(Uint8List content) async {
    body = content;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> _handle(HttpRequest req) async {
    final range = req.headers.value(HttpHeaders.rangeHeader);
    rangeHeaders.add(range);
    if (supportRange && range != null && range.startsWith('bytes=')) {
      final start = int.parse(range.substring(6).split('-').first);
      if (start >= body.length) {
        req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await req.response.close();
        return;
      }
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${body.length - 1}/${body.length}',
      );
      final slice = body.sublist(start);
      bytesServed += slice.length;
      req.response.add(slice);
    } else {
      bytesServed += body.length;
      req.response.add(body);
    }
    await req.response.close();
  }

  String get url =>
      'http://${_server!.address.host}:${_server!.port}/model.onnx';

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

/// 造一段确定内容的字节。
Uint8List _makeBody(int len) =>
    Uint8List.fromList(List.generate(len, (i) => (i * 31 + 7) & 0xff));

/// 分块算文件 SHA-256（与下载器校验同一口径，顺便覆盖分块逻辑）。
Future<String> _digestOf(File f) async {
  final sink = _Collector();
  final input = sha256.startChunkedConversion(sink);
  await for (final chunk in f.openRead()) {
    input.add(chunk);
  }
  input.close();
  return '${sink.value!}';
}

class _Collector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

void main() {
  late Directory tmp;
  late _FakeCdn cdn;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('l78z_ocr_dl');
    cdn = _FakeCdn();
  });

  tearDown(() async {
    await cdn.stop();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  String pathOf(String name) =>
      '${tmp.path}${Platform.pathSeparator}$name';

  OcrAssetSpec specOf(Uint8List body, String url) => OcrAssetSpec(
        filename: 'PP-OCRv6_det_medium.onnx',
        url: url,
        sha256: sha256.convert(body).toString(),
        bytes: body.length,
      );

  test('完整下载：落盘、SHA-256 正确、进度单调走到 1.0', () async {
    final body = _makeBody(64 * 1024);
    await cdn.start(body);
    final spec = specOf(body, cdn.url);

    final progress = <double>[];
    await downloadOcrAssets(
      dir: tmp.path,
      assets: [spec],
      onProgress: progress.add,
    );

    final f = File(pathOf(spec.filename));
    expect(await f.exists(), isTrue);
    expect(await f.length(), body.length);
    expect(await _digestOf(f), spec.sha256);
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }
    // 不该留下 .part。
    expect(File('${f.path}.part').existsSync(), isFalse);
  });

  test('断点续传：已有半截 .part 时带 Range 只拉剩余字节', () async {
    final body = _makeBody(48 * 1024);
    await cdn.start(body);
    final spec = specOf(body, cdn.url);

    // 预置前 12KB，模拟上次下到一半被杀。
    const offset = 12 * 1024;
    await File(pathOf('${spec.filename}.part'))
        .writeAsBytes(body.sublist(0, offset));

    await downloadOcrAssets(dir: tmp.path, assets: [spec]);

    expect(cdn.rangeHeaders.single, 'bytes=$offset-');
    expect(cdn.bytesServed, body.length - offset);
    final f = File(pathOf(spec.filename));
    expect(await _digestOf(f), spec.sha256);
  });

  test('服务器忽略 Range（回 200 全量）时覆盖重写也成功', () async {
    final body = _makeBody(32 * 1024);
    await cdn.start(body);
    cdn.supportRange = false;
    final spec = specOf(body, cdn.url);

    // 半截 .part 是脏的，全量覆盖后必须以新内容为准。
    await File(pathOf('${spec.filename}.part')).writeAsBytes(Uint8List(100));

    await downloadOcrAssets(dir: tmp.path, assets: [spec]);

    final f = File(pathOf(spec.filename));
    expect(await _digestOf(f), spec.sha256);
    expect(await f.length(), body.length);
  });

  test('SHA-256 不匹配：抛错、成品与 .part 都不留', () async {
    final body = _makeBody(16 * 1024);
    await cdn.start(body);
    final spec = OcrAssetSpec(
      filename: 'PP-OCRv6_rec_medium.onnx',
      url: cdn.url,
      sha256: '0' * 64, // 必然不匹配
      bytes: body.length,
    );

    await expectLater(
      downloadOcrAssets(dir: tmp.path, assets: [spec]),
      throwsA(isA<StateError>()),
    );

    expect(File(pathOf(spec.filename)).existsSync(), isFalse);
    expect(File(pathOf('${spec.filename}.part')).existsSync(), isFalse);
  });

  test('findMissingOcrAssets：缺失 / 长度不符 / 完好三种情况', () async {
    final specs = [
      const OcrAssetSpec(
        filename: 'a.onnx',
        url: 'http://x/a',
        sha256: 'aa',
        bytes: 10,
      ),
      const OcrAssetSpec(
        filename: 'b.onnx',
        url: 'http://x/b',
        sha256: 'bb',
        bytes: 20,
      ),
    ];

    // 目录为空：两个都缺。
    expect(
      findMissingOcrAssets(tmp.path, specs).map((s) => s.filename),
      ['a.onnx', 'b.onnx'],
    );

    // a 完好（长度 10）、b 只有半截（长度 3 → 删掉并列出）。
    await File(pathOf('a.onnx')).writeAsBytes(List.filled(10, 1));
    final b = File(pathOf('b.onnx'));
    await b.writeAsBytes(List.filled(3, 2));
    expect(
      findMissingOcrAssets(tmp.path, specs).map((s) => s.filename),
      ['b.onnx'],
    );
    expect(b.existsSync(), isFalse, reason: '损坏文件应被当场删除');
    expect(File(pathOf('a.onnx')).existsSync(), isTrue);

    // bytes=0 表示大小未知：文件存在即认为可用。
    const unknown = OcrAssetSpec(
      filename: 'c.onnx',
      url: 'http://x/c',
      sha256: 'cc',
      bytes: 0,
    );
    await File(pathOf('c.onnx')).writeAsBytes([1, 2, 3]);
    expect(findMissingOcrAssets(tmp.path, [unknown]), isEmpty);
  });
}
