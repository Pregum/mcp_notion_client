import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_message.dart';

class Step1ChatScreen extends StatefulWidget {
  const Step1ChatScreen({super.key});

  @override
  State<Step1ChatScreen> createState() => _Step1ChatScreenState();
}

class _Step1ChatScreenState extends State<Step1ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  final ScrollController _scrollController = ScrollController();
  late GenerativeModel _model;
  final List<Content> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      _model = GenerativeModel(
        model: 'models/gemini-2.0-flash',
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      );
      
      // 初期メッセージを追加
      _messages.add(
        const ChatMessage(
          text: 'Step 1: Flutter x Gemini 接続が完了しました！\n'
              'このステップでは基本的なチャット機能のみ利用できます。\n'
              'ツールは未実装です。',
          isUser: false,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
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
      final userContent = Content.text(text);
      _chatHistory.add(userContent);

      final response = await _model.generateContent(_chatHistory);
      final responseText = response.text ?? 'レスポンスを生成できませんでした。';

      _chatHistory.add(Content.text(responseText));

      setState(() {
        _messages.add(ChatMessage(text: responseText, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('エラーが発生しました: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'エラーが発生しました: $e',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showToolList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('利用可能なツール'),
        content: const Text(
          'Step 1 では、まだツールは実装されていません。\n'
          'Step 2 でローカルツールが追加されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearHistory() {
    setState(() {
      _messages.clear();
      _chatHistory.clear();
    });
    
    // 初期メッセージを再追加
    _messages.add(
      const ChatMessage(
        text: 'チャット履歴をクリアしました。',
        isUser: false,
      ),
    );
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
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Gemini を初期化中...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1: Flutter x Gemini'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: _showToolList,
            tooltip: 'ツール一覧',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearHistory,
            tooltip: '履歴クリア',
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
              // ステップ情報パネル
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1: Flutter x Gemini 基本接続',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Gemini API との基本的なチャット機能\n'
                      '• ツール機能は未実装（ツールボタンで確認可能）',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // チャット領域
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