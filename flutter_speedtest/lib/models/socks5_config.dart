/// SOCKS5 连接配置。
class Socks5Config {
  /// 预设名称（手填时为空）。
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;

  /// 全局路由（true 时所有流量走隧道）。
  final bool global;

  /// UDP over TCP。
  final bool udpInTcp;

  const Socks5Config({
    this.name = '',
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

  /// 预设测试节点（移植自 app 示例 NodeSelectionActivity）。
  static const List<Socks5Config> presets = [
    Socks5Config(
      name: 'USA',
      host: '183.131.226.81',
      port: 31080,
      username: 'hNx2RR4n0QdJTne8',
      password: 'hNx2RR4n0QdJTne8',
    ),
    Socks5Config(
      name: 'Japan',
      host: '183.131.226.81',
      port: 21080,
      username: 'hNx2RR4n0QdJTne8',
      password: 'hNx2RR4n0QdJTne8',
    ),
  ];

  /// 默认节点（USA）。
  static Socks5Config get defaultNode => presets[0];

  @override
  String toString() => name.isEmpty ? '$host:$port' : '$name ($host:$port)';
}
