enum ModelProvider {
  googleGenerativeAi,
  firebaseAi,
}

class GeminiModelConfig {
  final String modelId;
  final String displayName;
  final String description;
  final bool supportsFunctionCalling;
  final bool isExperimental;
  final ModelProvider provider;

  const GeminiModelConfig({
    required this.modelId,
    required this.displayName,
    required this.description,
    this.supportsFunctionCalling = true,
    this.isExperimental = false,
    this.provider = ModelProvider.googleGenerativeAi,
  });

  static const List<GeminiModelConfig> availableModels = [
    // Firebase AI モデル
    GeminiModelConfig(
      modelId: 'gemini-2.0-flash-thinking-exp',
      displayName: 'Gemini 2.0 Flash Thinking (Firebase)',
      description: 'Firebase AI: 真のthinking情報対応実験版',
      supportsFunctionCalling: true,
      isExperimental: true,
      provider: ModelProvider.firebaseAi,
    ),
    GeminiModelConfig(
      modelId: 'gemini-2.0-flash-exp',
      displayName: 'Gemini 2.0 Flash Exp (Firebase)',
      description: 'Firebase AI: 最新機能テスト版',
      supportsFunctionCalling: true,
      isExperimental: true,
      provider: ModelProvider.firebaseAi,
    ),
    // Google Generative AI モデル
    GeminiModelConfig(
      modelId: 'models/gemini-2.0-flash-thinking-exp',
      displayName: 'Gemini 2.0 Flash Thinking',
      description: '思考プロセス表示対応の実験版モデル',
      supportsFunctionCalling: true,
      isExperimental: true,
    ),
    GeminiModelConfig(
      modelId: 'models/gemini-2.0-flash-exp',
      displayName: 'Gemini 2.0 Flash Experimental',
      description: '最新機能テスト版、実験的な機能を含む',
      supportsFunctionCalling: true,
      isExperimental: true,
    ),
    GeminiModelConfig(
      modelId: 'models/gemini-2.0-flash',
      displayName: 'Gemini 2.0 Flash',
      description: '最新の高速モデル、マルチモーダル対応',
      supportsFunctionCalling: true,
      isExperimental: true,
    ),
    GeminiModelConfig(
      modelId: 'models/gemini-1.5-pro',
      displayName: 'Gemini 1.5 Pro',
      description: '高性能モデル、複雑なタスクに最適',
      supportsFunctionCalling: true,
    ),
    GeminiModelConfig(
      modelId: 'models/gemini-1.5-flash',
      displayName: 'Gemini 1.5 Flash',
      description: '高速レスポンス、日常タスクに最適',
      supportsFunctionCalling: true,
    ),
    GeminiModelConfig(
      modelId: 'models/gemini-1.0-pro',
      displayName: 'Gemini 1.0 Pro',
      description: '安定版モデル、実用性重視',
      supportsFunctionCalling: true,
    ),
    // Gemini 2.5 モデル (thinking機能対応)
    GeminiModelConfig(
      modelId: 'models/gemini-2.5-pro',
      displayName: 'Gemini 2.5 Pro',
      description: '最新高性能モデル、thinking機能対応',
      supportsFunctionCalling: true,
      isExperimental: true,
    ),
    GeminiModelConfig(
      modelId: 'models/gemini-2.5-flash',
      displayName: 'Gemini 2.5 Flash',
      description: '最新高速モデル、thinking機能対応',
      supportsFunctionCalling: true,
      isExperimental: true,
    ),
  ];

  static GeminiModelConfig getModelById(String modelId) {
    return availableModels.firstWhere(
      (model) => model.modelId == modelId,
      orElse: () => availableModels.first,
    );
  }

  static GeminiModelConfig get defaultModel => availableModels.first;

  bool get isFirebaseAi => provider == ModelProvider.firebaseAi;
  bool get isGoogleGenerativeAi => provider == ModelProvider.googleGenerativeAi;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeminiModelConfig &&
          runtimeType == other.runtimeType &&
          modelId == other.modelId &&
          provider == other.provider;

  @override
  int get hashCode => Object.hash(modelId, provider);
}