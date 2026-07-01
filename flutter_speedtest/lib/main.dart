import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================
// 硬编码默认配置（按需修改；界面上也可临时改）
//   - SOCKS5 服务器地址/端口/账号密码
//   - 测速下载地址（大文件）
//   - 稳定性探测地址（返回 204 的小接口）
// =============================================================
const String kDefaultSocksHost = '127.0.0.1';
const int kDefaultSocksPort = 1080;
const String kDefaultSocksUser = '';
const String kDefaultSocksPass = '';
const String kDefaultDownloadUrl = 'http://speedtest.tele2.net/100MB.zip';
const String kDefaultPingUrl = 'http://www.gstatic.com/generate_204';

const MethodChannel _channel = MethodChannel('com.zq.qf/hev_socks5');

void main() {
  runApp(const SpeedTestApp());
}

class SpeedTestApp extends StatelessWidget {
  const SpeedTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hev-socks5 SpeedTest',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _host = TextEditingController(text: kDefaultSocksHost);
  final _port = TextEditingController(text: '$kDefaultSocksPort');
  final _user = TextEditingController(text: kDefaultSocksUser);
  final _pass = TextEditingController(text: kDefaultSocksPass);
  final _downloadUrl = TextEditingController(text: kDefaultDownloadUrl);
  final _pingUrl = TextEditingController(text: kDefaultPingUrl);

  bool _connected = false;
  bool _busy = false;

  // 实时速率（由原生 tx/rx 字节差分得到）
  Timer? _statsTimer;
  int _lastTx = 0;
  int _lastRx = 0;
  double _upKBs = 0;
  double _downKBs = 0;
  int _totalTx = 0;
  int _totalRx = 0;

  // 稳定性探测
  Timer? _pingTimer;
  int _pingOk = 0;
  int _pingFail = 0;
  int _lastLatencyMs = -1;
  DateTime? _connectedAt;

  // 下载测速
  bool _downloading = false;
  double _downloadMBps = 0;
  String _downloadResult = '';

  final List<String> _logs = [];

  @override
  void dispose() {
    _statsTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$ts] $msg');
      if (_logs.length > 200) _logs.removeLast();
    });
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await _channel.invokeMethod<bool>('start', {
        'host': _host.text.trim(),
        'port': int.tryParse(_port.text.trim()) ?? kDefaultSocksPort,
        'username': _user.text,
        'password': _pass.text,
        'global': true,
        'udpInTcp': false,
      });
      if (ok == true) {
        _connected = true;
        _connectedAt = DateTime.now();
        _lastTx = 0;
        _lastRx = 0;
        _pingOk = 0;
        _pingFail = 0;
        _startTimers();
        _log('已启动 VPN，连接 ${_host.text}:${_port.text}');
      } else {
        _log('启动失败或用户拒绝 VPN 授权');
      }
    } on PlatformException catch (e) {
      _log('启动异常: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _channel.invokeMethod('stop');
      _connected = false;
      _stopTimers();
      _log('已断开 VPN');
    } on PlatformException catch (e) {
      _log('停止异常: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollStats());
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _ping());
  }

  void _stopTimers() {
    _statsTimer?.cancel();
    _pingTimer?.cancel();
    _statsTimer = null;
    _pingTimer = null;
    setState(() {
      _upKBs = 0;
      _downKBs = 0;
    });
  }

  // 读取原生统计 [tx_packets, tx_bytes, rx_packets, rx_bytes]，差分算速率
  Future<void> _pollStats() async {
    try {
      final stats = await _channel.invokeMethod<List<dynamic>>('getStats');
      if (stats == null || stats.length < 4) return;
      final tx = (stats[1] as num).toInt();
      final rx = (stats[3] as num).toInt();
      setState(() {
        _upKBs = (tx - _lastTx) / 1024.0;
        _downKBs = (rx - _lastRx) / 1024.0;
        _lastTx = tx;
        _lastRx = rx;
        _totalTx = tx;
        _totalRx = rx;
      });
    } catch (_) {}
  }

  // 稳定性：定时探测，记录成功/失败与延迟
  Future<void> _ping() async {
    final url = _pingUrl.text.trim();
    if (url.isEmpty) return;
    final sw = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 8));
      await resp.drain();
      sw.stop();
      setState(() {
        _pingOk++;
        _lastLatencyMs = sw.elapsedMilliseconds;
      });
    } catch (e) {
      setState(() {
        _pingFail++;
        _lastLatencyMs = -1;
      });
      _log('探测失败: $e');
    } finally {
      client.close(force: true);
    }
  }

  // 主动下载测速：下载大文件，统计平均速率
  Future<void> _runDownloadTest() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _downloadResult = '';
      _downloadMBps = 0;
    });
    final url = _downloadUrl.text.trim();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final sw = Stopwatch()..start();
    int received = 0;
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      // 最长测速 20 秒，避免下载超大文件卡住
      final completer = Completer<void>();
      late StreamSubscription sub;
      final limit = Timer(const Duration(seconds: 20), () {
        if (!completer.isCompleted) completer.complete();
      });
      sub = resp.listen((chunk) {
        received += chunk.length;
        final secs = sw.elapsedMilliseconds / 1000.0;
        if (secs > 0) {
          setState(() => _downloadMBps = received / 1024.0 / 1024.0 / secs);
        }
      }, onDone: () {
        if (!completer.isCompleted) completer.complete();
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      });
      await completer.future;
      await sub.cancel();
      limit.cancel();
      sw.stop();
      final secs = sw.elapsedMilliseconds / 1000.0;
      final mbps = secs > 0 ? received / 1024.0 / 1024.0 / secs : 0;
      setState(() {
        _downloadMBps = mbps.toDouble();
        _downloadResult =
            '下载 ${(received / 1024.0 / 1024.0).toStringAsFixed(1)} MB，用时 ${secs.toStringAsFixed(1)}s，'
            '平均 ${mbps.toStringAsFixed(2)} MB/s (${(mbps * 8).toStringAsFixed(1)} Mbps)';
      });
      _log(_downloadResult);
    } catch (e) {
      setState(() => _downloadResult = '下载测速失败: $e');
      _log('下载测速失败: $e');
    } finally {
      client.close(force: true);
      setState(() => _downloading = false);
    }
  }

  String _uptime() {
    if (_connectedAt == null) return '-';
    final d = DateTime.now().difference(_connectedAt!);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h}h ${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _pingOk + _pingFail;
    final lossRate = total == 0 ? 0 : (_pingFail * 100 / total);
    return Scaffold(
      appBar: AppBar(title: const Text('hev-socks5 速率/稳定性测试')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _configCard(),
            const SizedBox(height: 12),
            _connectButton(),
            const SizedBox(height: 12),
            _statsCard(lossRate.toDouble()),
            const SizedBox(height: 12),
            _downloadCard(),
            const SizedBox(height: 12),
            _logCard(),
          ],
        ),
      ),
    );
  }

  Widget _configCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: _field(_host, 'SOCKS5 地址')),
                const SizedBox(width: 8),
                Expanded(child: _field(_port, '端口', number: true)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_user, '账号(可空)')),
                const SizedBox(width: 8),
                Expanded(child: _field(_pass, '密码(可空)')),
              ],
            ),
            const SizedBox(height: 8),
            _field(_pingUrl, '稳定性探测 URL'),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) {
    return TextField(
      controller: c,
      enabled: !_connected,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _connectButton() {
    return FilledButton.icon(
      onPressed: _busy ? null : (_connected ? _disconnect : _connect),
      icon: Icon(_connected ? Icons.stop : Icons.play_arrow),
      label: Text(_busy
          ? '处理中...'
          : (_connected ? '断开 VPN' : '连接 VPN')),
      style: FilledButton.styleFrom(
        backgroundColor: _connected ? Colors.red : Colors.blue,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Widget _statsCard(double lossRate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实时状态', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _row('状态', _connected ? '已连接' : '未连接'),
            _row('已连接时长', _uptime()),
            _row('上行速率', '${_upKBs.toStringAsFixed(1)} KB/s'),
            _row('下行速率', '${_downKBs.toStringAsFixed(1)} KB/s'),
            _row('累计上行', '${(_totalTx / 1024.0 / 1024.0).toStringAsFixed(2)} MB'),
            _row('累计下行', '${(_totalRx / 1024.0 / 1024.0).toStringAsFixed(2)} MB'),
            const Divider(),
            _row('探测成功/失败', '$_pingOk / $_pingFail'),
            _row('丢包率', '${lossRate.toStringAsFixed(1)} %'),
            _row('最近延迟',
                _lastLatencyMs >= 0 ? '$_lastLatencyMs ms' : '超时'),
          ],
        ),
      ),
    );
  }

  Widget _downloadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下载测速', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _field(_downloadUrl, '下载测速 URL'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_connected && !_downloading)
                        ? _runDownloadTest
                        : null,
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(_downloading
                        ? '测速中 ${_downloadMBps.toStringAsFixed(2)} MB/s'
                        : '开始下载测速'),
                  ),
                ),
              ],
            ),
            if (_downloadResult.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_downloadResult),
            ],
          ],
        ),
      ),
    );
  }

  Widget _logCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('日志', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(
                  _logs[i],
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
