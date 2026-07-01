package com.example.hevsocks5demo;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import com.zq.qf.socks5proxy.TProxyService;
import com.zq.qf.socks5proxy.Preferences;

import java.util.Objects;

public class ServiceReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Objects.equals(intent.getAction(), Intent.ACTION_BOOT_COMPLETED)) {
            Preferences prefs = new Preferences(context);

            /* Auto-start */
            if (prefs.getEnable()) {
                Intent i = VpnService.prepare(context);
                if (i != null) {
                    i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(i);
                }

                i = new Intent(context, TProxyService.class);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i.setAction(TProxyService.ACTION_CONNECT));
                } else {
                    context.startService(i.setAction(TProxyService.ACTION_CONNECT));
                }
            }
        }
    }
}