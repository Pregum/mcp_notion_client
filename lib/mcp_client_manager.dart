import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart';
import 'server_status_panel.dart';

class McpClientManager {
  final List<McpClientInfo> _clients = [];
  final List<McpServerStatus> _serverStatuses = [];

  List<McpServerStatus> get serverStatuses => List.unmodifiable(_serverStatuses);

  Future<void> addServer(McpServerStatus serverStatus, {
    required String name,
    required String url,
    required Map<String, String> headers,
  }) async {
    // 既存のサーバーと重複チェック
    if (_serverStatuses.any((s) => s.name == name)) {
      throw Exception('Server with name "$name" already exists');
    }

    final status = McpServerStatus(
      name: name,
      url: url,
      headers: headers,
    );

    try {
      final client = McpClient.createClient(
        name: 'gemini-mcp-client-${name.toLowerCase()}',
        version: '1.0.0',
        capabilities: ClientCapabilities(sampling: true),
      );

      final transport = await McpClient.createSseTransport(
        serverUrl: url,
        headers: headers,
      );

      await client
          .connect(transport)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw McpError('$name connection timeout');
            },
          );

      _clients.add(McpClientInfo(
        name: name,
        client: client,
        status: status,
      ));
      _serverStatuses.add(status);

      status.isConnected = true;
      status.error = null;
      debugPrint('$name MCP connected successfully');
    } catch (e) {
      status.isConnected = false;
      status.error = e.toString();
      debugPrint('$name MCP connection failed: $e');
      rethrow;
    }
  }

  Future<void> removeServer(String name) async {
    final index = _serverStatuses.indexWhere((s) => s.name == name);
    if (index == -1) {
      throw Exception('Server with name "$name" not found');
    }

    final clientInfo = _clients.firstWhere((c) => c.name == name);
    clientInfo.client.disconnect();
    _clients.remove(clientInfo);
    _serverStatuses.removeAt(index);
  }

  Future<void> connectToServer(McpServerStatus status) async {
    try {
      final client = McpClient.createClient(
        name: 'gemini-mcp-client-${status.name.toLowerCase()}',
        version: '1.0.0',
        capabilities: ClientCapabilities(sampling: true),
      );

      final transport = await McpClient.createSseTransport(
        serverUrl: status.url,
        headers: _getHeadersForServer(status.name),
      );

      await client
          .connect(transport)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw McpError('${status.name} connection timeout');
            },
          );

      _clients.add(McpClientInfo(
        name: status.name,
        client: client,
        status: status,
      ));

      status.isConnected = true;
      status.error = null;
      debugPrint('${status.name} MCP connected successfully');
    } catch (e) {
      status.isConnected = false;
      status.error = e.toString();
      debugPrint('${status.name} MCP connection failed: $e');
    }
  }

  Map<String, String> _getHeadersForServer(String serverName) {
    switch (serverName) {
      case 'Notion MCP':
        return {
          'Authorization':
              'Bearer ${const String.fromEnvironment('NOTION_API_KEY')}',
          'Notion-Version': '2022-06-28',
        };
      case 'Spotify MCP':
        return {
          'Authorization':
              'Bearer ${const String.fromEnvironment('SPOTIFY_ACCESS_TOKEN')}',
        };
      default:
        return {};
    }
  }

  void disconnectAll() {
    for (final clientInfo in _clients) {
      clientInfo.client.disconnect();
      clientInfo.status.isConnected = false;
      clientInfo.status.error = null;
    }
    _clients.clear();
    _serverStatuses.clear();
  }

  bool isAnyServerConnected() {
    return _clients.isNotEmpty;
  }

  List<McpClientInfo> get connectedClients => List.unmodifiable(_clients);
}

class McpClientInfo {
  final String name;
  final Client client;
  final McpServerStatus status;

  McpClientInfo({
    required this.name,
    required this.client,
    required this.status,
  });
}
