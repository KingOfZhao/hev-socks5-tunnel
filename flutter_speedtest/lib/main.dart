import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/socks5_config.dart';
import 'services/hev_socks5_service.dart';
import 'services/speed_tester.dart';
import 'services/stability_monitor.dart';
import 'services/throughput_tracker.dart';

// =============================================================
// 硬编码默认配置（按需修改；界面上未连接时也可临时改）
// =============================================================
const String kDefaultSocksHost = '127.0.0.1';
const int kDefaultSocksPort = 1080;
const String kDefaultSocksUser = '';
const String kDefaultSocksPass = '';
const String kDefaultDownloadUrl = 'http://speedtest.tele2.net/100MB.zip';
const String kDefaultPingUrl = 'http://www.gstatic.com/generate_204';

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
  // ---- 工具类 ----
  final _service = const HevSocks5Service();
  final _tracker = ThroughputTracker();
  final _stability = StabilityMonitor();
  final _speedTester = SpeedTester();

  // ---- 输入 ----
  final _host = TextEditingController(text: kDefaultSocksHost);
  final _port = TextEditingController(text: '$kDefaultSocksPort');
  final _user = TextEditingController(text: kDefaultSocksUser);
  final _pass = TextEditingController(text: kDefaultSocksPass);
  final _downloadUrl = TextEditingController(text: kDefaultDownloadUrl);
  final _pingUrl = TextEditingController(text: kDefaultPingUrl);

  // ---- 状态 ----
  bool _connected = false;
  bool _busy = false;
  Timer? _statsTimer;
  DateTime? _connectedAt;

  bool _downloading = false;
  double _downloadMBps = 0;
  String _downloadResult = '';

  final List<String> _logs = [];

  @override
  void dispose() {
    _statsTimer?.cancel();
    _stability.stop();
    super.dispose();
  }

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$ts] $msg');
      if (_logs.length > 200) _logs.removeLast();
    });
  }

  Socks5Config _buildConfig() => Socks5Config(
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? kDefaultSocksPort,
        username: _user.text,
        password: _pass.text,
      );

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await _service.start(_buildConfig());
      if (ok) {
        _connected = true;
        _connectedAt = DateTime.now();
        _tracker.reset();
        _stability.reset();
        _startMonitors();
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
      await _service.stop();
      _connected = false;
      _stopMonitors();
      _log('已断开 VPN');
    } on PlatformException catch (e) {
      _log('停止异常: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _startMonitors() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final stats = await _service.getStats();
      _tracker.update(stats);
      if (mounted) setState(() {});
    });
    _stability.start(
      _pingUrl.text.trim(),
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onError: (e) => _log('探测失败: $e'),
    );
  }

  void _stopMonitors() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _stability.stop();
    setState(() {});
  }

  Future<void> _runDownloadTest() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _downloadResult = '';
      _downloadMBps = 0;
    });
    try {
      final result = await _speedTester.download(
        _downloadUrl.text.trim(),
        onProgress: (mbps) {
          if (mounted) setState(() => _downloadMBps = mbps);
        },
      );
      setState(() {
        _downloadMBps = result.mbps;
        _downloadResult = result.toString();
      });
      _log(result.toString());
    } catch (e) {
      setState(() => _downloadResult = '下载测速失败: $e');
      _log('下载测速失败: $e');
    } finally {
      setState(() => _downloading = false);
    }
  }

  String _uptime() {
    if (_connectedAt == null || !_connected) return '-';
    final d = DateTime.now().difference(_connectedAt!);
    return '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
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
            _statsCard(),
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
      label: Text(_busy ? '处理中...' : (_connected ? '断开 VPN' : '连接 VPN')),
      style: FilledButton.styleFrom(
        backgroundColor: _connected ? Colors.red : Colors.blue,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Widget _statsCard() {
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
            _row('上行速率', '${_tracker.upKBs.toStringAsFixed(1)} KB/s'),
            _row('下行速率', '${_tracker.downKBs.toStringAsFixed(1)} KB/s'),
            _row('累计上行', '${_tracker.totalTxMB.toStringAsFixed(2)} MB'),
            _row('累计下行', '${_tracker.totalRxMB.toStringAsFixed(2)} MB'),
            const Divider(),
            _row('探测成功/失败', '${_stability.okCount} / ${_stability.failCount}'),
            _row('丢包率', '${_stability.lossRate.toStringAsFixed(1)} %'),
            _row('最近延迟',
                _stability.lastLatencyMs >= 0 ? '${_stability.lastLatencyMs} ms' : '超时'),
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
            OutlinedButton.icon(
              onPressed: (_connected && !_downloading) ? _runDownloadTest : null,
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
