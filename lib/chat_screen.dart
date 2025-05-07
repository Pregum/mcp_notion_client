import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcp_client/mcp_client.dart';
import 'gemini_mcp_bridge.dart';
import 'chat_message.dart';
import 'server_status_panel.dart';
import 'mcp_client_manager.dart';
import 'add_server_dialog.dart';

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
  late McpClientManager _mcpManager;
  late GeminiMcpBridge _bridge;

  @override
  void initState() {
    super.initState();
    _initializeMcpClient();
  }

  Future<GenerativeModel> prepareGemini() async {
    final geminiModel = GenerativeModel(
      model: 'models/gemini-2.0-flash',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    );
    return geminiModel;
  }

  Future<void> _initializeMcpClient() async {
    final geminiModel = await prepareGemini();
    _mcpManager = McpClientManager();
    _bridge = GeminiMcpBridge(mcpManager: _mcpManager, model: geminiModel);
    _bridge.clearHistory();

    setState(() {
      _messages.clear();
    });

    // 各サーバーに接続を試みる
    for (final status in _mcpManager.serverStatuses) {
      await _mcpManager.connectToServer(status);
      setState(() {}); // UIを更新
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
      // if (!_mcpManager.isAnyServerConnected()) {
      //   setState(() {
      //     _messages.add(
      //       ChatMessage(
      //         text:
      //             '現在、MCPサーバーに接続できていません。\n'
      //             'サーバーの状態を確認してください。',
      //         isUser: false,
      //       ),
      //     );
      //     _isLoading = false;
      //   });
      //   return;
      // }

      final response = await _bridge.chat(text);
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

  Future<void> _addServer() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddServerDialog(),
    );

    if (result != null) {
      final serverStatus = McpServerStatus(
        name: result['name'],
        url: result['url'],
        headers: result['headers'],
        isConnected: false,
        error: null,
      );

      await _mcpManager.addServer(
        serverStatus,
        name: result['name'],
        url: result['url'],
        headers: result['headers'],
      );
      setState(() {}); // UIを更新
    }
  }

  Future<void> _deleteServer(String serverName) async {
    try {
      await _mcpManager.removeServer(serverName);
      setState(() {}); // UIを更新
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('サーバーの削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addServer,
            tooltip: 'サーバーを追加',
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
              ServerStatusPanel(
                serverStatuses: _mcpManager.serverStatuses,
                onRefresh: _initializeMcpClient,
                onDelete: _deleteServer,
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
