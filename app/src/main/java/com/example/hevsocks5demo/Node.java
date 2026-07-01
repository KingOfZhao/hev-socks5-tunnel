package com.example.hevsocks5demo;

public class Node {
    private final String name;
    private final String host;
    private final int port;
    private final String username;
    private final String password;

    public Node(String name, String host, int port, String username, String password) {
        this.name = name;
        this.host = host;
        this.port = port;
        this.username = username;
        this.password = password;
    }

    public String getName() { return name; }
    public String getHost() { return host; }
    public int getPort() { return port; }
    public String getUsername() { return username; }
    public String getPassword() { return password; }
}
