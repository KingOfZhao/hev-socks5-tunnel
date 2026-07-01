import '../models/tunnel_stats.dart';

/// 由相邻两次统计的字节差分，计算实时上/下行速率。
class ThroughputTracker {
  int _lastTx = 0;
  int _lastRx = 0;
  bool _hasPrev = false;

  /// 上行速率 (KB/s)
  double upKBs = 0;

  /// 下行速率 (KB/s)
  double downKBs = 0;

  /// 累计上行 (bytes)
  int totalTxBytes = 0;

  /// 累计下行 (bytes)
  int totalRxBytes = 0;

  /// 复位（每次连接开始时调用）。
  void reset() {
    _lastTx = 0;
    _lastRx = 0;
    _hasPrev = false;
    upKBs = 0;
    downKBs = 0;
    totalTxBytes = 0;
    totalRxBytes = 0;
  }

  /// 传入一次新统计，按固定采样间隔(默认 1s)计算速率。
  void update(TunnelStats stats, {double intervalSeconds = 1.0}) {
    totalTxBytes = stats.txBytes;
    totalRxBytes = stats.rxBytes;
    if (_hasPrev && intervalSeconds > 0) {
      upKBs = (stats.txBytes - _lastTx) / 1024.0 / intervalSeconds;
      downKBs = (stats.rxBytes - _lastRx) / 1024.0 / intervalSeconds;
    }
    _lastTx = stats.txBytes;
    _lastRx = stats.rxBytes;
    _hasPrev = true;
  }

  double get totalTxMB => totalTxBytes / 1024.0 / 1024.0;
  double get totalRxMB => totalRxBytes / 1024.0 / 1024.0;
}
