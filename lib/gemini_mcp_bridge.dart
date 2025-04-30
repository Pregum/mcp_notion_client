import 'package:mcp_client/mcp_client.dart' as mcp_client;
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

class GeminiMcpBridge {
  final mcp_client.Client mcp;
  final gemini.GenerativeModel model;

  GeminiMcpBridge({required this.mcp, required this.model});

  /// ユーザー入力を渡して最終テキストを返す
  Future<String> chat(String userPrompt) async {
    // 1) MCP のツール定義を Gemini 用に変換
    final geminiTools = _toGeminiTools(await mcp.listTools());

    // 2) LLM へ投げる（ユーザー発話）
    final first = await model.generateContent(
      [gemini.Content.text(userPrompt)],
      tools: geminiTools,
    );

    // 3) 関数呼び出しがあるか確認
    final call =
        first.functionCalls.isNotEmpty ? first.functionCalls.first : null;
    if (call == null) return first.text ?? '';

    // 4) MCP ツールを実行
    final toolResult = await mcp.callTool(call.name, call.args);

    // 5) 実行結果を LLM に返し、要約を生成
    final followUp = await model.generateContent([
      gemini.Content.model([call]), // モデル視点の呼び出し履歴
      gemini.Content.functionResponse(
        call.name,
        {'result': toolResult.content.map((e) => e.toJson())}, // Map<String,dynamic> 形式で渡す
      ),
    ]);

    return followUp.text ?? '';
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
  Map<String, gemini.Schema> _convertToGeminiSchema(Map<String, dynamic> schema) {
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