import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_message.dart';
import '../services/local_tools.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
        tools: LocalTools.tools,
      );
      
      // 初期メッセージを追加
      _messages.add(
        const ChatMessage(
          text: 'Step 2: Flutter x Gemini x ローカルツール 接続が完了しました！\n'
              'このステップではローカルツールが利用できます：\n'
              '• hello_gemini: Geminiに挨拶\n'
              '• calculate: 2つの整数の計算\n'
              '• web_search: Web検索（モック）\n\n'
              '「こんにちは」「5と3を足して」「Flutterについて調べて」などと話しかけてみてください！',
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
      
      // Function call があるかチェック
      if (response.functionCalls.isNotEmpty) {
        await _handleFunctionCalls(response.functionCalls.toList());
      } else {
        final responseText = response.text ?? 'レスポンスを生成できませんでした。';
        _chatHistory.add(Content.text(responseText));

        setState(() {
          _messages.add(ChatMessage(text: responseText, isUser: false));
          _isLoading = false;
        });
      }
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

  Future<void> _handleFunctionCalls(List<FunctionCall> functionCalls) async {
    final List<FunctionResponse> responses = [];

    for (final call in functionCalls) {
      try {
        final result = await LocalTools.executeTool(call.name, call.args);
        responses.add(FunctionResponse(call.name, {'result': result}));
        
        // ツール実行を表示（結果は含めない）
        setState(() {
          _messages.add(ChatMessage(
            text: '🔧 ツール実行: ${call.name}',
            isUser: false,
          ));
        });
      } catch (e) {
        responses.add(FunctionResponse(call.name, {'error': e.toString()}));
        setState(() {
          _messages.add(ChatMessage(
            text: '🔧 ツール実行エラー: ${call.name}\nエラー: $e',
            isUser: false,
          ));
        });
      }
    }

    // Function call とその応答をチャット履歴に正しく記録
    _chatHistory.add(Content.model(functionCalls));
    _chatHistory.add(Content.functionResponses(responses));

    // Function call の結果を含めて再度 Gemini に送信
    try {
      final followUpResponse = await _model.generateContent(_chatHistory);

      final responseText = followUpResponse.text ?? 'フォローアップレスポンスを生成できませんでした。';
      _chatHistory.add(Content.text(responseText));

      setState(() {
        _messages.add(ChatMessage(text: responseText, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'フォローアップレスポンスの生成でエラーが発生しました: $e',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  void _showToolList() {
    final tools = LocalTools.getToolList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('利用可能なツール'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return Card(
                child: ListTile(
                  title: Text(tool['name']),
                  subtitle: Text(tool['description']),
                  trailing: ElevatedButton(
                    onPressed: () => _showToolExecutionDialog(tool),
                    child: const Text('実行'),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showToolExecutionDialog(Map<String, dynamic> tool) {
    Navigator.of(context).pop(); // ツール一覧ダイアログを閉じる
    
    final Map<String, TextEditingController> controllers = {};
    final parameters = tool['parameters'] as Map<dynamic, dynamic>;
    
    for (final param in parameters.entries) {
      controllers[param.key] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${tool['name']} を実行'),
        content: parameters.isEmpty
            ? const Text('このツールにはパラメーターがありません。')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: parameters.entries.map((param) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: controllers[param.key],
                      decoration: InputDecoration(
                        labelText: param.key,
                        hintText: param.value['description'],
                      ),
                      keyboardType: param.value['type'] == 'integer'
                          ? TextInputType.number
                          : TextInputType.text,
                    ),
                  );
                }).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _executeToolManually(tool['name'], controllers);
            },
            child: const Text('実行'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeToolManually(String toolName, Map<String, TextEditingController> controllers) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> args = {};
      for (final entry in controllers.entries) {
        final value = entry.value.text;
        if (value.isNotEmpty) {
          // 型変換を試行
          if (toolName == 'calculate' && (entry.key == 'a' || entry.key == 'b')) {
            args[entry.key] = int.tryParse(value) ?? 0;
          } else {
            args[entry.key] = value;
          }
        }
      }

      final result = await LocalTools.executeTool(toolName, args);
      
      setState(() {
        _messages.add(ChatMessage(
          text: '🔧 手動実行: $toolName\n結果: $result',
          isUser: false,
        ));
        _isLoading = false;
      });

      // コントローラーを破棄
      for (final controller in controllers.values) {
        controller.dispose();
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '🔧 手動実行エラー: $toolName\nエラー: $e',
          isUser: false,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
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
                'Gemini + ローカルツール を初期化中...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2: Flutter x Gemini x Local Tools'),
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
                      'Step 2: Flutter x Gemini x ローカルツール',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Gemini API との Function Calling\n'
                      '• 3つのローカルツール（挨拶、計算、Web検索）\n'
                      '• ツール手動実行とAI自動選択の両方に対応',
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