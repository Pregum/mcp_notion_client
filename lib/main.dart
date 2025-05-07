import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcp_client/mcp_client.dart';
import 'gemini_mcp_bridge.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // 3. Gemini モデルの用意
  final geminiModel = await prepareGemini();
  // 2. MCPクライアントの初期化
  final mcpClient = await setupMcpClient(geminiModel: geminiModel);
  runApp(MyApp(mcpClient: mcpClient));
}

late GeminiMcpBridge bridge;

Future<GenerativeModel> prepareGemini() async {
  // Gemini Pro は Function Calling がデフォルト有効。
  final geminiModel = GenerativeModel(
    model: 'models/gemini-2.0-flash',
    apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
  );
  return geminiModel;
}

Future<Client> setupMcpClient({required GenerativeModel geminiModel}) async {
  final mcpClient = McpClient.createClient(
    name: 'gemini-mcp-client',
    version: '1.0.0',
    capabilities: ClientCapabilities(sampling: true),
  );

  try {
    // Notion用のトランスポート
    final notionTransport = await McpClient.createSseTransport(
      serverUrl: 'http://${const String.fromEnvironment('SERVER_IP')}:8000/sse',
      headers: {
        'Authorization':
            'Bearer ${const String.fromEnvironment('NOTION_API_KEY')}',
        'Notion-Version': '2022-06-28',
      },
    );

    // // Spotify用のトランスポート
    // final spotifyTransport = await McpClient.createSseTransport(
    //   serverUrl: 'http://${const String.fromEnvironment('SERVER_IP')}:8001/sse',
    //   headers: {
    //     'Authorization':
    //         'Bearer ${const String.fromEnvironment('SPOTIFY_ACCESS_TOKEN')}',
    //   },
    // );

    // 各トランスポートの接続を個別に試みる
    try {
      await mcpClient.connect(notionTransport).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw McpError('Notion connection timeout');
        },
      );
      debugPrint('Notion MCP connected successfully');
    } catch (e) {
      debugPrint('Notion MCP connection failed: $e');
      // Notionの接続失敗は続行
    }

    // try {
    //   await mcpClient.connect(spotifyTransport).timeout(
    //     const Duration(seconds: 10),
    //     onTimeout: () {
    //       throw McpError('Spotify connection timeout');
    //     },
    //   );
    //   debugPrint('Spotify MCP connected successfully');
    // } catch (e) {
    //   debugPrint('Spotify MCP connection failed: $e');
    //   // Spotifyの接続失敗は続行
    // }

    // ブリッジの初期化
    bridge = GeminiMcpBridge(mcp: mcpClient, model: geminiModel);
    return mcpClient;
  } catch (e) {
    debugPrint('MCP Client setup error: $e');
    // エラーが発生してもクライアントを返す
    return mcpClient;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.mcpClient});
  final Client mcpClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

/// MCPサーバーの接続状態を管理するクラス
class McpServerStatus {
  final String name;
  final String url;
  bool isConnected;
  String? error;

  McpServerStatus({
    required this.name,
    required this.url,
    this.isConnected = false,
    this.error,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final List<McpServerStatus> _serverStatuses = [
    McpServerStatus(
      name: 'Notion MCP',
      url: 'http://${const String.fromEnvironment('SERVER_IP')}:8000/sse',
    ),
    McpServerStatus(
      name: 'Spotify MCP',
      url: 'http://${const String.fromEnvironment('SERVER_IP')}:8001/sse',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
  }

  Future<void> _checkServerStatus() async {
    for (var status in _serverStatuses) {
      try {
        final response = await http.get(Uri.parse(status.url));
        setState(() {
          status.isConnected = response.statusCode == 200;
          status.error = null;
        });
      } catch (e) {
        setState(() {
          status.isConnected = false;
          status.error = e.toString();
        });
      }
    }
  }

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    _textController.clear();

    try {
      // サーバーの接続状態を確認
      final availableServers = _serverStatuses.where((s) => s.isConnected).length;
      if (availableServers == 0) {
        setState(() {
          _messages.add(ChatMessage(
            text: '現在、MCPサーバーに接続できていません。\n'
                'サーバーの状態を確認してください。',
            isUser: false,
          ));
          _isLoading = false;
        });
        return;
      }

      final response = await bridge.chat(text);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('エラーが発生しました: $e, $stackTrace');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'エラーが発生しました: $e\n'
                '一部の機能が利用できない可能性があります。',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerStatus,
            tooltip: 'サーバー状態を更新',
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            primaryFocus?.unfocus();
          },
          child: Column(
            children: [
              // サーバー状態表示
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'MCPサーバー状態',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_serverStatuses.where((s) => s.isConnected).length}/${_serverStatuses.length} 接続中)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._serverStatuses.map((status) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                status.isConnected
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: status.isConnected
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (status.error != null)
                                      Text(
                                        status.error!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const Divider(),
              // 既存のチャットUI
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _messages[index];
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              const Divider(height: 1.0),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: null,
              decoration: const InputDecoration.collapsed(
                hintText: 'メッセージを入力...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(child: Text(isUser ? 'U' : 'A')),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'ユーザー' : 'アシスタント',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: Text(text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
