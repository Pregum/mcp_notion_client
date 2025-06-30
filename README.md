# mcp_notion_client

## 概要

mcp_clientライブラリを使用して gemini経由でNotion MCPサーバーにsse接続するサンプルアプリです。
sse接続するサーバーは、ローカルPC上に立ててアプリはそこへ接続しています
アプリの場合は、stdio接続ではなくsseで接続するため、Notion MCPのstdioをsseに変換するためにsupergatewayを使用しています。
詳細はこちらの方の記事がわかりやすかったです。
<https://notai.jp/supergateway/>

## 事前準備

事前に以下のアカウントが必要です

- Google アカウント
- Notion アカウント

起動前に.envに以下の設定を行ってください

- GEMINI_API_KEY
  - <https://aistudio.google.com/app/apikey> から api keyを取得して設定してください
- NOTION_API_KEY
  - [notionのインテグレーション](https://www.notion.so/profile/integrations) で取得したAPI Keyを設定してください
- SERVER_IP
  - ローカルPCのIPアドレス(ifconfigなどで取得したローカルIPアドレスを設定してください)

```.env
GEMINI_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
NOTION_API_KEY=ntn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SERVER_IP=xxx.xxx.xx.xx
```

## demo

<https://x.com/i/status/1917635132045025587>

### 実際に叩いた時のローカルサーバのコマンド

supergatewayを使用してNotion MCPサーバーをローカルPC上で立ち上げた時のコマンドです。

```shell
OPENAPI_MCP_HEADERS='{"Authorization":"Bearer ntn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","Notion-Version":"2022-06-28"}' \
npx -y supergateway --stdio "npx -y @notionhq/notion-mcp-server"
```

notionのtokenは
[インテグレーションページ](https://www.notion.so/profile/integrations)で作成したapi keyを適用してください
また、[こちら](https://notion.notion.site/Notion-MCP-1d0efdeead058054a339ffe6b38649e1)のCursorでの設定方法の5.に記載されているように操作したいページにMCPの接続設定をしておかないと操作できないため、注意してください。

### notion page idの取得方法

Notionのページ操作をする際にpage idが必要になることがあるので
こちらのページを参照して取得してください

<https://booknotion.site/setting-pageid>

## プロジェクト構成

### lib/ディレクトリ構成

```
lib/
├── main.dart                           # アプリケーションのエントリーポイント
├── screens/
│   └── chat_screen.dart               # メイン画面（チャットUI）
├── services/
│   ├── gemini_mcp_bridge.dart         # Gemini AIとMCPサーバーを繋ぐ橋渡し役
│   └── mcp_client_manager.dart        # MCPクライアントの管理
├── models/
│   ├── chat_message.dart              # チャットメッセージのデータモデル
│   └── mcp_server_status.dart         # MCPサーバーの状態管理
└── components/
    ├── add_server_dialog.dart         # サーバー追加ダイアログ
    └── server_status_panel.dart       #接続状態表示パネル
```

### 各ファイルの役割

#### main.dart
- Flutter アプリケーションのエントリーポイント
- MaterialApp の設定とChatScreenの起動
- アプリ全体のテーマ設定

#### screens/chat_screen.dart
- メインのチャット画面UI
- ユーザーとの対話インターフェース
- MCPサーバーの接続状態表示
- サーバー追加・削除機能

#### services/gemini_mcp_bridge.dart
- Gemini AIとMCPサーバー間の通信を仲介
- MCP ツール定義をGemini用に変換
- チャット履歴の管理
- Function Calling フローの制御
- エラーハンドリング（認証エラー、レート制限など）

#### services/mcp_client_manager.dart
- 複数のMCPサーバーへの接続管理
- デフォルトサーバー（Notion、Spotify）の初期化
- サーバーの動的追加・削除機能
- 接続タイムアウト処理

#### models/chat_message.dart
- チャットメッセージの表示コンポーネント
- ユーザー/AI の発言を区別して表示
- メッセージのスタイリング

#### models/mcp_server_status.dart
- MCPサーバーの接続状態を表すデータモデル
- サーバー名、URL、ヘッダー、接続状態、エラー情報を管理

#### components/add_server_dialog.dart
- 新しいMCPサーバーを追加するためのダイアログ
- サーバータイプのテンプレート機能
- URL・認証情報の入力フォーム

#### components/server_status_panel.dart
- MCPサーバーの接続状態を表示するパネル
- 接続中サーバー数の表示
- サーバーの削除機能
- パネルの展開・収納機能

## データフロー図

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant UI as ChatScreen
    participant Bridge as GeminiMcpBridge
    participant Gemini as Gemini AI
    participant Manager as McpClientManager
    participant MCPClient as MCP Client
    participant MCPServer as MCP Server

    User->>UI: メッセージ入力
    UI->>Bridge: chat(userPrompt)
    
    Bridge->>Manager: connectedClients取得
    Manager-->>Bridge: 接続中クライアント一覧
    
    loop 各接続クライアント
        Bridge->>MCPClient: listTools()
        MCPClient-->>Bridge: 利用可能ツール一覧
    end
    
    Bridge->>Bridge: MCPツール→Gemini形式変換
    Bridge->>Gemini: generateContent(prompt, tools)
    Gemini-->>Bridge: 応答（Function Call含む）
    
    alt Function Call有り
        loop 各接続クライアント
            Bridge->>MCPClient: callTool(name, args)
            MCPClient->>MCPServer: ツール実行要求
            MCPServer-->>MCPClient: 実行結果
            MCPClient-->>Bridge: 実行結果
        end
        
        Bridge->>Gemini: generateContent(実行結果)
        Gemini-->>Bridge: 日本語要約
    else 通常の応答
        Bridge-->>UI: テキスト応答
    end
    
    Bridge-->>UI: 最終応答
    UI->>User: 結果表示
```
