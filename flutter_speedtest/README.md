# hev-socks5 速率/稳定性测试客户端 (Flutter)

用 Flutter 快速封装 `hev-socks5-sdk-release.aar`，用于测试**客户端到 SOCKS5 服务端**的速率与稳定性。界面从简，配置可写死也可在界面临时修改。

## 功能

- 一键连接/断开 VPN（全局路由，走 `TProxyService` 隧道）
- 实时上/下行速率（由原生 `TProxyGetStats()` 的 tx/rx 字节差分得到）+ 累计流量
- 主动**下载测速**（下载大文件，算平均 MB/s、Mbps）
- **稳定性探测**：定时请求探测 URL，统计成功/失败、丢包率、延迟、连接时长
- 运行日志

## 配置

默认配置在 `lib/main.dart` 顶部常量，按需改：

```dart
const String kDefaultSocksHost = '127.0.0.1'; // SOCKS5 服务器地址
const int kDefaultSocksPort = 1080;           // 端口
const String kDefaultSocksUser = '';          // 账号(可空)
const String kDefaultSocksPass = '';          // 密码(可空)
const String kDefaultDownloadUrl = 'http://speedtest.tele2.net/100MB.zip';
const String kDefaultPingUrl = 'http://www.gstatic.com/generate_204';
```

界面上这些字段在未连接时也可直接编辑。

## 集成方式

- `android/app/libs/hev-socks5-sdk-release.aar`：SDK（含 `TProxyService`/`Preferences` 与原生 `.so`）
- `android/app/build.gradle.kts`：`flatDir` 引入 AAR，`abiFilters` 限定 `armeabi-v7a`/`arm64-v8a`，`minSdk >= 21`
- `android/app/src/main/AndroidManifest.xml`：声明 VPN 权限与 `com.zq.qf.socks5proxy.TProxyService`
- `android/app/src/main/kotlin/.../MainActivity.kt`：MethodChannel `com.zq.qf/hev_socks5` 桥接
  - `start(host, port, username, password, global, udpInTcp)`：写入 `Preferences` → 申请 VPN 授权 → 启动服务
  - `stop()`：停止服务
  - `getStats()`：返回 `[tx_packets, tx_bytes, rx_packets, rx_bytes]`

## 构建

```bash
flutter pub get
flutter build apk --debug     # 或 --release
# 产物: build/app/outputs/flutter-apk/app-debug.apk
```

> 仅支持 arm 设备/真机（AAR 只含 arm ABI 的 .so，不含 x86，模拟器需 arm 镜像）。
