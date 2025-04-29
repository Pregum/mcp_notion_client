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
          properties: t.inputSchema as Map<String, gemini.Schema>,
        );

        return gemini.Tool(
          functionDeclarations: [
            gemini.FunctionDeclaration(t.name, t.description, schema),
          ],
        );
      }).toList();
}