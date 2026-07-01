import 'dart:async';
import 'dart:io';

/// 下载测速结果。
class SpeedTestResult {
  final int receivedBytes;
  final Duration elapsed;

  const SpeedTestResult(this.receivedBytes, this.elapsed);

  double get receivedMB => receivedBytes / 1024.0 / 1024.0;
  double get seconds => elapsed.inMilliseconds / 1000.0;
  double get mbps => seconds > 0 ? receivedMB / seconds : 0; // MB/s
  double get megabitsPerSec => mbps * 8; // Mbps

  @override
  String toString() =>
      '下载 ${receivedMB.toStringAsFixed(1)} MB，用时 ${seconds.toStringAsFixed(1)}s，'
      '平均 ${mbps.toStringAsFixed(2)} MB/s (${megabitsPerSec.toStringAsFixed(1)} Mbps)';
}

/// 主动下载测速：下载指定 URL，统计平均速率。
class SpeedTester {
  /// [maxDuration] 到时即停止（避免下载超大文件卡住）。
  /// [onProgress] 回调当前累计 MB/s。
  Future<SpeedTestResult> download(
    String url, {
    Duration maxDuration = const Duration(seconds: 20),
    void Function(double mbps)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final sw = Stopwatch()..start();
    int received = 0;
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();

      final completer = Completer<void>();
      Timer? limit;
      late StreamSubscription<List<int>> sub;

      void finish() {
        if (!completer.isCompleted) completer.complete();
      }

      limit = Timer(maxDuration, finish);
      sub = resp.listen(
        (chunk) {
          received += chunk.length;
          final secs = sw.elapsedMilliseconds / 1000.0;
          if (secs > 0 && onProgress != null) {
            onProgress(received / 1024.0 / 1024.0 / secs);
          }
        },
        onDone: finish,
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      try {
        await completer.future;
      } finally {
        await sub.cancel();
        limit.cancel();
      }
      sw.stop();
      return SpeedTestResult(received, sw.elapsed);
    } finally {
      client.close(force: true);
    }
  }
}
