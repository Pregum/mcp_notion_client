import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart' as mcp_client;
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'dart:convert';

class GeminiMcpBridge {
  final mcp_client.Client mcp;
  final gemini.GenerativeModel model;
  final List<gemini.Content> _chatHistory = [];

  GeminiMcpBridge({required this.mcp, required this.model});

  /// ユーザー入力を渡して最終テキストを返す
  Future<String> chat(String userPrompt) async {
    try {
      // 1) MCP のツール定義を Gemini 用に変換
      final geminiTools = _toGeminiTools(await mcp.listTools());
      debugPrint(
        'Gemini Tools: ${geminiTools.map((e) => e.functionDeclarations?.firstOrNull?.name)}',
      );

      // 2) LLM へ投げる（ユーザー発話）
      final userContent = gemini.Content.text(userPrompt);
      _chatHistory.add(userContent);

      final first = await model.generateContent(
        _chatHistory,
        tools: geminiTools,
      );

      // デバッグ出力を追加
      debugPrint('=== GenerateContentResponse ===');
      debugPrint('Candidates: ${first.candidates.length}件');
      for (var i = 0; i < first.candidates.length; i++) {
        final candidate = first.candidates[i];
        debugPrint('Candidate $i:');
        debugPrint('  - Text: ${candidate.text}');
        debugPrint('  - Finish Reason: ${candidate.finishReason}');
        debugPrint('  - Finish Message: ${candidate.finishMessage}');
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

      // 3) 関数呼び出しがあるか確認
      final call =
          first.functionCalls.isNotEmpty ? first.functionCalls.first : null;
      if (call == null) {
        final response = first.text ?? '';
        _chatHistory.add(gemini.Content.text(response));
        return response;
      }

      // 4) MCP ツールを実行
      final toolResult = await mcp.callTool(call.name, call.args);

      // デバッグ用のログ出力
      debugPrint('Tool Result Content: ${toolResult.content}');
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
                  return 'NotionのAPIトークンが無効です。有効なAPIトークンを設定してください。';
                }
                break;

              case 'spotify':
                if (errorJson['code'] == 'unauthorized') {
                  return 'Spotifyのアクセストークンが無効です。再認証が必要です。';
                } else if (errorJson['code'] == 'rate_limit') {
                  return 'Spotifyのレート制限に達しました。しばらく待ってから再試行してください。';
                }
                break;

              default:
                return 'エラーが発生しました: ${errorJson['message']}';
            }
          } catch (e) {
            // JSON解析エラーは無視
          }
        }
      }

      // 5) 実行結果を LLM に返し、要約を生成
      final followUp = await model.generateContent([
        ..._chatHistory,
        gemini.Content.text('以下の実行結果を日本語で分かりやすく要約してください：'),
        gemini.Content.model([call]),
        gemini.Content.functionResponse(call.name, {'result': resultJson}),
      ]);

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
}
