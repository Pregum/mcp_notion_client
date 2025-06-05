class GeminiModelConfig {
  final String modelId;
  final String displayName;
  final String description;
  final bool supportsFunctionCalling;
  final bool isExperimental;

  const GeminiModelConfig({
    required this.modelId,
    required this.displayName,
    required this.description,
    this.supportsFunctionCalling = true,
    this.isExperimental = false,
  });

  static const List<GeminiModelConfig> availableModels = [
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
  ];

  static GeminiModelConfig getModelById(String modelId) {
    return availableModels.firstWhere(
      (model) => model.modelId == modelId,
      orElse: () => availableModels.first,
    );
  }

  static GeminiModelConfig get defaultModel => availableModels.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeminiModelConfig &&
          runtimeType == other.runtimeType &&
          modelId == other.modelId;

  @override
  int get hashCode => modelId.hashCode;
}