package com.example.hevsocks5demo;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import java.util.List;

public class NodeAdapter extends ArrayAdapter<Node> {
    private final LayoutInflater inflater;

    public NodeAdapter(Context context, List<Node> items) {
        super(context, 0, items);
        inflater = LayoutInflater.from(context);
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        if (convertView == null) {
            convertView = inflater.inflate(R.layout.item_node, parent, false);
        }
        Node node = getItem(position);
        TextView name = convertView.findViewById(R.id.text_node_name);
        name.setText(node != null ? node.getName() : "");
        return convertView;
    }
}
