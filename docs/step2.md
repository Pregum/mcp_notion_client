# Step 2: Flutter x Gemini x ローカルツール

## 概要

Step 2では、Gemini API の Function Calling 機能を使用してローカルツールを呼び出す仕組みを学習します。AIが適切なツールを自動選択し、実行結果を基に応答を生成します。

## 実行方法

```bash
cd step2
flutter run
```

## ファイル構成

```
step2/
├── main.dart                      # アプリケーションエントリーポイント
└── lib/
    ├── models/
    │   └── chat_message.dart      # チャットメッセージUI コンポーネント
    ├── services/
    │   └── local_tools.dart       # ローカルツール実装
    └── screens/
        └── chat_screen.dart       # Function Calling対応チャット画面
```

## 各ファイルの役割

### main.dart

**役割**: アプリケーションのエントリーポイント

**Step 1 からの変更点**:
- アプリ名を `Step2: Flutter x Gemini x Local Tools` に変更
- テーマカラーを緑系(`Colors.green`)に変更
- その他の基本構造は Step 1 と同じ

### lib/models/chat_message.dart

**役割**: チャットメッセージUI コンポーネント

**機能**: Step 1 と同じ
- ユーザーとAIの発言を区別して表示
- レスポンシブデザイン
- Material Design 3 準拠

### lib/services/local_tools.dart

**役割**: ローカルツールの定義と実行を管理

**主な機能**:

#### 1. ツール定義
3つのローカルツールを定義:

```dart
static List<Tool> get tools => [
  // 1. hello_gemini: 挨拶ツール
  Tool(functionDeclarations: [
    FunctionDeclaration(
      'hello_gemini',
      'Gemini に挨拶をするシンプルなツール',
      Schema.object(properties: {}),
    ),
  ]),
  
  // 2. calculate: 計算ツール
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
  
  // 3. web_search: Web検索ツール（モック）
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
```

#### 2. ツール実行エンジン

```dart
static Future<String> executeTool(String toolName, Map<String, dynamic> args) async {
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
```

#### 3. 個別ツール実装

**hello_gemini**:
- パラメーター: なし
- 機能: 固定の挨拶メッセージを返す
- 用途: 最もシンプルなツールの例

**calculate**:
- パラメーター: `a`(int), `b`(int)
- 機能: 2つの整数の合計を計算
- エラーハンドリング: 型変換エラーをキャッチ

**web_search**:
- パラメーター: `query`(string)
- 機能: モック検索結果を返す
- 用途: 外部API呼び出しのシミュレーション

#### 4. UI支援機能

- `getToolList()`: ツール一覧をUI用の形式で取得
- 手動実行ダイアログで使用される情報を提供

### lib/screens/chat_screen.dart

**役割**: Function Calling対応のメインチャット画面

**Step 1 からの主要な追加・変更点**:

#### 1. Gemini モデル初期化でツール登録

```dart
_model = GenerativeModel(
  model: 'models/gemini-2.0-flash',
  apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
  tools: LocalTools.tools,  // ←ここが追加
);
```

#### 2. Function Call の検出と処理

```dart
final response = await _model.generateContent(_chatHistory);

// Function call があるかチェック
if (response.functionCalls.isNotEmpty) {
  await _handleFunctionCalls(response.functionCalls.toList());
} else {
  // 通常のテキスト応答処理
}
```

#### 3. Function Call 実行処理

```dart
Future<void> _handleFunctionCalls(List<FunctionCall> functionCalls) async {
  final List<FunctionResponse> responses = [];

  for (final call in functionCalls) {
    try {
      // ローカルツールを実行
      final result = await LocalTools.executeTool(call.name, call.args);
      responses.add(FunctionResponse(call.name, {'result': result}));
      
      // 実行結果をチャットに表示
      setState(() {
        _messages.add(ChatMessage(
          text: '🔧 ツール実行: ${call.name}\n結果: $result',
          isUser: false,
        ));
      });
    } catch (e) {
      // エラー処理
    }
  }

  // 実行結果を含めて Gemini に再送信
  final followUpResponse = await _model.generateContent([
    ..._chatHistory,
    Content.functionResponses(responses),
  ]);
}
```

#### 4. ツール一覧表示機能

```dart
void _showToolList() {
  final tools = LocalTools.getToolList();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('利用可能なツール'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return Card(
              child: ListTile(
                title: Text(tool['name']),
                subtitle: Text(tool['description']),
                trailing: ElevatedButton(
                  onPressed: () => _showToolExecutionDialog(tool),
                  child: const Text('実行'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
```

#### 5. 手動ツール実行機能

- ツールを手動で実行するためのダイアログ
- パラメーター入力フォーム
- 型変換（文字列→整数など）
- 実行結果の表示

## 学習のポイント

### 1. Function Calling の仕組み
- Gemini API でのツール定義方法
- `FunctionDeclaration` と `Schema` の使い方
- Function Call の検出と実行フロー

### 2. ツール設計パターン
- ツールの抽象化（名前、説明、パラメーター）
- 実行エンジンの実装
- エラーハンドリングの考慮

### 3. UI/UX の工夫
- AI自動選択と手動実行の両対応
- ツール実行の可視化
- リアルタイムフィードバック

### 4. 会話フローの管理
- Function Call の結果を含む再送信
- コンテキストの維持
- 複数ステップの会話処理

## 使用例

### AI自動選択の例
- 「こんにちは」→ `hello_gemini` ツールが自動選択
- 「5と3を足して」→ `calculate` ツールが自動選択
- 「Flutterについて調べて」→ `web_search` ツールが自動選択

### 手動実行の例
- ツールボタンから一覧表示
- 任意のツールを選択
- パラメーター入力ダイアログ
- 手動実行と結果表示

## 次のステップへ

Step 2 ではローカルツールによる Function Calling を実装しました。Step 3 では、より実用的な MCP (Model Context Protocol) サーバーとの連携を学習します。

**Step 2 → Step 3 での主な追加要素**:
- MCP サーバーとの通信
- 複数サーバーの管理
- 外部サービス（Notion、Spotify）との統合
- 認証とエラーハンドリングの強化