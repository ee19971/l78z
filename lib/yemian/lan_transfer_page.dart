import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/localsend_compat.dart';
import '../src/rust/api/qr.dart';
import '../src/rust/api/transfer.dart';
import 'frb_util.dart';
import 'scan_page.dart';

/// 与原生层通信：把收到的文件写进安卓系统"下载"目录（MediaStore）。
const MethodChannel _storageChannel = MethodChannel('com.example.l78z/storage');

/// 局域网传输的全局状态。
///
/// 服务必须比传输页活得久：退出页面只是关掉界面，接收服务得继续跑着，
/// 否则对端那边看起来就是"连上之后又断了"。
///
/// 收到文件后的落盘同样挂在这里而不是页面里——页面可能早就关掉了，
/// 文件仍然要搬进系统"下载"目录，否则用户在文件管理器里根本找不到。
class LanTransferService extends ChangeNotifier {
  LanTransferService._();

  static final LanTransferService instance = LanTransferService._();

  /// 本机接收服务信息；非 null 表示服务正在运行。
  ConnectInfo? self;

  /// 本机的配对二维码。
  Uint8List? pairingPng;

  /// 事件记录，最新在前。跨页面保留，回来还能看到之前发生过什么。
  final List<String> log = [];

  /// 由传输页在 didChangeDependencies 注入。
  ///
  /// Service 比页面活得久：页面关掉后事件仍会写日志，此时用的是上次注入的
  /// 语言（日志是历史记录，保持写入时的语言反而一致）。没注入时各日志点
  /// 退回中文原文——绝不能因为拿不到 context 就丢日志或崩溃。
  AppLocalizations? l10n;

  StreamSubscription<TransferEvent>? _sub;

  void addLog(String line) {
    log.insert(0, line);
    notifyListeners();
  }

  /// 确保事件流有人在听。收文件、落盘、反向注册都不该依赖页面是否还开着。
  void ensureListening() {
    if (_sub != null) return;
    _sub = serverEvents().listen(_onEvent);
  }

  /// LocalSend 兼容层发现的设备。
  ///
  /// 与自有协议并行：自有协议要扫码配对，兼容层靠多播自动发现。
  /// 取名 lsPeers 而不是 lsDevices，免得和桥接过来的 `lsDevices()` 撞车。
  List<LsDevice> lsPeers = [];

  /// 兼容层实际监听的端口；null 表示没在跑。
  int? lsPort;

  /// 兼容层没能正常跑起来的原因（多播绑不上等）。
  String? lsError;

  StreamSubscription<LsEvent>? _lsSub;

  /// 确保 LocalSend 兼容层的状态与设置一致。
  ///
  /// 它是可选能力：设置里没开就绝不占端口、不发多播。反过来在页面打开期间
  /// 被关掉也要停掉，否则开关看上去关了、端口其实还占着。
  Future<void> ensureLocalSend() async {
    final cfg = await loadAppConfig();

    if (!cfg.lsCompatEnabled) {
      if (_lsSub != null) {
        _lsSub?.cancel();
        _lsSub = null;
        await lsStop();
        lsPort = null;
        lsPeers = [];
        lsError = null;
        addLog(l10n?.lanLogLsDisabled ?? 'LocalSend 兼容层已按设置关闭');
      }
      return;
    }

    // 订阅要早于启动：启动会立刻广播 Started，晚一步就收不到了。
    _lsSub ??= lsEvents().listen(_onLsEvent);

    try {
      final docs = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${docs.path}/l78z_received');
      await saveDir.create(recursive: true);
      final st = await lsStart(
        saveDir: saveDir.path,
        deviceName: Platform.localHostname,
        portHint: cfg.port,
        pin: cfg.pin,
        verifyChecksums: cfg.verifyChecksums,
      );
      lsPort = st.port;
      lsError = st.multicastError;
      final reason = st.multicastError ?? l10n?.lanUnknown ?? '未知原因';
      addLog(
        st.multicastOk
            ? l10n?.lanLogLsStarted(st.port) ??
                'LocalSend 兼容层已启动，端口 ${st.port}，官方 LocalSend 可自动发现本机'
            : l10n?.lanLogLsStartedNoMcast(st.port, reason) ??
                'LocalSend 兼容层已启动（端口 ${st.port}），但多播不可用：'
                    '$reason，只能被主动扫描发现',
      );
    } catch (e) {
      lsError = e.toString();
      addLog(l10n?.lanLogLsStartFailed('$e') ?? 'LocalSend 兼容层启动失败：$e');
    }
  }

  void _onLsEvent(LsEvent ev) {
    switch (ev) {
      case LsEvent_Started(:final port, :final multicastOk, :final multicastError):
        lsPort = port;
        lsError = multicastOk
            ? null
            : (multicastError ?? l10n?.lanMcastUnavailable ?? '多播不可用');
      case LsEvent_Stopped():
        lsPort = null;
        lsPeers = [];
      case LsEvent_Discovered(:final alias, :final ip, :final port):
        addLog(l10n?.lanLogLsDiscovered(alias, '$ip:$port') ??
            '发现 LocalSend 设备：$alias（$ip:$port）');
        _refreshLsPeers();
      case LsEvent_Registered(:final alias, :final ip):
        addLog(l10n?.lanLogLsRegistered(alias, ip) ??
            '$alias 通过 LocalSend 协议注册到本机（$ip）');
        _refreshLsPeers();
      case LsEvent_Incoming(:final alias, :final files, :final totalBytes, :final ip):
        // files / received / failed 在 FRB 侧是 i64，落成 BigInt；个数用不着那么大，
        // 转回 int 好直接喂给 l10n 占位符。
        addLog(l10n?.lanLogLsIncoming(
                alias, files.toInt(), ip, _fmtBytes(totalBytes)) ??
            '$alias 请求推送 $files 个文件（$ip，共 ${_fmtBytes(totalBytes)}）');
      case LsEvent_Received(:final name):
        addLog(l10n?.lanLogLsReceived(name) ?? 'LocalSend 收到文件：$name');
      case LsEvent_ReceiveFailed(:final name, :final error):
        addLog(l10n?.lanLogLsRecvFailed(name, error) ??
            'LocalSend 文件接收失败：$name（$error）');
      case LsEvent_SessionEnd(:final received, :final failed):
        addLog(l10n?.lanLogLsSessionEnd(received.toInt(), failed.toInt()) ??
            'LocalSend 会话结束：成功 $received，失败 $failed');
      case LsEvent_Error(:final message):
        addLog(l10n?.lanLogLsError(message) ?? 'LocalSend：$message');
    }
    notifyListeners();
  }

  Future<void> _refreshLsPeers() async {
    final list = await lsDevices();
    lsPeers = list;
    notifyListeners();
  }

  static String _fmtBytes(BigInt bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${units[i]}';
  }

  void _onEvent(TransferEvent ev) {
    ev.when(
      textReceived: (from, kind, text) => addLog(
          l10n?.lanLogTextReceived(kind, from, text) ??
              '收到文本 [$kind] 来自 $from:\n$text'),
      fileReceived: (from, name, path, size) =>
          _onFileReceived(from, name, path, size),
      peerRegistered: (info) {
        PairedDevice.value = info;
        addLog(
          l10n?.lanLogReverseRegistered(info.name, '${info.ip}:${info.port}') ??
              '✓ ${info.name} 已反向注册，现在可以互相发送\n'
                  '${info.ip}:${info.port}',
        );
      },
      serverStarted: (port) =>
          addLog(l10n?.lanLogServerPort(port) ?? '服务已启动，端口 $port'),
      serverStopped: () =>
          addLog(l10n?.lanLogServerStopped ?? '服务已停止'),
    );
  }

  /// 收到文件：安卓端先落到应用私有目录（Rust 只能写私有路径），
  /// 再搬到系统"下载"目录，否则文件管理器根本看不到。
  Future<void> _onFileReceived(
    String from,
    String name,
    String path,
    BigInt size,
  ) async {
    var finalPath = path;
    var note = '';
    if (Platform.isAndroid) {
      try {
        final dest = await _storageChannel.invokeMethod<String>(
          'saveToDownloads',
          {'path': path, 'name': name},
        );
        if (dest != null && dest.isNotEmpty) {
          finalPath = dest;
          note = l10n?.lanLogSavedDownloads ?? '\n已存入系统"下载"目录';
        }
      } catch (e) {
        note = l10n?.lanLogSaveFailed('$e') ??
            '\n⚠ 存入下载目录失败（$e），文件仍留在应用私有目录';
      }
    }
    addLog(
      l10n?.lanLogFileReceived(from, name, fmtSize(size), finalPath, note) ??
          '收到来自 $from 的文件 $name（${fmtSize(size)}）\n'
              '已保存: $finalPath$note',
    );
  }

  static String fmtSize(BigInt n) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = n;
    var i = 0;
    final kb = BigInt.from(1024);
    while (value >= kb && i < units.length - 1) {
      value = value ~/ kb;
      i++;
    }
    return '$value ${units[i]}';
  }
}

/// 局域网传输页：本机开服务（配对二维码）+ 扫码配对后发送文本/文件。
class LanTransferPage extends StatefulWidget {
  const LanTransferPage({super.key});

  @override
  State<LanTransferPage> createState() => _LanTransferPageState();
}

class _LanTransferPageState extends State<LanTransferPage> {
  final _svc = LanTransferService.instance;

  ConnectInfo? _peer;
  final _textController = TextEditingController();
  double? _sendProgress; // 0..1
  bool _sending = false;
  bool _probing = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _peer = PairedDevice.value;
    _svc.addListener(_onServiceChanged);
    // 页面回来时重新挂监听：订阅跟着页面走，服务则常驻。
    _svc.ensureListening();
    // 自动启动接收服务。
    //
    // 不这么做的话，双向互传根本不成立：只扫对方的码，只有扫码方知道对方
    // 在哪，被扫的一方一无所知，也就无从发回去。而「本机必须先启动服务」
    // 这个前提用户无从得知（它只出现在日志里的一行小字中），照直觉操作
    // 必然失败 —— 所以这里直接替他做了。
    if (_svc.self == null) unawaited(_toggleServer());
    // 设置里启用了 LocalSend 兼容就在这里拉起来。失败不往外抛：自有协议
    // 还能用，不该因为兼容层起不来就让整个页面挂掉。
    unawaited(_svc.ensureLocalSend());
  }

  @override
  void dispose() {
    _svc.removeListener(_onServiceChanged);
    _textController.dispose();
    // 注意：这里绝不能 serverStop()。退出页面只是关掉界面，
    // 接收服务必须继续跑，否则对端会以为连接断了。
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次依赖变化（含语言切换）都重新注入：Service 常驻、事件回调里没有
    // context，日志文案只能拿这里给它的 l10n 对象来生成。
    _svc.l10n = AppLocalizations.of(context)!;
  }

  /// 页面方法里直接取文案；写日志的方法大多跨 await，取用前先备好。
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  void _onServiceChanged() {
    // 对端可能在本页开着的时候才反向注册过来（对方这时才扫码）。
    // 只 rebuild 而不同步 _peer 的话，「发送文本/发送文件」会一直是禁用态，
    // 非得退出重进才会亮——因为按钮读的是 State 字段而不是全局值，而
    // PairedDevice 只是个静态字段、不是 notifier，没有任何机制把它的
    // 变化推回 State。
    //
    // 时序上是安全的：_probePeer 成功时会同时写 _peer 和 PairedDevice.value，
    // 所以此后的同步读到的仍是同一个值，不会把探测结果覆盖掉。
    _peer = PairedDevice.value;
    if (mounted) setState(() {});
  }

  void _addLog(String line) => _svc.addLog(line);

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 探测对端哪条地址真的可达，把可用地址写回 _peer，并作为返回值交出去。
  ///
  /// 返回值是必需的，不能让调用方去读 `_peer`：那是 State 字段、靠 setState
  /// 刷新，而扫码配对流程紧接着还要用这个地址去注册本机信息。把结果显式
  /// 交出去，调用方就不必关心它什么时候写进字段。
  Future<ConnectInfo?> _probePeer() async {
    final info = _peer;
    if (info == null || _probing) return null;
    // 文案在第一个 await 之前取好，后续回调里不再碰 context。
    final l10n = _l10n;
    setState(() => _probing = true);
    String? ip;
    try {
      ip = await clientProbe(info: info);
    } catch (e) {
      _addLog(l10n.lanLogTestFailed('$e'));
    } finally {
      if (mounted) setState(() => _probing = false);
    }
    if (ip == null) {
      _addLog(
        l10n.lanLogPeerUnreachable(
            info.name, [info.ip, ...info.ips].join(', ')),
      );
      return null;
    }
    final reachable = ConnectInfo(
      name: info.name,
      ip: ip,
      port: info.port,
      token: info.token,
      ips: info.ips,
    );
    // 页面可能在探测期间被关掉，但结果仍要交回给调用方——
    // 配对流程下一步还要拿它去注册本机地址。
    if (mounted) setState(() => _peer = reachable);
    PairedDevice.value = reachable;
    _addLog(
      ip == info.ip
          ? l10n.lanLogConnOk('${info.ip}:${info.port}')
          : l10n.lanLogConnOkAlt('$ip:${info.port}', '${info.ip}:${info.port}'),
    );
    return reachable;
  }

  /// 把本机地址注册给对方。
  ///
  /// 只扫对方的码是单向的：只有扫码方知道对方在哪，被扫方一无所知，
  /// 结果就是"扫别人的那台能发、被扫的那台发不了"。补一次注册才双向互通。
  Future<void> _registerSelf(ConnectInfo peer) async {
    final self = _svc.self;
    if (self == null) {
      // 正常走不到这：进页面时已经自动启动服务了。真走到这里，
      // 说明启动失败（多半是没网络或端口被占），得把话说清楚，
      // 否则对方永远发不回来而用户不知道为什么。
      _addLog(_l10n.lanLogNeedServer(peer.name));
      return;
    }
    if (_registering) return;
    final l10n = _l10n;
    setState(() => _registering = true);
    try {
      await clientHello(info: peer, selfInfo: self);
      _addLog(l10n.lanLogToldPeer(peer.name));
    } catch (e) {
      _addLog(l10n.lanLogReverseFailed(peer.name, '$e'));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _toggleServer() async {
    if (_svc.self != null) {
      final l10n = _l10n;
      await serverStop();
      setState(() {
        _svc.self = null;
        _svc.pairingPng = null;
      });
      _addLog(l10n.lanLogServerStopped);
      return;
    }
    final l10n = _l10n;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${docs.path}/l78z_received');
      await saveDir.create(recursive: true);
      final info = await serverStart(
        portHint: 0,
        saveDir: saveDir.path,
        deviceName: Platform.localHostname,
      );
      final payload = await makePairingPayload(info: info);
      final png = await generateQrPng(text: payload, size: 260);
      _svc.ensureListening();
      setState(() {
        _svc.self = info;
        _svc.pairingPng = png;
      });
      final alts = info.ips.isEmpty
          ? ''
          : '\n${l10n.lanLogServerAlts(info.ips.join(', '))}';
      _addLog('${l10n.lanLogServerStarted('${info.ip}:${info.port}')}$alts');
    } catch (e) {
      _addLog(l10n.lanLogStartFailed('$e'));
      await _snack(l10n.lanLogStartFailed('$e'));
    }
  }

  Future<void> _scanPair() async {
    final l10n = _l10n;
    final info = await Navigator.of(context).push<ConnectInfo>(
      MaterialPageRoute(builder: (_) => const ScanPage(pairingMode: true)),
    );
    if (info == null) return;
    setState(() => _peer = info);
    PairedDevice.value = info;
    _addLog(l10n.lanLogPaired(info.name, '${info.ip}:${info.port}'));
    // 扫码只是本地解析 JSON，不代表网络通 —— 立刻探一遍真实可达地址
    final reachable = await _probePeer();
    if (reachable == null) return;
    // 再把自己的地址告诉对方，否则只有扫码方知道对方，对方发不回来。
    //
    // 这里必须传探测后的地址：二维码里首选的 IP 未必可达（手机同时挂着
    // VPN、有线/Wi-Fi 并存时很常见）。用原始 info 会往连不上的那个地址
    // 发注册请求，对方永远收不到，表现就是"扫完码对方还是发不了文件"。
    await _registerSelf(reachable);
  }

  Future<void> _sendText() async {
    final info = _peer;
    final text = _textController.text.trim();
    if (info == null || text.isEmpty) return;
    final l10n = _l10n;
    try {
      await clientSendText(
        info: info,
        text: text,
        kind: 'manual',
        from: Platform.localHostname,
      );
      _addLog(l10n.lanLogTextSent(info.name));
      _textController.clear();
    } catch (e) {
      await _snack(l10n.lanSendFailed('$e'));
      _addLog(l10n.lanLogSendTextFailed('$e'));
    }
  }

  Future<void> _sendFile() async {
    final info = _peer;
    if (info == null) return;
    final l10n = _l10n;
    final files = await FilePicker.pickFiles();
    final path = files.singleOrNull?.path;
    if (path == null) return;
    setState(() {
      _sending = true;
      _sendProgress = 0;
    });
    try {
      final stream = clientSendFile(
        info: info,
        path: path,
        from: Platform.localHostname,
      );
      await for (final p in stream) {
        final pct = p.totalBytes == BigInt.zero
            ? 0.0
            : p.sentBytes.toDouble() / p.totalBytes.toDouble();
        if (mounted) setState(() => _sendProgress = pct.clamp(0.0, 1.0));
      }
      _addLog(l10n.lanLogFileSent(
          File(path).uri.pathSegments.last, info.name));
    } catch (e) {
      await _snack(l10n.lanSendFailed('$e'));
      _addLog(l10n.lanLogSendFileFailed('$e'));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _sendProgress = null;
        });
      }
    }
  }

  /// 通过 LocalSend 协议给一台自动发现的设备发文件。
  ///
  /// 与「发送端」那张卡的扫码配对互为补充：那条路要先扫码，这条只要设备
  /// 在同一网络就会自己冒出来。
  Future<void> _sendToLs(LsDevice peer) async {
    final l10n = _l10n;
    final files = await FilePicker.pickFiles();
    final path = files.singleOrNull?.path;
    if (path == null) return;

    setState(() => _sending = true);
    try {
      final name = await lsSendFile(
        ip: peer.ip,
        port: peer.port,
        https: peer.https,
        fingerprint: peer.fingerprint,
        filePath: path,
      );
      _addLog(l10n.lanLogLsSent(name, peer.alias));
      await _snack(l10n.lanSnackSent(name));
    } catch (e) {
      _addLog(l10n.lanLogLsSendFailed('$e'));
      await _snack(l10n.lanSendFailed('$e'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// LocalSend 兼容层：状态 + 自动发现的官方设备。
  ///
  /// 与「接收端/发送端」两张卡并列，是第三条互传路径：那两张靠扫码配对，
  /// 这里靠多播自动发现，不需要任何一端先动手。
  Widget _localSendCard() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final svc = _svc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lanLsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              svc.lsPort == null
                  ? l10n.lanLsOff
                  : l10n.lanLsPortInfo(svc.lsPort!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (svc.lsError != null) ...[
              const SizedBox(height: 4),
              Text(l10n.lanLsNotice(svc.lsError!),
                  style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 8),
            if (svc.lsPeers.isEmpty)
              Text(
                l10n.lanNoDevice,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final d in svc.lsPeers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    d.deviceModel == 'Android' || d.deviceModel == 'iPhone'
                        ? Icons.phone_android
                        : Icons.computer,
                  ),
                  title: Text(d.alias),
                  subtitle: Text(
                    '${d.ip}:${d.port}'
                    '${d.deviceModel == null ? '' : ' · ${d.deviceModel}'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.https ? 'HTTPS' : 'HTTP'),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.send),
                        tooltip: l10n.lanSendToAlias(d.alias),
                        onPressed: _sending ? null : () => _sendToLs(d),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final running = _svc.self != null;
    final self = _svc.self;
    final pairingPng = _svc.pairingPng;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lanTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 服务端
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.lanReceiver,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        icon: Icon(running ? Icons.stop : Icons.play_arrow),
                        label: Text(
                            running ? l10n.lanStopServer : l10n.lanStartServer),
                        onPressed: _toggleServer,
                      ),
                      const SizedBox(width: 12),
                      if (self != null)
                        Expanded(
                          child: Text(
                            '${self.ip}:${self.port}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.lanServerKeepAlive,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (pairingPng != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.memory(pairingPng, width: 220, height: 220),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text(l10n.lanQrHint)),
                  ],
                ],
              ),
            ),
          ),
          // LocalSend 兼容层：只在跑着或已经发现设备时才占地方，
          // 否则对没启用它的用户来说就是一块永远空着的区域。
          if (_svc.lsPort != null || _svc.lsPeers.isNotEmpty) ...[
            _localSendCard(),
            const SizedBox(height: 12),
          ],
          // 客户端
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.lanSender,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _peer == null
                              ? l10n.lanUnpaired
                              : l10n.lanPeerInfo(
                                  _peer!.name, '${_peer!.ip}:${_peer!.port}'),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(l10n.lanPair),
                        onPressed: _scanPair,
                      ),
                      if (_peer != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.network_check),
                          label: Text(l10n.lanTest),
                          onPressed: _probing ? null : _probePeer,
                        ),
                      ],
                    ],
                  ),
                  if (_probing || _registering) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            labelText: l10n.lanTextContent,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _peer == null ? null : _sendText,
                        child: Text(l10n.lanSendText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(l10n.lanSendFile),
                        onPressed: _peer == null || _sending ? null : _sendFile,
                      ),
                      const SizedBox(width: 12),
                      if (_sending)
                        Expanded(
                          child: LinearProgressIndicator(value: _sendProgress),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.lanLogTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._svc.log.map(
            (line) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                // 用 SelectableText：收到的文本、文件路径经常要复制走，
                // 原来是 Text，长按没有任何反应。
                child: SelectableText(line),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
