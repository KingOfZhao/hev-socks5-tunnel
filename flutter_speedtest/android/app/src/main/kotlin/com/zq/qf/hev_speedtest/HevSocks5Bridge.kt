package com.zq.qf.hev_speedtest

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.core.content.ContextCompat
import com.zq.qf.socks5proxy.Preferences
import com.zq.qf.socks5proxy.TProxyService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * hev-socks5 SDK 与 Flutter 的桥接工具类。
 *
 * 职责：
 *  - 把 SOCKS5 配置写入 [Preferences]；
 *  - 处理 VpnService 授权流程；
 *  - 启动/停止 [TProxyService]；
 *  - 读取原生统计 [TProxyService.TProxyGetStats]（进程内全局，任意实例可读）。
 *
 * MethodChannel: `com.zq.qf/hev_socks5`
 *  - start(host, port, username, password, global, udpInTcp) -> Boolean
 *  - stop() -> Boolean
 *  - getStats() -> [tx_packets, tx_bytes, rx_packets, rx_bytes]
 */
class HevSocks5Bridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.zq.qf/hev_socks5"
        const val REQ_VPN_PERMISSION = 0x53
    }

    private var channel: MethodChannel? = null

    // VPN 授权后待执行的启动动作及其回调
    private var pendingStart: (() -> Unit)? = null
    private var pendingResult: MethodChannel.Result? = null

    // 仅用于读取原生全局统计的探针实例
    private val statsProbe: TProxyService by lazy { TProxyService() }

    /** 注册 MethodChannel。 */
    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    /** 释放。 */
    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> {
                stop()
                result.success(true)
            }
            "getStats" -> result.success(readStats())
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        applyConfig(call)

        val startAction = { startService() }
        val prepare = VpnService.prepare(activity)
        if (prepare != null) {
            // 需要用户授权 VPN，结果在 onActivityResult 回调
            pendingStart = startAction
            pendingResult = result
            activity.startActivityForResult(prepare, REQ_VPN_PERMISSION)
        } else {
            startAction()
            result.success(true)
        }
    }

    /** 把入参写入 SharedPreferences（SDK 从这里读取配置）。 */
    private fun applyConfig(call: MethodCall) {
        val prefs = Preferences(activity)
        prefs.setSocksAddress(call.argument<String>("host") ?: "127.0.0.1")
        prefs.setSocksPort(call.argument<Int>("port") ?: 1080)
        prefs.setSocksUdpAddress(call.argument<String>("host") ?: "127.0.0.1")
        prefs.setSocksUsername(call.argument<String>("username") ?: "")
        prefs.setSocksPassword(call.argument<String>("password") ?: "")
        prefs.setUdpInTcp(call.argument<Boolean>("udpInTcp") ?: false)
        prefs.setGlobal(call.argument<Boolean>("global") ?: true)
        prefs.setRemoteDns(true)
        prefs.setIpv4(true)
        prefs.setIpv6(false)
        prefs.setDnsIpv4("223.5.5.5")
    }

    private fun startService() {
        val intent = Intent(activity, TProxyService::class.java)
        intent.action = TProxyService.ACTION_CONNECT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(activity, intent)
        } else {
            activity.startService(intent)
        }
    }

    private fun stop() {
        val intent = Intent(activity, TProxyService::class.java)
        intent.action = TProxyService.ACTION_DISCONNECT
        activity.startService(intent)
    }

    /** 返回 [tx_packets, tx_bytes, rx_packets, rx_bytes]。 */
    private fun readStats(): List<Long> {
        return try {
            val arr = statsProbe.TProxyGetStats()
            if (arr != null && arr.size >= 4) arr.toList()
            else listOf(0L, 0L, 0L, 0L)
        } catch (e: Throwable) {
            listOf(0L, 0L, 0L, 0L)
        }
    }

    /** 由 Activity 转发 VPN 授权结果。返回 true 表示已处理。 */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQ_VPN_PERMISSION) return false
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
        return true
    }
}
