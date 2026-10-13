import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
        addLog('LocalSend 兼容层已按设置关闭');
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
      addLog(
        st.multicastOk
            ? 'LocalSend 兼容层已启动，端口 ${st.port}，官方 LocalSend 可自动发现本机'
            : 'LocalSend 兼容层已启动（端口 ${st.port}），但多播不可用：'
                '${st.multicastError ?? '未知原因'}，只能被主动扫描发现',
      );
    } catch (e) {
      lsError = e.toString();
      addLog('LocalSend 兼容层启动失败：$e');
    }
  }

  void _onLsEvent(LsEvent ev) {
    switch (ev) {
      case LsEvent_Started(:final port, :final multicastOk, :final multicastError):
        lsPort = port;
        lsError = multicastOk ? null : (multicastError ?? '多播不可用');
      case LsEvent_Stopped():
        lsPort = null;
        lsPeers = [];
      case LsEvent_Discovered(:final alias, :final ip, :final port):
        addLog('发现 LocalSend 设备：$alias（$ip:$port）');
        _refreshLsPeers();
      case LsEvent_Registered(:final alias, :final ip):
        addLog('$alias 通过 LocalSend 协议注册到本机（$ip）');
        _refreshLsPeers();
      case LsEvent_Incoming(:final alias, :final files, :final totalBytes, :final ip):
        addLog('$alias 请求推送 $files 个文件（$ip，共 ${_fmtBytes(totalBytes)}）');
      case LsEvent_Received(:final name):
        addLog('LocalSend 收到文件：$name');
      case LsEvent_ReceiveFailed(:final name, :final error):
        addLog('LocalSend 文件接收失败：$name（$error）');
      case LsEvent_SessionEnd(:final received, :final failed):
        addLog('LocalSend 会话结束：成功 $received，失败 $failed');
      case LsEvent_Error(:final message):
        addLog('LocalSend：$message');
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
      textReceived: (from, kind, text) =>
          addLog('收到文本 [$kind] 来自 $from:\n$text'),
      fileReceived: (from, name, path, size) =>
          _onFileReceived(from, name, path, size),
      peerRegistered: (info) {
        PairedDevice.value = info;
        addLog(
          '✓ ${info.name} 已反向注册，现在可以互相发送\n'
          '${info.ip}:${info.port}',
        );
      },
      serverStarted: (port) => addLog('服务已启动，端口 $port'),
      serverStopped: () => addLog('服务已停止'),
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
          note = '\n已存入系统"下载"目录';
        }
      } catch (e) {
        note = '\n⚠ 存入下载目录失败（$e），文件仍留在应用私有目录';
      }
    }
    addLog(
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
    setState(() => _probing = true);
    String? ip;
    try {
      ip = await clientProbe(info: info);
    } catch (e) {
      _addLog('测试连接出错: $e');
    } finally {
      if (mounted) setState(() => _probing = false);
    }
    if (ip == null) {
      _addLog(
        '⚠ 连不上 ${info.name}（尝试了 ${[info.ip, ...info.ips].join(', ')}）。\n'
        '请确认两台设备连的是同一个 Wi-Fi/局域网，且对方已启动接收服务',
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
          ? '✓ 连接正常 ${info.ip}:${info.port}'
          : '✓ 连接正常，改用可达地址 $ip:${info.port}'
              '（二维码首选的 ${info.ip} 连不上）',
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
      _addLog(
        '⚠ 本机接收服务未运行，${peer.name} 还不能给本机发送。\n'
        '点上方「启动服务」后，请对方重新扫一次你的二维码',
      );
      return;
    }
    if (_registering) return;
    setState(() => _registering = true);
    try {
      await clientHello(info: peer, selfInfo: self);
      _addLog('✓ 已把本机地址告诉 ${peer.name}，现在双方都能互发');
    } catch (e) {
      _addLog('⚠ 无法反向注册给 ${peer.name}：$e');
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _toggleServer() async {
    if (_svc.self != null) {
      await serverStop();
      setState(() {
        _svc.self = null;
        _svc.pairingPng = null;
      });
      _addLog('服务已停止');
      return;
    }
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
      _addLog(
        '服务已启动：${info.ip}:${info.port}'
        '${info.ips.isEmpty ? '' : '\n备选地址: ${info.ips.join(', ')}'}',
      );
    } catch (e) {
      _addLog('启动失败: $e');
      await _snack('启动失败: $e');
    }
  }

  Future<void> _scanPair() async {
    final info = await Navigator.of(context).push<ConnectInfo>(
      MaterialPageRoute(builder: (_) => const ScanPage(pairingMode: true)),
    );
    if (info == null) return;
    setState(() => _peer = info);
    PairedDevice.value = info;
    _addLog('已配对设备: ${info.name} (${info.ip}:${info.port})');
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
    try {
      await clientSendText(
        info: info,
        text: text,
        kind: 'manual',
        from: Platform.localHostname,
      );
      _addLog('已发送文本到 ${info.name}');
      _textController.clear();
    } catch (e) {
      await _snack('发送失败: $e');
      _addLog('⚠ 发送文本失败：$e');
    }
  }

  Future<void> _sendFile() async {
    final info = _peer;
    if (info == null) return;
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
      _addLog('已发送文件 ${File(path).uri.pathSegments.last} 到 ${info.name}');
    } catch (e) {
      await _snack('发送失败: $e');
      _addLog('⚠ 发送文件失败：$e');
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
      _addLog('已通过 LocalSend 发送 $name 到 ${peer.alias}');
      await _snack('已发送 $name');
    } catch (e) {
      _addLog('LocalSend 发送失败：$e');
      await _snack('发送失败：$e');
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
    final svc = _svc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LocalSend 设备',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              svc.lsPort == null
                  ? '兼容层未运行'
                  : '端口 ${svc.lsPort}，与官方 LocalSend 自动互通',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (svc.lsError != null) ...[
              const SizedBox(height: 4),
              Text('注意：${svc.lsError}', style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 8),
            if (svc.lsPeers.isEmpty)
              Text(
                '未发现设备。确认两台设备连的是同一个网络，稍等几秒',
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
                        tooltip: '发送文件到 ${d.alias}',
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
    final running = _svc.self != null;
    final self = _svc.self;
    final pairingPng = _svc.pairingPng;

    return Scaffold(
      appBar: AppBar(title: const Text('局域网传输')),
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
                  Text('接收端', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        icon: Icon(running ? Icons.stop : Icons.play_arrow),
                        label: Text(running ? '停止服务' : '启动服务'),
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
                        '退出本页面服务仍会保持运行，对端可以继续连',
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
                    const Center(child: Text('用另一台设备扫描此二维码配对')),
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
                  Text('发送端', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _peer == null
                              ? '未配对设备'
                              : '目标: ${_peer!.name} (${_peer!.ip}:${_peer!.port})',
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('扫码配对'),
                        onPressed: _scanPair,
                      ),
                      if (_peer != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.network_check),
                          label: const Text('测试'),
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
                          decoration: const InputDecoration(
                            labelText: '文本内容',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _peer == null ? null : _sendText,
                        child: const Text('发送文本'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text('发送文件'),
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
          Text('记录', style: Theme.of(context).textTheme.titleMedium),
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
