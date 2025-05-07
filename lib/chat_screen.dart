import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcp_client/mcp_client.dart';
import 'gemini_mcp_bridge.dart';
import 'chat_message.dart';
import 'server_status_panel.dart';

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
  late GeminiMcpBridge bridge;
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
    // MCPクライアントの初期化 + Geminiモデルの用意 + MCPサーバーとの接続
    _initializeMcpClient();
  }

  Future<GenerativeModel> prepareGemini() async {
    // Gemini Pro は Function Calling がデフォルト有効。
    final geminiModel = GenerativeModel(
      model: 'models/gemini-2.0-flash',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    );
    return geminiModel;
  }

  Future<GeminiMcpBridge> setupMcpClient({
    required GenerativeModel geminiModel,
  }) async {
    final mcpClient = McpClient.createClient(
      name: 'gemini-mcp-client',
      version: '1.0.0',
      capabilities: ClientCapabilities(sampling: true),
    );

    // ブリッジの初期化
    final bridge = GeminiMcpBridge(mcp: mcpClient, model: geminiModel);
    return bridge;
  }

  Future<void> _initializeMcpClient() async {
    final geminiModel = await prepareGemini();
    bridge = await setupMcpClient(geminiModel: geminiModel);
    bridge.clearHistory();
    setState(() {
      _messages.clear();
    });
    try {
      // Notion用のトランスポート
      final notionTransport = await McpClient.createSseTransport(
        serverUrl:
            'http://${const String.fromEnvironment('SERVER_IP')}:8000/sse',
        headers: {
          'Authorization':
              'Bearer ${const String.fromEnvironment('NOTION_API_KEY')}',
          'Notion-Version': '2022-06-28',
        },
      );

      try {
        await bridge.mcp
            .connect(notionTransport)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw McpError('Notion connection timeout');
              },
            );
        debugPrint('Notion MCP connected successfully');
        setState(() {
          _serverStatuses[0].isConnected = true;
          _serverStatuses[0].error = null;
        });
      } catch (e) {
        debugPrint('Notion MCP connection failed: $e');
        setState(() {
          _serverStatuses[0].isConnected = false;
          _serverStatuses[0].error = e.toString();
        });
      }
    } catch (e) {
      debugPrint('MCP Client setup error: $e');
      setState(() {
        _serverStatuses[0].isConnected = false;
        _serverStatuses[0].error = e.toString();
      });
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
      final availableServers =
          _serverStatuses.where((s) => s.isConnected).length;
      if (availableServers == 0) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  '現在、MCPサーバーに接続できていません。\n'
                  'サーバーの状態を確認してください。',
              isUser: false,
            ),
          );
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
            text:
                'エラーが発生しました: $e\n'
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
      appBar: AppBar(title: const Text('MCP Demo')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            primaryFocus?.unfocus();
          },
          child: Column(
            children: [
              ServerStatusPanel(
                serverStatuses: _serverStatuses,
                onRefresh: _initializeMcpClient,
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
