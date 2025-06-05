import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:mcp_notion_client/models/mcp_server_status.dart';
import '../services/gemini_mcp_bridge.dart';
import '../services/firebase_ai_bridge.dart';
import '../services/firebase_ai_service.dart';
import '../models/chat_message.dart';
import '../components/server_status_panel.dart';
import '../services/mcp_client_manager.dart';
import '../components/add_server_dialog.dart';
import '../models/gemini_model_config.dart';
import '../components/model_selector_dialog.dart';
import '../components/tool_list_dialog.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true; // 初期化状態を管理するフラグを追加
  final ScrollController _scrollController = ScrollController();
  late McpClientManager _mcpManager;
  late GeminiMcpBridge _bridge;
  FirebaseAiBridge? _firebaseBridge;

  // Thinking関連の状態
  ChatMessage? _currentThinkingMessage;

  // モデル関連の状態
  GeminiModelConfig _currentModel = GeminiModelConfig.defaultModel;

  @override
  void initState() {
    super.initState();
    _initializeMcpClient();
  }

  Future<dynamic> prepareModel([GeminiModelConfig? modelConfig]) async {
    final config = modelConfig ?? _currentModel;

    if (config.isFirebaseAi) {
      // Firebase AI モデル
      try {
        await FirebaseAiService.instance.initialize(
          apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
        );
        return FirebaseAiService.instance.createModel(config.modelId);
      } catch (e) {
        debugPrint('Firebase AI initialization failed: $e');
        // フォールバックとして Google Generative AI を使用
        return google_ai.GenerativeModel(
          model: 'models/gemini-2.0-flash',
          apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
        );
      }
    } else {
      // Google Generative AI モデル
      final model = FirebaseAI.googleAI().generativeModel(
        model: config.modelId,
        generationConfig: GenerationConfig(),
      );
      return model;
    }
  }

  Future<void> _initializeMcpClient() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      debugPrint(
        '🚀 Initializing MCP client with model: ${_currentModel.displayName}',
      );
      debugPrint('🚀 Model details:');
      debugPrint('  - Model ID: ${_currentModel.modelId}');
      debugPrint('  - Provider: ${_currentModel.provider}');
      debugPrint('  - Is Firebase AI: ${_currentModel.isFirebaseAi}');
      debugPrint(
        '  - Is Google Generative AI: ${_currentModel.isGoogleGenerativeAi}',
      );

      final model = await prepareModel();
      _mcpManager = McpClientManager();

      // Firebase AI か Google Generative AI かでブリッジを選択
      if (_currentModel.isFirebaseAi && model is firebase_ai.GenerativeModel) {
        _firebaseBridge = FirebaseAiBridge(
          mcpManager: _mcpManager,
          model: model,
          onThinking: _handleThinking,
        );
        _firebaseBridge!.clearHistory();
        debugPrint('Using Firebase AI Bridge');
      } else {
        _bridge = GeminiMcpBridge(
          mcpManager: _mcpManager,
          model: model,
          onThinking: _handleThinking,
        );
        _bridge.clearHistory();
        debugPrint('Using Google Generative AI Bridge');
      }

      _messages.clear();

      // thinking状態をリセット
      _clearThinking();

      // 各サーバーに接続を試みる
      for (final status in _mcpManager.serverStatuses) {
        await _mcpManager.connectToServer(status);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _changeModel() async {
    final selectedModel = await showDialog<GeminiModelConfig?>(
      context: context,
      builder: (context) => ModelSelectorDialog(currentModel: _currentModel),
    );

    if (selectedModel != null && selectedModel != _currentModel) {
      debugPrint(
        '🔄 Model changed from ${_currentModel.displayName} to ${selectedModel.displayName}',
      );
      debugPrint('🔄 New model details:');
      debugPrint('  - Model ID: ${selectedModel.modelId}');
      debugPrint('  - Provider: ${selectedModel.provider}');
      debugPrint('  - Is experimental: ${selectedModel.isExperimental}');
      debugPrint(
        '  - Supports thinking (expected): ${selectedModel.modelId.contains('2.5')}',
      );

      setState(() {
        _currentModel = selectedModel;
      });

      // 新しいモデルでブリッジを更新
      await _initializeMcpClient();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('モデルを${selectedModel.displayName}に変更しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleThinking(ThinkingStep step, String message) {
    // 実際の思考情報がある場合のみ表示（疑似的な思考ステップは表示しない）
    if (step == ThinkingStep.planning && message.length > 50) {
      // 十分な思考内容がある場合のみ表示
      setState(() {
        if (_currentThinkingMessage == null) {
          // 初回のthinkingメッセージを作成
          _currentThinkingMessage = ChatMessage.thinking(
            currentStep: step,
            thinkingSteps: ['思考中...'],
          );
          _messages.add(_currentThinkingMessage!);
        } else {
          // 既存のthinkingメッセージを更新
          final index = _messages.indexOf(_currentThinkingMessage!);
          if (index != -1) {
            _messages[index] = ChatMessage.thinking(
              currentStep: step,
              thinkingSteps: ['思考中...'],
            );
            _currentThinkingMessage = _messages[index];
          }
        }
      });
      _scrollToBottom();
    }
  }

  void _clearThinking() {
    if (_currentThinkingMessage != null) {
      setState(() {
        _messages.remove(_currentThinkingMessage!);
        _currentThinkingMessage = null;
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

      // 思考情報付きレスポンスを取得
      debugPrint(
        '💭 Getting thinking response for model: ${_currentModel.displayName}',
      );
      final thinkingResponse =
          _currentModel.isFirebaseAi && _firebaseBridge != null
              ? null // Firebase AIは現在思考情報をサポートしていない
              : await _bridge.chatWithThinking(
                text,
                modelDisplayName: _currentModel.displayName,
              );

      String responseText;
      String? thinkingContent;

      if (thinkingResponse != null) {
        // Google Generative AI (思考情報対応)
        responseText = thinkingResponse.text;
        thinkingContent =
            thinkingResponse.thoughts.isNotEmpty
                ? thinkingResponse.thoughts
                : null;

        debugPrint('💭 Thinking response received:');
        debugPrint('  - Response text length: ${responseText.length}');
        debugPrint(
          '  - Thinking content length: ${thinkingResponse.thoughts.length}',
        );
        debugPrint('  - Has thinking content: ${thinkingContent != null}');

        if (thinkingContent != null) {
          debugPrint(
            '💭 Thinking preview: ${thinkingContent.substring(0, thinkingContent.length > 100 ? 100 : thinkingContent.length)}...',
          );
        }
      } else {
        // Firebase AI (通常の応答)
        responseText = await _firebaseBridge!.chat(text);
        thinkingContent = null;
        debugPrint(
          '💭 Firebase AI response (no thinking): ${responseText.length} chars',
        );
      }

      // thinkingメッセージを削除して回答を追加
      _clearThinking();

      setState(() {
        if (thinkingContent != null && thinkingContent.isNotEmpty) {
          // 思考情報付きメッセージ
          debugPrint('💭 Adding message with thinking content');
          _messages.add(
            ChatMessage.withThoughts(
              text: responseText,
              actualThoughts: thinkingContent,
            ),
          );
        } else {
          // 通常のメッセージ
          debugPrint('💭 Adding regular message (no thinking)');
          _messages.add(ChatMessage(text: responseText, isUser: false));
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('エラーが発生しました: $e, $stackTrace');

      // thinkingメッセージを削除
      _clearThinking();

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
        headers: Map<String, String>.from(result['headers'] as Map),
        isConnected: false,
        error: null,
      );

      await _mcpManager.addServer(
        serverStatus,
        name: result['name'],
        url: result['url'],
        headers: Map<String, String>.from(result['headers'] as Map),
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

  Future<void> _showToolList() async {
    await showDialog(
      context: context,
      builder: (context) => ToolListDialog(mcpManager: _mcpManager),
    );
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
                'MCPクライアントを初期化中...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'MCP Assistant',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton.outlined(
              icon: const Icon(Icons.build_rounded),
              onPressed: _showToolList,
              tooltip: 'ツール一覧を表示',
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton.outlined(
              icon: const Icon(Icons.psychology_rounded),
              onPressed: _changeModel,
              tooltip: 'AIモデルを変更',
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton.filled(
              icon: const Icon(Icons.add_rounded),
              onPressed: _addServer,
              tooltip: 'サーバーを追加',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
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
              // 現在のモデル表示
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '現在のモデル: ${_currentModel.displayName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    if (_currentModel.isExperimental) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'BETA',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              // 既存のチャットUI
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: _messages[index],
                    );
                  },
                ),
              ),
              if (_isLoading)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '処理中...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1.0),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
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
      margin: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () => _handleSubmitted(_textController.text),
              color: Theme.of(context).colorScheme.onPrimary,
              iconSize: 20,
            ),
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
