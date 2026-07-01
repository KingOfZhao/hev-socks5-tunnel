package com.example.hevsocks5demo;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import java.util.ArrayList;
import java.util.List;

public class NodeSelectionActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_node_selection);

        ListView list = findViewById(R.id.list_nodes);
        final List<Node> nodes = new ArrayList<>();
        // nodes.add(new Node("Default (local)", "127.0.0.1", 1080));
        nodes.add(new Node("USA", "183.131.226.81", 31080, "hNx2RR4n0QdJTne8", "hNx2RR4n0QdJTne8"));
        nodes.add(new Node("Japan", "183.131.226.81", 21080, "hNx2RR4n0QdJTne8", "hNx2RR4n0QdJTne8"));

        NodeAdapter adapter = new NodeAdapter(this, nodes);
        list.setAdapter(adapter);
        list.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                Node chosen = nodes.get(position);
                Toast.makeText(NodeSelectionActivity.this, "Selected: " + chosen.getName(), Toast.LENGTH_SHORT).show();
                Intent out = new Intent();
                out.putExtra("node_name", chosen.getName());
                out.putExtra("node_host", chosen.getHost());
                out.putExtra("node_port", chosen.getPort());
                out.putExtra("username", "hNx2RR4n0QdJTne8");
                out.putExtra("password", "hNx2RR4n0QdJTne8");
                setResult(RESULT_OK, out);
                finish();
            }
        });
    }
}
