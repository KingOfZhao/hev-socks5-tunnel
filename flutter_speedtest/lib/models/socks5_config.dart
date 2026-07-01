/// SOCKS5 连接配置。
class Socks5Config {
  final String host;
  final int port;
  final String username;
  final String password;

  /// 全局路由（true 时所有流量走隧道）。
  final bool global;

  /// UDP over TCP。
  final bool udpInTcp;

  const Socks5Config({
    required this.host,
    required this.port,
    this.username = '',
    this.password = '',
    this.global = true,
    this.udpInTcp = false,
  });

  /// 转成传给原生 MethodChannel 的参数。
  Map<String, dynamic> toArgs() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'global': global,
        'udpInTcp': udpInTcp,
      };

  @override
  String toString() => '$host:$port';
}
