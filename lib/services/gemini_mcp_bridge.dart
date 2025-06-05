import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:mcp_client/mcp_client.dart' as mcp_client;
import 'mcp_client_manager.dart';
import '../models/chat_message.dart';

typedef ThinkingCallback = void Function(ThinkingStep step, String message);

class GeminiMcpBridge {
  final McpClientManager _mcpManager;
  gemini.GenerativeModel model;
  final List<gemini.Content> _chatHistory = [];
  ThinkingCallback? _thinkingCallback;

  GeminiMcpBridge({
    required McpClientManager mcpManager,
    required this.model,
    ThinkingCallback? onThinking,
  }) : _mcpManager = mcpManager,
       _thinkingCallback = onThinking;

  void setThinkingCallback(ThinkingCallback? callback) {
    _thinkingCallback = callback;
  }
  
  void updateModel(gemini.GenerativeModel newModel) {
    model = newModel;
    // モデル変更時はチャット履歴をクリア
    clearHistory();
  }

  /// ユーザー入力を渡して最終テキストを返す
  Future<String> chat(String userPrompt) async {
    try {
      // Thinking step 1: ユーザー入力の理解
      _notifyThinking(ThinkingStep.understanding, 'ユーザーの質問を分析しています...');
      
      // // 接続されているMCPクライアントがない場合はエラー
      // if (!_mcpManager.isAnyServerConnected()) {
      //   throw Exception('No connected MCP servers available');
      // }

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

      // 2) MCP のツール定義を Gemini 用に変換
      final geminiTools = _toGeminiTools(allTools);
      debugPrint(
        'Gemini Tools: ${geminiTools.map((e) => e.functionDeclarations?.firstOrNull?.name)}',
      );
      
      _notifyThinking(ThinkingStep.planning, '実行計画を立てています...');

      // 3) LLM へ投げる（ユーザー発話）
      final userContent = gemini.Content.text(userPrompt);
      _chatHistory.add(userContent);

      final first = await model.generateContent(
        _chatHistory,
        tools: geminiTools,
      );

      // デバッグ出力を追加（thinking情報も確認）
      debugPrint('=== GenerateContentResponse ===');
      debugPrint('Candidates: ${first.candidates.length}件');
      for (var i = 0; i < first.candidates.length; i++) {
        final candidate = first.candidates[i];
        debugPrint('Candidate $i:');
        debugPrint('  - Text: ${candidate.text}');
        debugPrint('  - Finish Reason: ${candidate.finishReason}');
        debugPrint('  - Finish Message: ${candidate.finishMessage}');
        
        // Content partsを詳しく確認（thinking情報が含まれている可能性）
        if (candidate.content.parts.isNotEmpty) {
          debugPrint('  - Content Parts: ${candidate.content.parts.length}件');
          for (var j = 0; j < candidate.content.parts.length; j++) {
            final part = candidate.content.parts[j];
            debugPrint('    Part $j: ${part.toString()}');
          }
        }
        
        if (candidate.safetyRatings != null) {
          debugPrint('  - Safety Ratings:');
          for (final rating in candidate.safetyRatings!) {
            debugPrint(
              '    * Category: ${rating.category}, Probability: ${rating.probability}',
            );
          }
        }
      }

      if (first.promptFeedback != null) {
        debugPrint('Prompt Feedback:');
        debugPrint('  - Block Reason: ${first.promptFeedback?.blockReason}');
        debugPrint(
          '  - Block Reason Message: ${first.promptFeedback?.blockReasonMessage}',
        );
        if (first.promptFeedback?.safetyRatings.isNotEmpty ?? false) {
          debugPrint('  - Safety Ratings:');
          for (final rating in first.promptFeedback!.safetyRatings) {
            debugPrint(
              '    * Category: ${rating.category}, Probability: ${rating.probability}',
            );
          }
        }
      }

      if (first.usageMetadata != null) {
        debugPrint('Usage Metadata:');
        debugPrint(
          '  - Prompt Token Count: ${first.usageMetadata?.promptTokenCount}',
        );
        debugPrint(
          '  - Candidates Token Count: ${first.usageMetadata?.candidatesTokenCount}',
        );
        debugPrint(
          '  - Total Token Count: ${first.usageMetadata?.totalTokenCount}',
        );
      }
      debugPrint('===========================');

      // Thinking情報の抽出を試行
      _extractThinkingFromResponse(first);
      
      // 4) 関数呼び出しがあるか確認
      final functionCalls = first.functionCalls.toList();
      if (functionCalls.isEmpty) {
        _notifyThinking(ThinkingStep.completed, '回答を生成しました');
        final response = first.text ?? '';
        _chatHistory.add(gemini.Content.text(response));
        return response;
      }

      // 5) 複数のツール実行を順次処理
      final toolResults = <gemini.FunctionCall>[];
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

        // エラーチェック
        if (resultJson.isNotEmpty && resultJson[0]['text'] != null) {
          final errorText = resultJson[0]['text'];
          if (errorText is String) {
            try {
              final errorJson = json.decode(errorText);
              debugPrint('Error JSON - service: ${errorJson['service']}');
              // サービスごとのエラーハンドリング
              switch (errorJson['service']) {
                case 'notion':
                  if (errorJson['code'] == 'unauthorized') {
                    toolResponses.add({
                      'result': 'NotionのAPIトークンが無効です。有効なAPIトークンを設定してください。'
                    });
                    continue;
                  }
                  break;

                case 'spotify':
                  if (errorJson['code'] == 'unauthorized') {
                    toolResponses.add({
                      'result': 'Spotifyのアクセストークンが無効です。再認証が必要です。'
                    });
                    continue;
                  } else if (errorJson['code'] == 'rate_limit') {
                    toolResponses.add({
                      'result': 'Spotifyのレート制限に達しました。しばらく待ってから再試行してください。'
                    });
                    continue;
                  }
                  break;

                default:
                  toolResponses.add({
                    'result': 'エラーが発生しました: ${errorJson['message']}'
                  });
                  continue;
              }
            } catch (e) {
              // JSON解析エラーは無視
            }
          }
        }

        toolResults.add(call);
        toolResponses.add({'result': resultJson});
      }

      // 6) 実行結果を LLM に返し、要約を生成
      _notifyThinking(ThinkingStep.completed, '実行結果を整理して回答を生成しています...');
      
      final followUpContent = [
        ..._chatHistory,
        gemini.Content.text('以下の実行結果を日本語で分かりやすく要約してください：'),
        gemini.Content.model(toolResults),
      ];
      
      // 各ツールの実行結果を追加
      for (int i = 0; i < toolResults.length; i++) {
        followUpContent.add(
          gemini.Content.functionResponse(toolResults[i].name, toolResponses[i])
        );
      }
      
      final followUp = await model.generateContent(followUpContent);

      final response = followUp.text ?? 'レスポンスを生成できませんでした。';
      _chatHistory.add(gemini.Content.text(response));
      return response;
    } catch (e, stackTrace) {
      debugPrint('Error in chat: $e\n$stackTrace');
      return 'エラーが発生しました: $e';
    }
  }

  /// チャット履歴をクリアする
  void clearHistory() {
    _chatHistory.clear();
  }

  /// MCP → Gemini ツール変換
  List<gemini.Tool> _toGeminiTools(List<mcp_client.Tool> infos) =>
      infos.map((t) {
        // JSON Schema → Schema クラス（v0.4.2+）
        final schema = gemini.Schema.object(
          properties: _convertToGeminiSchema(t.inputSchema),
        );

        return gemini.Tool(
          functionDeclarations: [
            gemini.FunctionDeclaration(t.name, t.description, schema),
          ],
        );
      }).toList();

  /// NotionのスキーマをGeminiのスキーマに変換
  Map<String, gemini.Schema> _convertToGeminiSchema(
    Map<String, dynamic> schema,
  ) {
    // スキーマがプリミティブ型の場合
    if (schema['type'] != null && !schema.containsKey('properties')) {
      return {'value': _createBasicSchema(schema['type'] as String)};
    }

    // propertiesが存在しない場合は空のオブジェクトを返す
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final convertedProperties = <String, gemini.Schema>{};

    properties.forEach((key, value) {
      if (value == null) {
        convertedProperties[key] = gemini.Schema.string(); // デフォルト値
        return;
      }

      final type = value['type'] as String? ?? 'string';
      switch (type) {
        case 'string':
          convertedProperties[key] = gemini.Schema.string();
          break;
        case 'object':
          if (value is! Map<String, dynamic>) {
            convertedProperties[key] = gemini.Schema.object(properties: {});
          } else {
            convertedProperties[key] = gemini.Schema.object(
              properties: _convertToGeminiSchema(value),
            );
          }
          break;
        case 'array':
          if (value['items'] == null) {
            convertedProperties[key] = gemini.Schema.array(
              items: gemini.Schema.string(),
            );
          } else {
            final itemSchema = value['items'] as Map<String, dynamic>;
            final itemType = itemSchema['type'] as String? ?? 'string';
            convertedProperties[key] = gemini.Schema.array(
              items: _createBasicSchema(itemType),
            );
          }
          break;
        default:
          convertedProperties[key] = gemini.Schema.string();
      }
    });

    return convertedProperties;
  }

  /// 基本的なスキーマタイプを作成
  gemini.Schema _createBasicSchema(String type) {
    switch (type) {
      case 'string':
        return gemini.Schema.string();
      case 'number':
        return gemini.Schema.number();
      case 'integer':
        return gemini.Schema.integer();
      case 'boolean':
        return gemini.Schema.boolean();
      case 'object':
        return gemini.Schema.object(properties: {});
      case 'array':
        return gemini.Schema.array(items: gemini.Schema.string());
      default:
        return gemini.Schema.string();
    }
  }
  
  void _notifyThinking(ThinkingStep step, String message) {
    _thinkingCallback?.call(step, message);
  }
  
  /// Gemini APIレスポンスからthinking情報を抽出（実験的）
  void _extractThinkingFromResponse(gemini.GenerateContentResponse response) {
    try {
      for (final candidate in response.candidates) {
        for (final part in candidate.content.parts) {
          // thinking情報が含まれている可能性のあるpartを確認
          final partText = part.toString();
          debugPrint('Checking part for thinking: $partText');
          
          // Thinking専用モデルからの特別な情報があるかチェック
          if (partText.contains('thinking') || partText.contains('思考')) {
            debugPrint('Potential thinking content found: $partText');
            // 実際のthinking情報が見つかった場合の処理をここに追加
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting thinking info: $e');
    }
  }
}
