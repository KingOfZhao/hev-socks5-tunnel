import 'dart:async';
import 'dart:io';

/// 稳定性监测：定时探测目标 URL，统计成功/失败、丢包率、延迟。
class StabilityMonitor {
  int okCount = 0;
  int failCount = 0;
  int lastLatencyMs = -1;

  Timer? _timer;

  int get total => okCount + failCount;

  /// 丢包率 (%)。
  double get lossRate => total == 0 ? 0 : failCount * 100 / total;

  /// 是否正在运行。
  bool get isRunning => _timer != null;

  /// 复位计数。
  void reset() {
    okCount = 0;
    failCount = 0;
    lastLatencyMs = -1;
  }

  /// 开始定时探测。
  /// [onUpdate] 每次探测后回调；[onError] 探测失败时回调错误信息。
  void start(
    String url, {
    Duration interval = const Duration(seconds: 3),
    void Function()? onUpdate,
    void Function(Object error)? onError,
  }) {
    stop();
    _timer = Timer.periodic(interval, (_) async {
      await probeOnce(url, onError: onError);
      onUpdate?.call();
    });
  }

  /// 停止探测。
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 单次探测。
  Future<void> probeOnce(String url, {void Function(Object error)? onError}) async {
    if (url.isEmpty) return;
    final sw = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 8));
      await resp.drain();
      sw.stop();
      okCount++;
      lastLatencyMs = sw.elapsedMilliseconds;
    } catch (e) {
      failCount++;
      lastLatencyMs = -1;
      onError?.call(e);
    } finally {
      client.close(force: true);
    }
  }
}
