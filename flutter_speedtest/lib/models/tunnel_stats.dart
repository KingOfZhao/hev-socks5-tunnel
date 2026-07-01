/// 原生隧道统计：对应 TProxyGetStats 返回的 [tx_packets, tx_bytes, rx_packets, rx_bytes]。
class TunnelStats {
  final int txPackets;
  final int txBytes;
  final int rxPackets;
  final int rxBytes;

  const TunnelStats({
    this.txPackets = 0,
    this.txBytes = 0,
    this.rxPackets = 0,
    this.rxBytes = 0,
  });

  static const TunnelStats zero = TunnelStats();

  /// 从原生返回的 List 解析。
  factory TunnelStats.fromList(List<dynamic>? list) {
    if (list == null || list.length < 4) return zero;
    int at(int i) => (list[i] as num).toInt();
    return TunnelStats(
      txPackets: at(0),
      txBytes: at(1),
      rxPackets: at(2),
      rxBytes: at(3),
    );
  }
}
