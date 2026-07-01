package com.example.hevsocks5demo;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import android.net.VpnService;
import com.zq.qf.socks5proxy.Preferences;
import com.zq.qf.socks5proxy.TProxyService;

public class MainActivity extends AppCompatActivity {
    private com.zq.qf.socks5proxy.Preferences prefs;
    private boolean running = false;
    private boolean pendingStart = false;
    private Button toggleButton;

    private final ActivityResultLauncher<Intent> vpnPermissionLauncher =
            registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
                if (result.getResultCode() == RESULT_OK) {
                    if (pendingStart) {
                        launchNodeSelection();
                    }
                } else {
                    pendingStart = false;
                    Toast.makeText(this, "VPN permission denied", Toast.LENGTH_SHORT).show();
                }
            });

    private final ActivityResultLauncher<Intent> selectNodeLauncher =
            registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
                if (result.getResultCode() == RESULT_OK && result.getData() != null) {
                    Intent data = result.getData();
                    String name = data.getStringExtra("node_name");
                    String host = data.getStringExtra("node_host");
                    int port = data.getIntExtra("node_port", 0);
                    String username = data.getStringExtra("username");
                    String password = data.getStringExtra("password");
                    // Here you could use the selected node to configure service
                    prefs = new com.zq.qf.socks5proxy.Preferences(this);
                    prefs.setEnable(true);
                    prefs.setSocksAddress(host);
                    prefs.setSocksPort(port);
                    prefs.setSocksUdpAddress(host);
                    prefs.setSocksUsername(username);
                    prefs.setSocksPassword(password);
                    prefs.setRemoteDns(true);
                    prefs.setGlobal(true);
                    prefs.setIpv4(true);
                    // prefs.setIpv6(true);
                    prefs.setDnsIpv4("223.5.5.5");
                    // prefs.setDnsIpv6("2400:3200::1");
                    Toast.makeText(this, "Node: " + name + " (" + host + ":" + port + ")", Toast.LENGTH_LONG).show();
                    Intent intent = new Intent(this, TProxyService.class);
                    intent.setAction(TProxyService.ACTION_CONNECT);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(this, intent);
                    } else {
                        startService(intent);
                    }
                    running = true;
                    pendingStart = false;
                    updateToggleLabel();
                } else {
                    pendingStart = false;
                }
            });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_main);

        prefs = new com.zq.qf.socks5proxy.Preferences(this);
        toggleButton = findViewById(R.id.btn_toggle);
        updateToggleLabel();
        toggleButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (running) {
                    stopVpn();
                } else {
                    requestVpnPermissionAndStart();
                }
            }
        });
    }

    private void requestVpnPermissionAndStart() {
        Intent vpnIntent = VpnService.prepare(this);
        if (vpnIntent != null) {
            pendingStart = true;
            vpnPermissionLauncher.launch(vpnIntent);
            return;
        }

        launchNodeSelection();
    }

    private void launchNodeSelection() {
        selectNodeLauncher.launch(new Intent(this, NodeSelectionActivity.class));
    }

    private void stopVpn() {
        Intent intent = new Intent(this, TProxyService.class);
        intent.setAction(TProxyService.ACTION_DISCONNECT);
        startService(intent);
        running = false;
        pendingStart = false;
        if (prefs != null) {
            prefs.setEnable(false);
        }
        updateToggleLabel();
        Toast.makeText(this, "VPN stopped", Toast.LENGTH_SHORT).show();
    }

    private void updateToggleLabel() {
        if (toggleButton != null) {
            toggleButton.setText(running ? R.string.stop_service : R.string.start_service);
        }
    }
}
