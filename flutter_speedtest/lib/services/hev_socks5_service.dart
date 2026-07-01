import 'package:flutter/services.dart';

import '../models/socks5_config.dart';
import '../models/tunnel_stats.dart';

/// 封装与原生 hev-socks5 SDK 的通信（MethodChannel）。
class HevSocks5Service {
  static const MethodChannel _channel = MethodChannel('com.zq.qf/hev_socks5');

  const HevSocks5Service();

  /// 启动 VPN。返回 true 表示已启动（含用户已授权）；false 表示失败或拒绝授权。
  Future<bool> start(Socks5Config config) async {
    final ok = await _channel.invokeMethod<bool>('start', config.toArgs());
    return ok ?? false;
  }

  /// 停止 VPN。
  Future<void> stop() => _channel.invokeMethod('stop');

  /// 读取原生实时统计。
  Future<TunnelStats> getStats() async {
    final list = await _channel.invokeMethod<List<dynamic>>('getStats');
    return TunnelStats.fromList(list);
  }
}
