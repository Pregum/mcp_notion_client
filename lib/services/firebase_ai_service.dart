import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseAiService {
  static FirebaseAiService? _instance;
  GenerativeModel? _model;

  FirebaseAiService._();

  static FirebaseAiService get instance {
    _instance ??= FirebaseAiService._();
    return _instance!;
  }

  /// Firebase AIを初期化（APIキーベース）
  Future<void> initialize({required String apiKey}) async {
    try {
      // Firebase Core が初期化されていない場合は初期化
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Firebase AI の初期化 - APIキーベース
      final ai = FirebaseAI.googleAI();
      
      debugPrint('Firebase AI initialized successfully with API key');
    } catch (e) {
      debugPrint('Failed to initialize Firebase AI: $e');
      rethrow;
    }
  }

  /// 指定されたモデルIDでGenerativeModelを作成
  GenerativeModel createModel(String modelId) {
    try {
      final ai = FirebaseAI.googleAI();
      
      // モデルを作成
      _model = ai.generativeModel(
        model: modelId,
        // thinking情報を取得するための設定
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        ),
      );
      
      debugPrint('Firebase AI model created: $modelId');
      return _model!;
    } catch (e) {
      debugPrint('Failed to create Firebase AI model: $e');
      rethrow;
    }
  }

  /// 利用可能なモデル一覧を取得
  static List<String> get availableModels => [
    'gemini-2.0-flash-thinking-exp',
    'gemini-2.0-flash-exp', 
    'gemini-2.0-flash',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
  ];

  /// thinking対応モデルかどうかを判定
  static bool isThinkingModel(String modelId) {
    return modelId.contains('thinking');
  }

  /// モデルの説明を取得
  static String getModelDescription(String modelId) {
    switch (modelId) {
      case 'gemini-2.0-flash-thinking-exp':
        return 'Firebase AI: 思考プロセス表示対応の実験版';
      case 'gemini-2.0-flash-exp':
        return 'Firebase AI: 最新機能テスト版';
      case 'gemini-2.0-flash':
        return 'Firebase AI: 高速マルチモーダルモデル';
      case 'gemini-1.5-pro':
        return 'Firebase AI: 高性能モデル';
      case 'gemini-1.5-flash':
        return 'Firebase AI: 高速レスポンスモデル';
      default:
        return 'Firebase AI: 不明なモデル';
    }
  }
}