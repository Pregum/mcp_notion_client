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

  /// ユーザー入力を渡して最終テキストを返す（ストリーミング対応）
  Future<String> chat(String userPrompt) async {
    final response = await chatWithThinking(userPrompt);
    return response.text;
  }

  /// ユーザー入力を渡して思考情報付きの応答を返す
  Future<StreamingResponse> chatWithThinking(String userPrompt) async {
    try {
      // 1) 接続されている全てのMCPクライアントからツール定義を取得
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

      // 3) モデルが思考機能をサポートしているかチェック（現在は無効化）
      final supportsThinking = false; // Gemini 2.5の思考機能は今後対応予定
      
      debugPrint('Supports thinking: $supportsThinking');

      // 4) LLM へ投げる（ユーザー発話）
      final userContent = gemini.Content.text(userPrompt);
      _chatHistory.add(userContent);

      // ストリーミングで応答を取得
      final response = await _generateStreamingResponse(
        _chatHistory, 
        geminiTools,
        supportsThinking: supportsThinking,
      );
      
      if (response.functionCalls.isEmpty) {
        _chatHistory.add(gemini.Content.text(response.text));
        return response;
      }

      // 5) 複数のツール実行を順次処理
      final toolResults = <gemini.FunctionCall>[];
      final toolResponses = <Map<String, dynamic>>[];
      
      for (final call in response.functionCalls) {
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
      
      final followUpResponse = await _generateStreamingResponse(
        followUpContent, 
        [],
        supportsThinking: supportsThinking,
      );

      _chatHistory.add(gemini.Content.text(followUpResponse.text));
      return followUpResponse;
    } catch (e, stackTrace) {
      debugPrint('Error in chat: $e\n$stackTrace');
      final errorResponse = StreamingResponse();
      errorResponse.text = 'エラーが発生しました: $e';
      return errorResponse;
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
  
  /// ストリーミング応答を処理
  Future<StreamingResponse> _generateStreamingResponse(
    List<gemini.Content> contents,
    List<gemini.Tool> tools, {
    required bool supportsThinking,
  }) async {
    final result = StreamingResponse();
    var currentThoughts = '';
    var currentAnswer = '';
    
    try {
      // ストリーミングで応答を取得
      final responseStream = model.generateContentStream(
        contents,
        tools: tools,
      );
      
      await for (final chunk in responseStream) {
        if (chunk.candidates.isEmpty) continue;
        
        final candidate = chunk.candidates.first;
        
        // Function callsの処理
        for (final call in chunk.functionCalls) {
          result.functionCalls.add(call);
        }
        
        // テキストコンテンツの処理
        for (final part in candidate.content.parts) {
          try {
            final partMap = part.toJson() as Map<String, dynamic>;
            
            // thought属性が存在するかチェック（Gemini 2.5での実装）
            if (supportsThinking && partMap.containsKey('thought') && partMap['thought'] == true) {
              if (partMap.containsKey('text')) {
                currentThoughts += partMap['text'] as String;
                // 実際の思考情報が取得できた場合のみUIに通知
                if (currentThoughts.isNotEmpty) {
                  _thinkingCallback?.call(ThinkingStep.planning, currentThoughts);
                }
              }
            } else if (partMap.containsKey('text')) {
              // 通常のテキスト（回答）
              currentAnswer += partMap['text'] as String;
            }
            
            // デバッグ出力
            debugPrint('Part: $partMap');
          } catch (e) {
            // JSON変換エラーの場合はテキストとして処理
            final text = part.toString();
            if (text.isNotEmpty) {
              currentAnswer += text;
            }
            debugPrint('Part parsing error: $e');
          }
        }
      }
      
      result.thoughts = currentThoughts;
      result.text = currentAnswer;
      
      if (currentThoughts.isNotEmpty || currentAnswer.isNotEmpty) {
        _notifyThinking(ThinkingStep.completed, '完了しました');
      }
      
    } catch (e) {
      debugPrint('Error in streaming response: $e');
      result.text = 'ストリーミング処理中にエラーが発生しました: $e';
    }
    
    return result;
  }
}

/// ストリーミング応答の結果を格納するクラス
class StreamingResponse {
  String thoughts = '';
  String text = '';
  final List<gemini.FunctionCall> functionCalls = [];
}
