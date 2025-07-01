import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'theme_manager.dart';

class LocalTools {
  // 色解釈用のGeminiモデル（静的インスタンス）
  static late GenerativeModel _colorInterpreterModel;
  static bool _isColorInterpreterInitialized = false;
  
  static void initializeColorInterpreter() {
    if (!_isColorInterpreterInitialized) {
      _colorInterpreterModel = GenerativeModel(
        model: 'gemini-2.5-flash-lite-preview-06-17',
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      );
      _isColorInterpreterInitialized = true;
    }
  }
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
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'change_theme_color',
        'アプリのテーマカラーを変更するツール。自然言語で色を指定できます（例：赤、青、夕焼けの色、深い海の青、桜色など）',
        Schema.object(properties: {
          'color': Schema.string(description: '変更したい色の表現（日本語、英語、または詩的な表現）'),
        }, requiredProperties: ['color']),
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
      case 'change_theme_color':
        return await _executeChangeThemeColor(args);
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
        '1. $queryについて - Wikipedia',
        '   $queryとは、...',
        '',
        '2. $queryの詳細解説 - 専門サイト',
        '   $queryに関する詳しい情報が掲載されています。',
        '',
        '3. $queryの使い方 - チュートリアル',
        '   $queryの基本的な使い方を学べます。',
        '',
        '※ これはStep 2のデモ用モック検索結果です。',
      ];
      
      return mockResults.join('\n');
    } catch (e) {
      return 'エラー: Web検索に失敗しました。 ($e)';
    }
  }

  static Future<String> _executeChangeThemeColor(Map<String, dynamic> args) async {
    try {
      final colorExpression = args['color'] as String;
      final themeManager = ThemeManager();
      
      // まず直接的な色名やHEXコードかチェック
      var color = ThemeManager.parseColorFromText(colorExpression);
      
      // 直接解釈できない場合は、Geminiに解釈を依頼
      if (color == null) {
        initializeColorInterpreter();
        
        final prompt = '''
あなたは色の専門家です。以下の色の表現を解釈して、最も適切なHEXカラーコードを1つだけ返してください。
ある程度独自解釈で良いので、あなたの解釈を含めて返答してください。
返答は#で始まる6桁のHEXコードのみにしてください。説明は不要です。

色の表現: "$colorExpression"

例:
- "夕焼けの色" → #FF6B35
- "深い海の青" → #003366
- "春の桜" → #FFB6C1
''';
        
        final response = await _colorInterpreterModel.generateContent([Content.text(prompt)]);
        final hexCode = response.text?.trim();
        
        if (hexCode != null && hexCode.startsWith('#')) {
          color = ThemeManager.parseHexColor(hexCode);
          if (color != null) {
            themeManager.updateTheme(color);
            return 'テーマカラーを「$colorExpression」($hexCode) に変更しました！';
          }
        }
        
        return 'エラー: 「$colorExpression」という色を解釈できませんでした。';
      } else {
        // 直接解釈できた場合
        themeManager.updateTheme(color);
        return 'テーマカラーを「$colorExpression」に変更しました！';
      }
    } catch (e) {
      return 'エラー: テーマカラーの変更に失敗しました。 ($e)';
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
      {
        'name': 'change_theme_color',
        'description': 'アプリのテーマカラーを変更するツール',
        'parameters': {
          'color': {'type': 'string', 'description': '変更したい色の表現（自然言語で指定可能）'},
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