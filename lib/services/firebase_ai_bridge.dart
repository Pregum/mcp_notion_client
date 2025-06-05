import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:mcp_client/mcp_client.dart' as mcp_client;
import 'mcp_client_manager.dart';
import '../models/chat_message.dart';

typedef ThinkingCallback = void Function(ThinkingStep step, String message);

class FirebaseAiBridge {
  final McpClientManager _mcpManager;
  final GenerativeModel model;
  final List<Content> _chatHistory = [];
  ThinkingCallback? _thinkingCallback;

  FirebaseAiBridge({
    required McpClientManager mcpManager,
    required this.model,
    ThinkingCallback? onThinking,
  }) : _mcpManager = mcpManager,
       _thinkingCallback = onThinking;

  void setThinkingCallback(ThinkingCallback? callback) {
    _thinkingCallback = callback;
  }
  
  void updateModel(GenerativeModel newModel) {
    // Firebase AIでは直接モデル変更はできないため、新しいインスタンスが必要
    debugPrint('Firebase AI: Model update requested - ${newModel.toString()}');
    clearHistory();
  }

  /// ユーザー入力を渡して最終テキストを返す
  Future<String> chat(String userPrompt) async {
    try {
      // Thinking step 1: ユーザー入力の理解
      _notifyThinking(ThinkingStep.understanding, 'ユーザーの質問を分析しています...');
      
      // 1) 接続されている全てのMCPクライアントからツール定義を取得
      _notifyThinking(ThinkingStep.planning, '利用可能なツールを確認しています...');
      final allTools = <mcp_client.Tool>[];
      for (final clientInfo in _mcpManager.connectedClients) {
        try {
          final tools = await clientInfo.client.listTools();
          allTools.addAll(tools);
        } catch (e) {
          debugPrint('Failed to get tools from ${clientInfo.name}: $e');
        }
      }

      // 2) MCP のツール定義を Firebase AI 用に変換
      final firebaseTools = _toFirebaseTools(allTools);
      debugPrint('Firebase AI Tools: ${firebaseTools.length}個');
      
      _notifyThinking(ThinkingStep.planning, '実行計画を立てています...');

      // 3) Firebase AI へ投げる（ユーザー発話）
      final userContent = Content.text(userPrompt);
      _chatHistory.add(userContent);

      final first = await model.generateContent(
        _chatHistory,
        tools: firebaseTools,
      );

      // Firebase AI レスポンスの詳細確認（thinking情報検索）
      debugPrint('=== Firebase AI GenerateContentResponse ===');
      _extractThinkingFromResponse(first);
      
      // 4) 関数呼び出しがあるか確認
      final functionCalls = first.functionCalls.toList();
      if (functionCalls.isEmpty) {
        _notifyThinking(ThinkingStep.completed, '回答を生成しました');
        final response = first.text ?? '';
        _chatHistory.add(Content.text(response));
        return response;
      }

      // 5) 複数のツール実行を順次処理
      final toolResults = <FunctionCall>[];
      final toolResponses = <Map<String, dynamic>>[];
      
      for (final call in functionCalls) {
        _notifyThinking(ThinkingStep.executing, '${call.name}ツールを実行しています...');
        mcp_client.CallToolResult? toolResult;
        String? errorMessage;

        // 適切なMCPクライアントを探してツールを実行
        for (final clientInfo in _mcpManager.connectedClients) {
          try {
            final tools = await clientInfo.client.listTools();
            if (tools.any((tool) => tool.name == call.name)) {
              toolResult = await clientInfo.client.callTool(call.name, call.args);
              break;
            }
          } catch (e) {
            errorMessage = 'Failed to execute tool on ${clientInfo.name}: $e';
            debugPrint(errorMessage);
          }
        }

        if (toolResult == null) {
          debugPrint('Tool ${call.name} not found in any connected MCP server: $errorMessage');
          // ツールが見つからなくても続行
          toolResponses.add({
            'result': 'ツール ${call.name} が見つかりませんでした: ${errorMessage ?? 'Unknown error'}'
          });
          continue;
        }

        // デバッグ用のログ出力
        debugPrint('Tool ${call.name} Result Content: ${toolResult.content}');
        final resultJson = toolResult.content.map((e) => e.toJson()).toList();
        debugPrint('Result JSON: $resultJson');

        toolResults.add(call);
        toolResponses.add({'result': resultJson});
      }

      // 6) 実行結果を Firebase AI に返し、要約を生成
      _notifyThinking(ThinkingStep.completed, '実行結果を整理して回答を生成しています...');
      
      final followUpContent = [
        ..._chatHistory,
        Content.text('以下の実行結果を日本語で分かりやすく要約してください：'),
        Content.model(toolResults),
      ];
      
      // 各ツールの実行結果を追加
      for (int i = 0; i < toolResults.length; i++) {
        followUpContent.add(
          Content.functionResponse(toolResults[i].name, toolResponses[i])
        );
      }
      
      final followUp = await model.generateContent(followUpContent);

      final response = followUp.text ?? 'レスポンスを生成できませんでした。';
      _chatHistory.add(Content.text(response));
      return response;
    } catch (e, stackTrace) {
      debugPrint('Error in Firebase AI chat: $e\n$stackTrace');
      return 'エラーが発生しました: $e';
    }
  }

  /// チャット履歴をクリアする
  void clearHistory() {
    _chatHistory.clear();
  }

  /// MCP → Firebase AI ツール変換
  List<Tool> _toFirebaseTools(List<mcp_client.Tool> infos) =>
      infos.map((t) {
        // JSON Schema → パラメータマップに変換（Firebase AI版）
        final parameters = _convertToFirebaseSchema(t.inputSchema);

        return Tool.functionDeclarations([
          FunctionDeclaration(
            t.name, 
            t.description,
            parameters: parameters,
          ),
        ]);
      }).toList();

  /// NotionのスキーマをFirebase AIのスキーマに変換
  Map<String, Schema> _convertToFirebaseSchema(Map<String, dynamic> schema) {
    // スキーマがプリミティブ型の場合
    if (schema['type'] != null && !schema.containsKey('properties')) {
      return {'value': _createBasicFirebaseSchema(schema['type'] as String)};
    }

    // propertiesが存在しない場合は空のオブジェクトを返す
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final convertedProperties = <String, Schema>{};

    properties.forEach((key, value) {
      if (value == null) {
        convertedProperties[key] = Schema.string(); // デフォルト値
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
              properties: _convertToFirebaseSchema(value),
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
              items: _createBasicFirebaseSchema(itemType),
            );
          }
          break;
        default:
          convertedProperties[key] = Schema.string();
      }
    });

    return convertedProperties;
  }

  /// 基本的なスキーマタイプを作成（Firebase AI版）
  Schema _createBasicFirebaseSchema(String type) {
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
  
  void _notifyThinking(ThinkingStep step, String message) {
    _thinkingCallback?.call(step, message);
  }
  
  /// Firebase AI レスポンスからthinking情報を抽出（実験的）
  void _extractThinkingFromResponse(GenerateContentResponse response) {
    try {
      debugPrint('Firebase AI Response Analysis:');
      debugPrint('Candidates: ${response.candidates.length}');
      
      for (var i = 0; i < response.candidates.length; i++) {
        final candidate = response.candidates[i];
        debugPrint('Candidate $i:');
        debugPrint('  - Text: ${candidate.text}');
        debugPrint('  - Finish Reason: ${candidate.finishReason}');
        
        // Content partsを詳しく確認（thinking情報が含まれている可能性）
        if (candidate.content.parts.isNotEmpty) {
          debugPrint('  - Content Parts: ${candidate.content.parts.length}件');
          for (var j = 0; j < candidate.content.parts.length; j++) {
            final part = candidate.content.parts[j];
            debugPrint('    Part $j: ${part.toString()}');
            
            // Firebase AIでthinking情報がある場合の特別な処理
            final partText = part.toString().toLowerCase();
            if (partText.contains('thinking') || 
                partText.contains('reasoning') || 
                partText.contains('thought') ||
                partText.contains('考え') ||
                partText.contains('思考')) {
              debugPrint('🧠 Potential thinking content detected in Firebase AI response!');
              debugPrint('Content: ${part.toString()}');
              
              // 実際のthinking情報が取得できた場合の処理をここに追加
              _processThinkingContent(part.toString());
            }
          }
        }
        
        // Safety ratingsをチェック
        if (candidate.safetyRatings != null) {
          debugPrint('  - Safety Ratings: ${candidate.safetyRatings!.length}件');
        }
      }
    } catch (e) {
      debugPrint('Error extracting thinking info from Firebase AI: $e');
    }
  }
  
  /// 検出されたthinking内容を処理
  void _processThinkingContent(String thinkingText) {
    debugPrint('Processing thinking content: $thinkingText');
    
    // thinking内容を解析してステップに分解
    if (thinkingText.contains('analysis') || thinkingText.contains('分析')) {
      _notifyThinking(ThinkingStep.understanding, 'AI思考: $thinkingText');
    } else if (thinkingText.contains('plan') || thinkingText.contains('計画')) {
      _notifyThinking(ThinkingStep.planning, 'AI思考: $thinkingText');
    } else if (thinkingText.contains('execute') || thinkingText.contains('実行')) {
      _notifyThinking(ThinkingStep.executing, 'AI思考: $thinkingText');
    }
  }
}