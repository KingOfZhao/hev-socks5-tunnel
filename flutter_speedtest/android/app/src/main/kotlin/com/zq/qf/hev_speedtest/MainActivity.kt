package com.zq.qf.hev_speedtest

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 仅负责挂载 [HevSocks5Bridge] 并转发 VPN 授权结果，具体逻辑都在 Bridge 里。
 */
class MainActivity : FlutterActivity() {

    private lateinit var bridge: HevSocks5Bridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = HevSocks5Bridge(this)
        bridge.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        bridge.onActivityResult(requestCode, resultCode)
    }

    override fun onDestroy() {
        if (this::bridge.isInitialized) bridge.detach()
        super.onDestroy()
    }
}
