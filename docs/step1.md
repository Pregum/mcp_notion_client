# Step 1: Flutter x Gemini 基本接続

## 概要

Step 1では、FlutterアプリケーションからGemini APIへの基本的な接続方法を学習します。最もシンプルな構成で、チャット機能のみを実装しています。

## 実行方法

```bash
cd step1
flutter run
```

## ファイル構成

```
step1/
├── main.dart                    # アプリケーションエントリーポイント
└── lib/
    ├── models/
    │   └── chat_message.dart    # チャットメッセージUI コンポーネント
    └── screens/
        └── chat_screen.dart     # メインのチャット画面
```

## 各ファイルの役割

### main.dart

**役割**: アプリケーションのエントリーポイント

**主な機能**:
- `Step1App` ウィジェットの定義
- MaterialApp の設定（テーマ、タイトル）
- `ChatScreen` を home として設定

**重要なポイント**:
- シンプルな Flutter アプリの基本構造
- テーマカラーを青系(`Colors.blue`)に設定
- Step1専用のアプリタイトル

```dart
class Step1App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step1: Flutter x Gemini',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
```

### lib/models/chat_message.dart

**役割**: チャットメッセージを表示するUIコンポーネント

**主な機能**:
- ユーザーとAIの発言を区別して表示
- 左右の配置でメッセージの送信者を視覚的に区別
- レスポンシブデザイン（画面幅の70%まで）

**デザインの特徴**:
- ユーザーメッセージ: 右寄せ、プライマリカラー
- AIメッセージ: 左寄せ、セカンダリコンテナカラー
- 角丸デザイン（`borderRadius: 20.0`）

**重要なポイント**:
- シンプルで再利用可能なコンポーネント設計
- Material Design 3 のカラーシステムを活用
- レスポンシブ対応

### lib/screens/chat_screen.dart

**役割**: メインのチャット画面UI

**主な機能**:
1. **Gemini API との接続**
   - API キーの設定（環境変数から取得）
   - `GenerativeModel` の初期化
   - モデル: `gemini-2.0-flash`

2. **チャット機能**
   - ユーザー入力の受付
   - Gemini API への送信
   - レスポンスの表示

3. **UI機能**
   - チャット履歴の表示
   - 自動スクロール
   - ローディング状態の表示

4. **ステップ情報表示**
   - Step 1 の説明パネル
   - ツールボタン（未実装を確認用）
   - 履歴クリア機能

**重要なポイント**:
- **API認証**: 環境変数 `GEMINI_API_KEY` を使用
- **エラーハンドリング**: 基本的な try-catch 構造
- **状態管理**: `StatefulWidget` での UI 状態管理
- **チャット履歴**: `List<Content>` で会話履歴を管理

**コア実装**:

```dart
// Gemini モデルの初期化
_model = GenerativeModel(
  model: 'models/gemini-2.0-flash',
  apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
);

// メッセージ送信処理
final userContent = Content.text(text);
_chatHistory.add(userContent);

final response = await _model.generateContent(_chatHistory);
final responseText = response.text ?? 'レスポンスを生成できませんでした。';
```

## 学習のポイント

### 1. Gemini API の基本
- API キーの設定方法
- `GenerativeModel` の使い方
- 基本的なリクエスト/レスポンス処理

### 2. Flutter の基本パターン
- `StatefulWidget` の使い方
- リスト表示とスクロール制御
- 非同期処理と UI 更新

### 3. 会話履歴の管理
- `List<Content>` による履歴管理
- ユーザー入力とAI応答の記録
- コンテキストを保った会話の実現

## 次のステップへ

Step 1 では基本的なチャット機能のみを実装しています。Step 2 では Function Calling（ツール機能）を追加し、AIがローカルツールを呼び出せるようになります。

**Step 1 → Step 2 での主な追加要素**:
- ツール定義の追加
- Function Calling の実装
- ツール実行結果の処理
- 手動ツール実行機能