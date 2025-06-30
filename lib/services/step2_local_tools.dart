import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class Step2LocalTools {
  // ローカルツールの定義
  static List<Tool> get tools => [
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'hello_gemini',
        'Gemini に挨拶をするシンプルなツール',
        Schema.object(properties: {}),
      ),
    ]),
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'calculate',
        '2つの整数を受け取って合計を計算するツール',
        Schema.object(properties: {
          'a': Schema.integer(description: '1つ目の整数'),
          'b': Schema.integer(description: '2つ目の整数'),
        }, requiredProperties: ['a', 'b']),
      ),
    ]),
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'web_search',
        'Webを検索して結果を要約するツール（モック実装）',
        Schema.object(properties: {
          'query': Schema.string(description: '検索クエリ'),
        }, requiredProperties: ['query']),
      ),
    ]),
  ];

  // ツール実行メソッド
  static Future<String> executeTool(String toolName, Map<String, dynamic> args) async {
    debugPrint('Executing tool: $toolName with args: $args');
    
    switch (toolName) {
      case 'hello_gemini':
        return _executeHelloGemini();
      case 'calculate':
        return _executeCalculate(args);
      case 'web_search':
        return _executeWebSearch(args);
      default:
        throw Exception('Unknown tool: $toolName');
    }
  }

  // 個別ツール実装
  static String _executeHelloGemini() {
    return 'ハロー gemini！ Step 2 のローカルツールから挨拶します！';
  }

  static String _executeCalculate(Map<String, dynamic> args) {
    try {
      final a = args['a'] as int;
      final b = args['b'] as int;
      final result = a + b;
      return '計算結果: $a + $b = $result';
    } catch (e) {
      return 'エラー: 計算に失敗しました。正しい整数を入力してください。 ($e)';
    }
  }

  static String _executeWebSearch(Map<String, dynamic> args) {
    try {
      final query = args['query'] as String;
      
      // モック検索結果
      final mockResults = [
        '「$query」に関する検索結果:',
        '',
        '1. ${query}について - Wikipedia',
        '   ${query}とは、...',
        '',
        '2. ${query}の詳細解説 - 専門サイト',
        '   ${query}に関する詳しい情報が掲載されています。',
        '',
        '3. ${query}の使い方 - チュートリアル',
        '   ${query}の基本的な使い方を学べます。',
        '',
        '※ これはStep 2のデモ用モック検索結果です。',
      ];
      
      return mockResults.join('\n');
    } catch (e) {
      return 'エラー: Web検索に失敗しました。 ($e)';
    }
  }

  // ツール一覧取得
  static List<Map<String, dynamic>> getToolList() {
    return [
      {
        'name': 'hello_gemini',
        'description': 'Gemini に挨拶をするシンプルなツール',
        'parameters': {},
      },
      {
        'name': 'calculate',
        'description': '2つの整数を受け取って合計を計算するツール',
        'parameters': {
          'a': {'type': 'integer', 'description': '1つ目の整数'},
          'b': {'type': 'integer', 'description': '2つ目の整数'},
        },
      },
      {
        'name': 'web_search',
        'description': 'Webを検索して結果を要約するツール（モック実装）',
        'parameters': {
          'query': {'type': 'string', 'description': '検索クエリ'},
        },
      },
    ];
  }

  // ツール実行用のレスポンス生成
  static Map<String, dynamic> createFunctionResponse(String toolName, String result) {
    return {
      'name': toolName,
      'response': {'result': result},
    };
  }
}