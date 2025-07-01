/// MCPサーバーの接続状態を管理するクラス
class McpServerStatus {
  final String name;
  final String url;
  final Map<String, String> headers;
  bool isConnected;
  String? error;

  McpServerStatus({
    required this.name,
    required this.url,
    required this.headers,
    this.isConnected = false,
    this.error,
  });
} 