# Step 3: Flutter x Gemini x MCP (完全版)

## 概要

Step 3では、MCP (Model Context Protocol) サーバーとの実用的な統合を学習します。Notion や Spotify などの外部サービスと連携し、複数のMCPサーバーを管理する本格的なアプリケーションを実装します。

## 実行方法

```bash
cd step3
flutter run
```

## ファイル構成

```
step3/
├── main.dart                         # アプリケーションエントリーポイント
└── lib/
    ├── components/
    │   ├── add_server_dialog.dart     # サーバー追加ダイアログ
    │   └── server_status_panel.dart   # サーバー状態表示パネル
    ├── models/
    │   ├── chat_message.dart          # チャットメッセージUI コンポーネント
    │   └── mcp_server_status.dart     # MCPサーバー状態管理
    ├── screens/
    │   └── chat_screen.dart           # MCP統合チャット画面
    └── services/
        ├── gemini_mcp_bridge.dart     # Gemini-MCP橋渡し
        └── mcp_client_manager.dart    # MCPクライアント管理
```

## 各ファイルの役割

### main.dart

**役割**: アプリケーションのエントリーポイント

**Step 2 からの変更点**:
- アプリ名を `Step3: Flutter x Gemini x MCP` に変更
- テーマカラーを紫系(`Colors.deepPurple`)に変更
- より高度な機能を示すための色選択

### lib/models/chat_message.dart

**役割**: チャットメッセージUI コンポーネント

**機能**: Step 1, 2 と同じ
- 統一されたメッセージ表示コンポーネント
- 全ステップで共通の UI/UX

### lib/models/mcp_server_status.dart

**役割**: MCPサーバーの接続状態を管理するデータモデル

**主な機能**:
```dart
class McpServerStatus {
  final String name;                    // サーバー名
  final String url;                     // 接続URL
  final Map<String, String> headers;    // 認証ヘッダー
  bool isConnected;                     // 接続状態
  String? error;                        // エラー情報
}
```

**重要なポイント**:
- サーバーごとの状態を個別管理
- 接続失敗時のエラー情報保持
- UI での状態表示に使用

### lib/services/mcp_client_manager.dart

**役割**: 複数のMCPサーバーへの接続を管理

**主な機能**:

#### 1. デフォルトサーバーの初期化
```dart
void _initializeDefaultServers() {
  _serverStatuses.addAll([
    McpServerStatus(
      name: 'Notion MCP',
      url: 'http://${const String.fromEnvironment('SERVER_IP')}:8000/sse',
      headers: {},
    ),
    McpServerStatus(
      name: 'Spotify MCP',
      url: 'http://${const String.fromEnvironment('SERVER_IP')}:8001/sse',
      headers: {},
    ),
  ]);
}
```

#### 2. サーバー接続処理
```dart
Future<void> connectToServer(McpServerStatus status) async {
  try {
    final client = McpClient.createClient(
      name: 'gemini-mcp-client-${status.name.toLowerCase()}',
      version: '1.0.0',
      capabilities: ClientCapabilities(sampling: true),
    );

    final transport = await McpClient.createSseTransport(
      serverUrl: status.url,
      headers: _getHeadersForServer(status.name),
    );

    await client.connect(transport).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw McpError('${status.name} connection timeout'),
    );

    _clients.add(McpClientInfo(
      name: status.name,
      client: client,
      status: status,
    ));

    status.isConnected = true;
    status.error = null;
  } catch (e) {
    status.isConnected = false;
    status.error = e.toString();
  }
}
```

#### 3. 認証ヘッダー管理
```dart
Map<String, String> _getHeadersForServer(String serverName) {
  switch (serverName) {
    case 'Notion MCP':
      return {
        'Authorization': 'Bearer ${const String.fromEnvironment('NOTION_API_KEY')}',
        'Notion-Version': '2022-06-28',
      };
    case 'Spotify MCP':
      return {
        'Authorization': 'Bearer ${const String.fromEnvironment('SPOTIFY_ACCESS_TOKEN')}',
      };
    default:
      return {};
  }
}
```

#### 4. サーバー動的管理
- `addServer()`: 新しいサーバーの追加
- `removeServer()`: サーバーの削除
- `disconnectAll()`: 全サーバーとの切断

### lib/services/gemini_mcp_bridge.dart

**役割**: Gemini AI と MCP サーバー間の通信を仲介

**主な機能**:

#### 1. ツール取得と変換
```dart
// 1) 接続されている全てのMCPクライアントからツール定義を取得
final allTools = <mcp_client.Tool>[];
for (final clientInfo in _mcpManager.connectedClients) {
  try {
    final tools = await clientInfo.client.listTools();
    allTools.addAll(tools);
  } catch (e) {
    debugPrint('Failed to get tools from ${clientInfo.name}: $e');
  }
}

// 2) MCP のツール定義を Gemini 用に変換
final geminiTools = _toGeminiTools(allTools);
```

#### 2. MCP → Gemini スキーマ変換
```dart
List<gemini.Tool> _toGeminiTools(List<mcp_client.Tool> infos) =>
    infos.map((t) {
      final schema = gemini.Schema.object(
        properties: _convertToGeminiSchema(t.inputSchema),
      );

      return gemini.Tool(
        functionDeclarations: [
          gemini.FunctionDeclaration(t.name, t.description, schema),
        ],
      );
    }).toList();
```

#### 3. ツール実行と結果処理
```dart
// 5) 適切なMCPクライアントを探してツールを実行
mcp_client.CallToolResult? toolResult;
String? errorMessage;

for (final clientInfo in _mcpManager.connectedClients) {
  try {
    final tools = await clientInfo.client.listTools();
    if (tools.any((tool) => tool.name == call.name)) {
      toolResult = await clientInfo.client.callTool(call.name, call.args);
      break;
    }
  } catch (e) {
    errorMessage = 'Failed to execute tool on ${clientInfo.name}: $e';
  }
}
```

#### 4. エラーハンドリング
- サービス別エラー処理（Notion, Spotify）
- 認証エラーの検出
- レート制限の処理
- 分かりやすいエラーメッセージの生成

### lib/screens/chat_screen.dart

**役割**: MCP統合対応のメインチャット画面

**Step 2 からの主要な追加・変更点**:

#### 1. MCP統合の初期化
```dart
Future<void> _initializeMcpClient() async {
  try {
    final geminiModel = await prepareGemini();
    _mcpManager = McpClientManager();
    _bridge = GeminiMcpBridge(mcpManager: _mcpManager, model: geminiModel);
    
    // 各サーバーに接続を試みる
    for (final status in _mcpManager.serverStatuses) {
      await _mcpManager.connectToServer(status);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }
}
```

#### 2. MCP Bridge を使用したチャット処理
```dart
void _handleSubmitted(String text) async {
  // MCPブリッジ経由でチャット処理
  final response = await _bridge.chat(text);
  setState(() {
    _messages.add(ChatMessage(text: response, isUser: false));
    _isLoading = false;
  });
}
```

#### 3. サーバー管理UI
- `ServerStatusPanel` の統合
- サーバー追加・削除機能
- 接続状態のリアルタイム表示

### lib/components/server_status_panel.dart

**役割**: MCPサーバーの接続状態を表示するパネル

**主な機能**:
- 接続中サーバー数の表示
- 各サーバーの接続状態表示
- エラー情報の表示
- パネルの展開・収納機能
- サーバー削除機能（確認ダイアログ付き）

**UI の特徴**:
```dart
Row(
  children: [
    Icon(
      status.isConnected ? Icons.check_circle : Icons.error,
      color: status.isConnected ? Colors.green : Colors.red,
    ),
    Text(status.name),
    if (status.error != null) Text(status.error!),
    IconButton(
      icon: const Icon(Icons.remove),
      onPressed: () => _showDeleteConfirmation(context, status.name),
    ),
  ],
)
```

### lib/components/add_server_dialog.dart

**役割**: 新しいMCPサーバーを追加するためのダイアログ

**主な機能**:

#### 1. サーバータイプテンプレート
```dart
final Map<String, Map<String, String>> _serverTemplates = {
  'Notion': {
    'name': 'Notion MCP',
    'url': 'http://192.168.11.35:8000/sse',
    'authHeader': 'Authorization',
    'authPrefix': 'Bearer ',
  },
  'Spotify': {
    'name': 'Spotify MCP',
    'url': 'http://192.168.11.35:8001/sse',
    'authHeader': 'Authorization',
    'authPrefix': 'Bearer ',
  },
  'Custom': {
    // カスタムサーバー用
  },
};
```

#### 2. 入力検証
- URL形式の検証
- ホスト名・ポート番号の確認
- 必須フィールドのチェック

#### 3. 認証情報管理
- 認証トークンの入力
- ヘッダー形式の自動生成

## 学習のポイント

### 1. MCP (Model Context Protocol)
- MCP の基本概念と仕組み
- SSE (Server-Sent Events) による通信
- 複数サーバーの管理方法

### 2. 外部サービス統合
- Notion API との連携
- Spotify API との連携
- 認証の管理（API Key, Access Token）

### 3. エラーハンドリング
- 接続タイムアウトの処理
- 認証エラーの検出
- レート制限への対応
- ユーザーフレンドリーなエラーメッセージ

### 4. 状態管理
- 複数サーバーの状態管理
- UI の動的更新
- 非同期処理の制御

### 5. ユーザビリティ
- サーバー管理の UI/UX
- リアルタイムステータス表示
- 直感的な操作性

## 実用例

### Notion との連携
- ページの作成・編集
- データベースの検索
- コンテンツの取得

### Spotify との連携
- プレイリストの管理
- 楽曲検索
- 再生制御

### カスタムサーバー
- 独自のMCPサーバー追加
- プライベートAPI との連携
- 企業内システムとの統合

## アーキテクチャの特徴

### 1. レイヤー分離
- UI レイヤー（Screens, Components）
- サービスレイヤー（Bridge, Manager）
- モデルレイヤー（Data Models）

### 2. 疎結合設計
- MCP クライアントの抽象化
- サーバー管理の独立性
- エラーハンドリングの分離

### 3. 拡張性
- 新しいMCPサーバーの容易な追加
- プラグイン的なアーキテクチャ
- 設定の外部化

## 本格運用への考慮事項

### 1. セキュリティ
- API キーの安全な管理
- 通信の暗号化
- 認証情報の保護

### 2. パフォーマンス
- 接続プールの管理
- キャッシュ戦略
- 非同期処理の最適化

### 3. 監視・ログ
- 接続状態の監視
- エラーログの記録
- パフォーマンス指標の取得

Step 3 では、実用的なアプリケーションレベルでの MCP 統合を実現しています。この実装をベースに、さらなる機能拡張や本格運用に向けた改良を行うことができます。