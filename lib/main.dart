import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcp_client/mcp_client.dart';
import 'gemini_mcp_bridge.dart';

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

  final transport = await McpClient.createSseTransport(
    serverUrl: 'http://${const String.fromEnvironment('SERVER_IP')}:8000/sse',
    headers: {
      'Authorization':
          'Bearer ${const String.fromEnvironment('NOTION_API_KEY')}',
      'Notion-Version': '2022-06-28',
    },
  );
  await mcpClient.connect(transport);

  // ブリッジの初期化
  bridge = GeminiMcpBridge(mcp: mcpClient, model: geminiModel);
  return mcpClient;
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

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _textController.clear();

    try {
      final response = await bridge.chat(text);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('エラーが発生しました: $e, $stackTrace');
      setState(() {
        _messages.add(
          ChatMessage(text: 'エラーが発生しました: $e, $stackTrace', isUser: false),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
