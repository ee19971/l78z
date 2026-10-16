import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/ocr.dart';
import '../src/rust/api/qr.dart';
import '../src/rust/api/transfer.dart';
import 'frb_util.dart';
import 'ocr_download.dart';

/// 对同一张图的处理方式：只认文字，或只认码。二者互不相干。
enum ScanMode {
  /// OCR 只识别文字，不解码二维码/条形码。
  ocr,

  /// 只解码二维码/条形码，不做 OCR。
  barcode,
}

/// 循环流光进度条：4px 圆角底条 + 循环平移的渐变高光，约 1.2s 一轮。
///
/// 取代 LinearProgressIndicator 的确定进度条：OCR 的百分比在 stage 之间
/// 跳变（0 → 5% → 55% → 100%），确定条会一顿一顿；这里改跑无限循环动画，
/// 真实百分比交给下方进度文本（文本行为不变）。
class _ShimmerProgress extends StatefulWidget {
  const _ShimmerProgress();

  @override
  State<_ShimmerProgress> createState() => _ShimmerProgressState();
}

class _ShimmerProgressState extends State<_ShimmerProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    // _busy 变 false 时本组件整体卸载，repeat 动画随之销毁，无需手动停。
    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final streakW = maxW * 0.35;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  // easeInOut 让高光在两端略作停顿，比匀速扫更有呼吸感。
                  final t = Curves.easeInOut.transform(_ctrl.value);
                  // 从完全移出左边界扫到完全移出右边界，一趟全覆盖。
                  final x = (maxW + streakW) * t - streakW;
                  return Positioned(
                    left: x,
                    top: 0,
                    bottom: 0,
                    width: streakW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0),
                            color.withValues(alpha: 0.85),
                            color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 扫一扫 / 识别页：拍照或选图，然后按需做 OCR 或码解码。
///
/// 不再内置实时相机预览：预览帧分辨率低，二维码和小字都识别不稳，
/// 还要背一套相机权限和预览生命周期；交给系统相机拍出来的是原图。
class ScanPage extends StatefulWidget {
  /// 从传输页跳转扫码配对时为 true：识别到配对码后直接返回连接信息。
  final bool pairingMode;

  /// 从主页面快捷入口进来时指定的模式：选完图直接跑该模式，
  /// 不再让用户选「OCR」还是「扫码」。为 null 时保持原有交互——
  /// 工具页那个入口就是 null，用户拍完照自己挑模式。
  final ScanMode? initialMode;

  const ScanPage({super.key, this.pairingMode = false, this.initialMode});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _busy = false;

  /// 当前待处理的图片。
  String? _imagePath;

  final List<DecodedCode> _results = [];
  String? _ocrText;

  /// 0.0~1.0；null 表示当前没在跑。
  double? _progress;
  String _stage = '';

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 调起系统相机；用户取消时静默返回。
  Future<void> _capture() async {
    final path = await takePicture();
    if (path == null) return;
    _adoptImage(path);
  }

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final path = files.singleOrNull?.path;
    if (path == null) return;
    _adoptImage(path);
  }

  void _adoptImage(String path) {
    setState(() {
      _imagePath = path;
      _results.clear();
      _ocrText = null;
      _progress = null;
      _stage = '';
    });
    // 配对场景里二维码是唯一有意义的东西，没必要再问用户一遍。
    if (widget.pairingMode) {
      _run(ScanMode.barcode);
      return;
    }
    // 快捷入口进来时模式已经由入口定了（点了「OCR 识别」进来就是要 OCR），
    // 同样不必让用户再选一次。
    final mode = widget.initialMode;
    if (mode != null) {
      _run(mode);
    }
  }

  /// rxing 同一个码可能重复上报，去重后才展示，否则列表里出现两条一样的。
  static List<DecodedCode> _dedup(List<DecodedCode> codes) {
    final seen = <String>{};
    return codes
        .where((c) => seen.add('${c.format}|${c.payload}'))
        .toList(growable: false);
  }

  /// 把解码结果当作设备配对信息处理；若已直接结束本页则返回 true。
  Future<bool> _applyPayloads(List<DecodedCode> codes) async {
    final l10n = AppLocalizations.of(context)!;
    for (final c in codes) {
      final info = await parseConnectInfo(text: c.payload);
      if (info == null) continue;
      if (widget.pairingMode) {
        if (mounted) Navigator.of(context).pop(info);
        return true;
      }
      PairedDevice.value = info;
      await _snack(l10n.scanSavedDevice(info.name, info.ip));
    }
    return false;
  }

  Future<void> _run(ScanMode mode) async {
    final path = _imagePath;
    if (path == null || _busy) return;
    // stage 文案在多次 setState 之间复用，取一次 l10n 备着。
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _busy = true;
      _progress = 0;
      _stage = l10n.scanStageRead;
      _ocrText = null;
      _results.clear();
    });

    try {
      final img = await decodeRgbaFile(path);
      if (!mounted) return;

      if (mode == ScanMode.ocr) {
        // OCR 只认文字，不再顺手跑一遍二维码解码——
        // 普通照片上没有码，那一步必然报错，把真正的 OCR 挡在了外面。
        setState(() {
          _stage = l10n.scanStagePrepareModel;
          _progress = 0.05;
        });
        // 解包随包的小文件（不到 1MB，一闪而过），大模型另行检查。
        final modelDir = await ensureOcrModelDir(onProgress: (p) {
          if (mounted) setState(() => _progress = 0.05 + p * 0.04);
        });
        if (!mounted) return;

        // 安装包不含 132MB 的大模型：首次使用先征求同意、再联网下载，
        // 下载过一次就常驻本地。用户取消则结束本次识别。
        final missing = await missingOcrAssets(modelDir);
        if (!mounted) return;
        if (missing.isNotEmpty) {
          final totalMb =
              missing.fold<int>(0, (a, s) => a + s.size) ~/ (1024 * 1024);
          final go = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.scanModelDownloadTitle),
              content: Text(l10n.scanModelDownloadBody(totalMb)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.scanModelDownloadAction),
                ),
              ],
            ),
          );
          if (go != true) {
            if (mounted) setState(() => _stage = '');
            return;
          }
          if (!mounted) return;
          setState(() {
            _stage = l10n.scanStageDownloadModel;
            _progress = 0.1;
          });
          try {
            await downloadOcrAssets(
              dir: modelDir,
              assets: missing,
              onProgress: (p) {
                if (mounted) setState(() => _progress = 0.1 + p * 0.45);
              },
            );
          } catch (e) {
            // 下载和识别是两回事，不套「识别失败」模板——
            // 用户该做的（换网络重试）也不一样。
            if (mounted) await _snack(l10n.scanModelDownloadFailed('$e'));
            return;
          }
          if (!mounted) return;
        }

        setState(() {
          _stage = l10n.scanStageRecognizing;
          _progress = 0.55;
        });
        final text = await ocrImageText(
          buf: img.pixels,
          width: img.width,
          height: img.height,
          modelDir: modelDir,
        );
        if (!mounted) return;
        setState(() {
          _ocrText = text;
          _progress = 1.0;
          _stage = l10n.scanStageDone;
        });
      } else {
        setState(() {
          _stage = l10n.scanStageDecoding;
          _progress = 0.5;
        });
        List<DecodedCode> codes;
        try {
          codes = await decodeImage(
            buf: img.pixels,
            width: img.width,
            height: img.height,
          );
        } catch (_) {
          // Rust 侧已经把原图、降采样、对比度、两档自适应二值化都试过了，
          // 还是空手而归就只能报「没识别出」——究竟是图里真没码，还是拍糊了，
          // 这一层分辨不出来，与其含糊其辞不如直接给可操作的建议。
          codes = const [];
        }
        if (!mounted) return;
        final unique = _dedup(codes);
        setState(() {
          _results.addAll(unique);
          _progress = 1.0;
          _stage = l10n.scanStageDecoded;
        });
        if (unique.isEmpty) {
          await _snack(l10n.scanNoCode);
          return;
        }
        if (await _applyPayloads(unique)) return;
      }
    } catch (e) {
      await _snack(l10n.scanFailed(_stage, '$e'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Widget _preview() {
    final path = _imagePath;
    if (path == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imagePath != null;
    // 配对场景直接解码，不需要让用户选模式；快捷入口同理——
    // 模式已在入口定死，再摆两个按钮等于问了个没意义的问题。
    final showModeButtons = hasImage &&
        !_busy &&
        !widget.pairingMode &&
        widget.initialMode == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pairingMode
              ? AppLocalizations.of(context)!.scanTitlePair
              : widget.initialMode == ScanMode.ocr
                  ? AppLocalizations.of(context)!.scanTitleOcr
                  : AppLocalizations.of(context)!.scanTitleScan,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              // 拍照依赖系统相机，只在安卓实现；桌面上显示一个点了没反应的按钮
              // 只会造成困惑，索性不渲染。
              if (Platform.isAndroid) ...[
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: Text(AppLocalizations.of(context)!.scanTakePhoto),
                    onPressed: _busy ? null : _capture,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.image),
                  label: Text(Platform.isAndroid
                      ? AppLocalizations.of(context)!.scanPickGallery
                      : AppLocalizations.of(context)!.scanPickImage),
                  onPressed: _busy ? null : _pick,
                ),
              ),
            ],
          ),
          if (hasImage) ...[
            const SizedBox(height: 16),
            _preview(),
          ],
          if (showModeButtons) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.document_scanner),
                    label:
                        Text(AppLocalizations.of(context)!.scanActionOcr),
                    onPressed: () => _run(ScanMode.ocr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label:
                        Text(AppLocalizations.of(context)!.scanActionBarcode),
                    onPressed: () => _run(ScanMode.barcode),
                  ),
                ),
              ],
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            // 循环流光动画；真实进度仍由下方文本展示，_progress 逻辑未动。
            const _ShimmerProgress(),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _progress == null || _stage.isEmpty
                    ? _stage
                    : AppLocalizations.of(context)!
                        .scanStagePercent(_stage, (_progress! * 100).round()),
              ),
            ),
          ],
          if (_ocrText != null) ...[
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.scanOcrResult,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(_ocrText!.isEmpty
                ? AppLocalizations.of(context)!.scanNoText
                : _ocrText!),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.scanDecodeResult,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._results.map(
              (c) => Card(
                child: ListTile(
                  title: SelectableText(c.payload),
                  subtitle: Text(c.format),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
