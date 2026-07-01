package com.zq.qf.hev_speedtest

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.core.content.ContextCompat
import com.zq.qf.socks5proxy.Preferences
import com.zq.qf.socks5proxy.TProxyService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter <-> hev-socks5 SDK 桥接。
 * 通过 MethodChannel 暴露：启动/停止 VPN、读取原生统计(tx/rx 字节)。
 * 用于测试客户端到 SOCKS5 服务端的速率与稳定性。
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.zq.qf/hev_socks5"
    private val reqVpnPermission = 0x53

    // 待授权 VPN 后要执行的启动动作及其回调
    private var pendingStart: (() -> Unit)? = null
    private var pendingResult: MethodChannel.Result? = null

    // 仅用于调用原生统计方法的探针实例（原生统计是进程内全局状态，任意实例均可读取）
    private val statsProbe: TProxyService by lazy { TProxyService() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startProxy(call, result)
            "stop" -> {
                stopProxy()
                result.success(true)
            }
            "getStats" -> result.success(readStats())
            else -> result.notImplemented()
        }
    }

    /** 将硬编码/传入配置写入 Preferences，然后（必要时先申请 VPN 权限）启动 TProxyService。 */
    private fun startProxy(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host") ?: "127.0.0.1"
        val port = call.argument<Int>("port") ?: 1080
        val user = call.argument<String>("username") ?: ""
        val pass = call.argument<String>("password") ?: ""
        val global = call.argument<Boolean>("global") ?: true
        val udpInTcp = call.argument<Boolean>("udpInTcp") ?: false

        val prefs = Preferences(this)
        prefs.setSocksAddress(host)
        prefs.setSocksPort(port)
        prefs.setSocksUdpAddress(host)
        prefs.setSocksUsername(user)
        prefs.setSocksPassword(pass)
        prefs.setUdpInTcp(udpInTcp)
        prefs.setRemoteDns(true)
        prefs.setGlobal(global)
        prefs.setIpv4(true)
        prefs.setIpv6(false)
        prefs.setDnsIpv4("223.5.5.5")

        val startAction = { doStartService() }

        val prepare = VpnService.prepare(this)
        if (prepare != null) {
            // 需要用户授权 VPN，授权结果在 onActivityResult 处理
            pendingStart = startAction
            pendingResult = result
            startActivityForResult(prepare, reqVpnPermission)
        } else {
            startAction()
            result.success(true)
        }
    }

    private fun doStartService() {
        val intent = Intent(this, TProxyService::class.java)
        intent.action = TProxyService.ACTION_CONNECT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }

    private fun stopProxy() {
        val intent = Intent(this, TProxyService::class.java)
        intent.action = TProxyService.ACTION_DISCONNECT
        startService(intent)
    }

    /** 返回原生统计: [tx_packets, tx_bytes, rx_packets, rx_bytes]。 */
    private fun readStats(): List<Long> {
        return try {
            val arr = statsProbe.TProxyGetStats()
            if (arr != null && arr.size >= 4) arr.toList()
            else listOf(0L, 0L, 0L, 0L)
        } catch (e: Throwable) {
            listOf(0L, 0L, 0L, 0L)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == reqVpnPermission) {
            val res = pendingResult
            val action = pendingStart
            pendingResult = null
            pendingStart = null
            if (resultCode == Activity.RESULT_OK && action != null) {
                action()
                res?.success(true)
            } else {
                res?.success(false)
            }
        }
    }
}
