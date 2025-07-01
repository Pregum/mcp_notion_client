import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcp_client/mcp_client.dart' as mcp_client;
import '../models/mcp_server_status.dart';

class McpTools {
  final List<McpClientInfo> _clients = [];
  final List<McpServerStatus> _serverStatuses = [];

  McpTools() {
    _initializeDefaultServers();
  }

  void _initializeDefaultServers() {
    _serverStatuses.addAll([
      McpServerStatus(
        name: 'Notion MCP',
        url: 'http://${const String.fromEnvironment('SERVER_IP')}:8000/sse',
        headers: {},
      ),
      McpServerStatus(
        name: 'Spotify MCP',
        url: 'http://${const String.fromEnvironment('SERVER_IP')}:8001/sse',
        headers: {},
      ),
    ]);
  }

  List<McpServerStatus> get serverStatuses => List.unmodifiable(_serverStatuses);
  List<McpClientInfo> get connectedClients => List.unmodifiable(_clients);

  /// MCPサーバーへの接続
  Future<void> connectToServer(McpServerStatus status) async {
    try {
      final client = mcp_client.McpClient.createClient(
        name: 'gemini-mcp-client-${status.name.toLowerCase()}',
        version: '1.0.0',
        capabilities: mcp_client.ClientCapabilities(sampling: true),
      );

      final transport = await mcp_client.McpClient.createSseTransport(
        serverUrl: status.url,
        headers: _getHeadersForServer(status.name),
      );

      await client
          .connect(transport)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw mcp_client.McpError('${status.name} connection timeout');
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

  /// 利用可能なツールを取得（MCPサーバーから）
  Future<List<Tool>> getAvailableTools() async {
    final allTools = <mcp_client.Tool>[];
    
    // 接続されている全てのMCPクライアントからツール定義を取得
    for (final clientInfo in _clients) {
      try {
        final tools = await clientInfo.client.listTools();
        allTools.addAll(tools);
      } catch (e) {
        debugPrint('Failed to get tools from ${clientInfo.name}: $e');
      }
    }

    // MCP のツール定義を Gemini 用に変換
    return _toGeminiTools(allTools);
  }

  /// MCPツールの実行
  Future<String> executeTool(String toolName, Map<String, dynamic> args) async {
    debugPrint('Executing MCP tool: $toolName with args: $args');
    
    // 適切なMCPクライアントを探してツールを実行
    for (final clientInfo in _clients) {
      try {
        final tools = await clientInfo.client.listTools();
        if (tools.any((tool) => tool.name == toolName)) {
          final toolResult = await clientInfo.client.callTool(toolName, args);
          
          // エラーチェック
          final resultJson = toolResult.content.map((e) => e.toJson()).toList();
          debugPrint('MCP Tool Result: $resultJson');
          
          // エラーハンドリング
          if (resultJson.isNotEmpty && resultJson[0]['text'] != null) {
            final errorText = resultJson[0]['text'];
            if (errorText is String) {
              try {
                final errorJson = json.decode(errorText);
                if (errorJson['service'] != null) {
                  return _handleServiceError(errorJson);
                }
              } catch (e) {
                // JSON解析エラーは無視して通常の結果として扱う
              }
            }
          }
          
          return _formatToolResult(resultJson);
        }
      } catch (e) {
        debugPrint('Failed to execute tool on ${clientInfo.name}: $e');
      }
    }
    
    throw Exception('Tool "$toolName" not found in any connected MCP server');
  }

  String _handleServiceError(Map<String, dynamic> errorJson) {
    switch (errorJson['service']) {
      case 'notion':
        if (errorJson['code'] == 'unauthorized') {
          return 'NotionのAPIトークンが無効です。有効なAPIトークンを設定してください。';
        }
        break;
      case 'spotify':
        if (errorJson['code'] == 'unauthorized') {
          return 'Spotifyのアクセストークンが無効です。再認証が必要です。';
        } else if (errorJson['code'] == 'rate_limit') {
          return 'Spotifyのレート制限に達しました。しばらく待ってから再試行してください。';
        }
        break;
    }
    return 'エラーが発生しました: ${errorJson['message']}';
  }

  String _formatToolResult(List<Map<String, dynamic>> resultJson) {
    if (resultJson.isEmpty) return '結果が空です';
    
    final firstResult = resultJson[0];
    if (firstResult['text'] != null) {
      return firstResult['text'].toString();
    }
    
    return resultJson.toString();
  }

  /// MCP → Gemini ツール変換
  List<Tool> _toGeminiTools(List<mcp_client.Tool> mcpTools) =>
      mcpTools.map((t) {
        final schema = Schema.object(
          properties: _convertToGeminiSchema(t.inputSchema),
        );

        return Tool(
          functionDeclarations: [
            FunctionDeclaration(t.name, t.description, schema),
          ],
        );
      }).toList();

  /// NotionのスキーマをGeminiのスキーマに変換
  Map<String, Schema> _convertToGeminiSchema(Map<String, dynamic> schema) {
    if (schema['type'] != null && !schema.containsKey('properties')) {
      return {'value': _createBasicSchema(schema['type'] as String)};
    }

    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final convertedProperties = <String, Schema>{};

    properties.forEach((key, value) {
      if (value == null) {
        convertedProperties[key] = Schema.string();
        return;
      }

      final type = value['type'] as String? ?? 'string';
      switch (type) {
        case 'string':
          convertedProperties[key] = Schema.string();
          break;
        case 'object':
          if (value is! Map<String, dynamic>) {
            convertedProperties[key] = Schema.object(properties: {});
          } else {
            convertedProperties[key] = Schema.object(
              properties: _convertToGeminiSchema(value),
            );
          }
          break;
        case 'array':
          if (value['items'] == null) {
            convertedProperties[key] = Schema.array(
              items: Schema.string(),
            );
          } else {
            final itemSchema = value['items'] as Map<String, dynamic>;
            final itemType = itemSchema['type'] as String? ?? 'string';
            convertedProperties[key] = Schema.array(
              items: _createBasicSchema(itemType),
            );
          }
          break;
        default:
          convertedProperties[key] = Schema.string();
      }
    });

    return convertedProperties;
  }

  /// 基本的なスキーマタイプを作成
  Schema _createBasicSchema(String type) {
    switch (type) {
      case 'string':
        return Schema.string();
      case 'number':
        return Schema.number();
      case 'integer':
        return Schema.integer();
      case 'boolean':
        return Schema.boolean();
      case 'object':
        return Schema.object(properties: {});
      case 'array':
        return Schema.array(items: Schema.string());
      default:
        return Schema.string();
    }
  }

  /// ツール一覧をUI用の形式で取得
  Future<List<Map<String, dynamic>>> getToolList() async {
    final allTools = <mcp_client.Tool>[];
    
    for (final clientInfo in _clients) {
      try {
        final tools = await clientInfo.client.listTools();
        allTools.addAll(tools);
      } catch (e) {
        debugPrint('Failed to get tools from ${clientInfo.name}: $e');
      }
    }

    return allTools.map((tool) => {
      'name': tool.name,
      'description': tool.description,
      'parameters': tool.inputSchema,
    }).toList();
  }

  /// サーバー追加
  Future<void> addServer(McpServerStatus serverStatus) async {
    if (_serverStatuses.any((s) => s.name == serverStatus.name)) {
      throw Exception('Server with name "${serverStatus.name}" already exists');
    }
    
    _serverStatuses.add(serverStatus);
    await connectToServer(serverStatus);
  }

  /// サーバー削除
  Future<void> removeServer(String name) async {
    final index = _serverStatuses.indexWhere((s) => s.name == name);
    if (index == -1) {
      throw Exception('Server with name "$name" not found');
    }

    final clientInfo = _clients.where((c) => c.name == name).firstOrNull;
    if (clientInfo != null) {
      clientInfo.client.disconnect();
      _clients.remove(clientInfo);
    }
    _serverStatuses.removeAt(index);
  }

  /// 全サーバーとの切断
  void disconnectAll() {
    for (final clientInfo in _clients) {
      clientInfo.client.disconnect();
      clientInfo.status.isConnected = false;
      clientInfo.status.error = null;
    }
    _clients.clear();
  }

  bool get hasConnectedServers => _clients.isNotEmpty;
}

class McpClientInfo {
  final String name;
  final mcp_client.Client client;
  final McpServerStatus status;

  McpClientInfo({
    required this.name,
    required this.client,
    required this.status,
  });
}