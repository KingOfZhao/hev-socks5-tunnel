package com.zq.qf.socks5proxy;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import android.os.ParcelFileDescriptor;
import android.content.Context;
import android.os.Build;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.net.VpnService;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.pm.ServiceInfo;

public class TProxyService extends VpnService {
    private ParcelFileDescriptor tunFd = null;
    public static final String ACTION_CONNECT = "hev.sockstun.CONNECT";
	public static final String ACTION_DISCONNECT = "hev.sockstun.DISCONNECT";
	private static final String NOTIFICATION_CHANNEL_ID = "hev_socks5_tunnel";
	private static final int NOTIFICATION_ID = 1001;

    static {
        System.loadLibrary("hev-socks5-tunnel");
    }

    public native void TProxyStartService(String configPath, int fd);
    public native void TProxyStopService();
    public native long[] TProxyGetStats();

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		if (intent != null && ACTION_DISCONNECT.equals(intent.getAction())) {
			stopService();
			stopForeground(true);
			return START_NOT_STICKY;
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			startForeground(NOTIFICATION_ID, buildNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
		} else {
			startForeground(NOTIFICATION_ID, buildNotification());
		}
		startService();
		return START_STICKY;
	}

	@Override
	public void onDestroy() {
		stopForeground(true);
		super.onDestroy();
	}

	@Override
	public void onRevoke() {
		stopService();
		super.onRevoke();
	}

    public void startService() {
		if (tunFd != null)
		  return;

		Preferences prefs = new Preferences(this);

		/* VPN */
		String session = new String();
		VpnService.Builder builder = new VpnService.Builder();
		builder.setBlocking(false);
		builder.setMtu(prefs.getTunnelMtu());
		if (prefs.getIpv4()) {
			String addr = prefs.getTunnelIpv4Address();
			int prefix = prefs.getTunnelIpv4Prefix();
			String dns = prefs.getDnsIpv4();
			builder.addAddress(addr, prefix);
			builder.addRoute("0.0.0.0", 0);
			if (!prefs.getRemoteDns() && !dns.isEmpty())
			  builder.addDnsServer(dns);
			session += "IPv4";
		}

		if (prefs.getIpv6()) {
			String addr = prefs.getTunnelIpv6Address();
			int prefix = prefs.getTunnelIpv6Prefix();
			String dns = prefs.getDnsIpv6();
			builder.addAddress(addr, prefix);
			builder.addRoute("::", 0);
			if (!prefs.getRemoteDns() && !dns.isEmpty())
			  builder.addDnsServer(dns);
			if (!session.isEmpty())
			  session += " + ";
			session += "IPv6";
		}

		if (prefs.getRemoteDns()) {
			builder.addDnsServer(prefs.getMappedDns());
		}

		boolean disallowSelf = true;
		if (prefs.getGlobal()) {
			session += "/Global";
		} 
        else {
			for (String appName : prefs.getApps()) {
				try {
					builder.addAllowedApplication(appName);
					disallowSelf = false;
				} catch (NameNotFoundException e) {
				}
			}
			session += "/per-App";
		}
		if (disallowSelf) {
			String selfName = getApplicationContext().getPackageName();
			try {
				builder.addDisallowedApplication(selfName);
			} catch (NameNotFoundException e) {
			}
		}
		builder.setSession(session);
		tunFd = builder.establish();
		if (tunFd == null) {
			prefs.setEnable(false);
			stopSelf();
			return;
		}

		/* TProxy */
		File tproxy_file = new File(getCacheDir(), "tproxy.conf");
		try {
			tproxy_file.createNewFile();
			FileOutputStream fos = new FileOutputStream(tproxy_file, false);

			String tproxy_conf = "misc:\n" +
				"  task-stack-size: " + prefs.getTaskStackSize() + "\n" +
				"tunnel:\n" +
				"  mtu: " + prefs.getTunnelMtu() + "\n";

			tproxy_conf += "socks5:\n" +
				"  port: " + prefs.getSocksPort() + "\n" +
				"  address: '" + prefs.getSocksAddress() + "'\n" +
				"  udp: '" + (prefs.getUdpInTcp() ? "tcp" : "udp") + "'\n";

			if (!prefs.getSocksUdpAddress().isEmpty()) {
                tproxy_conf += "  udp-address: '" + prefs.getSocksUdpAddress() + "'\n";
            }

            System.out.println(tproxy_conf);
			if (!prefs.getSocksUsername().isEmpty() &&
				!prefs.getSocksPassword().isEmpty()) {
				tproxy_conf += "  username: '" + prefs.getSocksUsername() + "'\n";
				tproxy_conf += "  password: '" + prefs.getSocksPassword() + "'\n";
			}

			if (prefs.getRemoteDns()) {
				tproxy_conf += "mapdns:\n" +
					"  address: " + prefs.getMappedDns() + "\n" +
					"  port: 53\n" +
					"  network: 240.0.0.0\n" +
					"  netmask: 240.0.0.0\n" +
					"  cache-size: 10000\n";
			}

			fos.write(tproxy_conf.getBytes());
			fos.close();
		} catch (IOException e) {
			return;
		}
		TProxyStartService(tproxy_file.getAbsolutePath(), tunFd.getFd());
		prefs.setEnable(true);
	}

	private void ensureNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return;
		}

		NotificationManager manager = getSystemService(NotificationManager.class);
		if (manager == null) {
			return;
		}

		NotificationChannel channel = new NotificationChannel(
				NOTIFICATION_CHANNEL_ID,
				"VPN service",
				NotificationManager.IMPORTANCE_LOW);
		channel.setDescription("Shows that the VPN tunnel is running");
		manager.createNotificationChannel(channel);
	}

	private Notification buildNotification() {
		ensureNotificationChannel();
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
		    return new Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
			    .setContentTitle("hev-socks5-demo")
			    .setContentText("VPN is running")
			    .setSmallIcon(android.R.drawable.ic_dialog_info)
			    .setOngoing(true)
			    .setOnlyAlertOnce(true)
			    .build();
		}

		return new Notification.Builder(this)
			.setContentTitle("hev-socks5-demo")
			.setContentText("VPN is running")
			.setSmallIcon(android.R.drawable.ic_dialog_info)
			.setOngoing(true)
			.setOnlyAlertOnce(true)
			.build();
	}

    public void stopService() {
        TProxyStopService();
        if (tunFd != null) {
            try { tunFd.close(); } catch (Exception ignored) {}
            tunFd = null;
        }
		new Preferences(this).setEnable(false);
    }
}
