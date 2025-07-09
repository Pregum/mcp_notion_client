# mcp_notion_client

## 概要

mcp_clientライブラリを使用して gemini経由でNotion MCPサーバーにsse接続するサンプルアプリです。
sse接続するサーバーは、ローカルPC上に立ててアプリはそこへ接続しています
アプリの場合は、stdio接続ではなくsseで接続するため、Notion MCPのstdioをsseに変換するためにsupergatewayを使用しています。
詳細はこちらの方の記事がわかりやすかったです。
<https://notai.jp/supergateway/>

このプロジェクトは学習用に3つのステップ（step1〜3）に分かれており、段階的にLLM統合を学べる構成になっています。
また、ルートレベルの`lib/`ディレクトリにはstep3と同じ完全版の実装が含まれており、`flutter run`でメインアプリケーションとして実行できます。

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

supergatewayを使用して各MCPサーバーをローカルPC上で立ち上げた時のコマンドです。

#### Notion MCP (ポート8000)

```shell
OPENAPI_MCP_HEADERS='{"Authorization":"Bearer ntn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","Notion-Version":"2022-06-28"}' \
npx -y supergateway --port 8000 --stdio "npx -y @notionhq/notion-mcp-server"
```

#### Mobile MCP (ポート8002)

```shell
npx -y supergateway --port 8002 --stdio "npx -y @mobilenext/mobile-mcp@0.0.19"
```

notionのtokenは
[インテグレーションページ](https://www.notion.so/profile/integrations)で作成したapi keyを適用してください
また、[こちら](https://notion.notion.site/Notion-MCP-1d0efdeead058054a339ffe6b38649e1)のCursorでの設定方法の5.に記載されているように操作したいページにMCPの接続設定をしておかないと操作できないため、注意してください。

### notion page idの取得方法

Notionのページ操作をする際にpage idが必要になることがあるので
こちらのページを参照して取得してください

<https://booknotion.site/setting-pageid>

## プロジェクト構成

### ディレクトリ構成

```
├── lib/                                # メインアプリケーション (step3と同じ構成)
│   ├── components/
│   │   ├── add_server_dialog.dart      # サーバー追加ダイアログ
│   │   └── server_status_panel.dart    # サーバー状態表示パネル
│   ├── models/
│   │   ├── chat_message.dart           # チャットメッセージUI
│   │   └── mcp_server_status.dart      # MCPサーバー状態管理
│   ├── screens/
│   │   └── chat_screen.dart            # MCP統合チャット画面
│   └── services/
│       ├── gemini_mcp_bridge.dart      # Gemini-MCP橋渡し
│       └── mcp_client_manager.dart     # MCPクライアント管理
├── docs/                               # ドキュメント
│   ├── README.md                       # ドキュメント一覧
│   ├── step1.md                        # Step 1の詳細説明
│   ├── step2.md                        # Step 2の詳細説明
│   └── step3.md                        # Step 3の詳細説明
├── step1/                              # Step 1: Flutter x Gemini 基本接続
│   ├── main.dart                       # エントリーポイント
│   └── lib/
│       ├── models/
│       │   └── chat_message.dart       # チャットメッセージUI
│       └── screens/
│           └── chat_screen.dart        # 基本チャット画面
├── step2/                              # Step 2: Flutter x Gemini x ローカルツール
│   ├── main.dart                       # エントリーポイント
│   └── lib/
│       ├── models/
│       │   └── chat_message.dart       # チャットメッセージUI
│       ├── services/
│       │   └── local_tools.dart        # ローカルツール実装
│       └── screens/
│           └── chat_screen.dart        # Function Calling対応チャット画面
└── step3/                              # Step 3: Flutter x Gemini x MCP (完全版)
    ├── main.dart                       # エントリーポイント
    └── lib/
        ├── components/
        │   ├── add_server_dialog.dart   # サーバー追加ダイアログ
        │   └── server_status_panel.dart # サーバー状態表示パネル
        ├── models/
        │   ├── chat_message.dart        # チャットメッセージUI
        │   └── mcp_server_status.dart   # MCPサーバー状態管理
        ├── screens/
        │   ├── chat_screen.dart         # MCP統合チャット画面
        │   ├── step1_chat_screen.dart   # Step 1画面の統合版
        │   └── step2_chat_screen.dart   # Step 2画面の統合版
        └── services/
            ├── gemini_mcp_bridge.dart   # Gemini-MCP橋渡し
            ├── mcp_client_manager.dart  # MCPクライアント管理
            ├── mcp_tools.dart           # MCPツール管理
            └── step2_local_tools.dart   # Step 2のローカルツール
```

### 各ステップの特徴

#### Step 1: 基本接続

- **目的**: Gemini APIとの基本的な接続方法を学習
- **機能**: シンプルなチャット機能のみ
- **学習ポイント**: API認証、基本的なリクエスト/レスポンス処理

#### Step 2: ローカルツール

- **目的**: Function Callingの仕組みを理解
- **機能**: 3つのローカルツール（挨拶、計算、Web検索モック）
- **学習ポイント**: ツール定義、手動実行、AI自動選択

#### Step 3: MCP統合

- **目的**: 実用的なMCPサーバー連携を実装
- **機能**: Notion/Spotify等の外部サービス統合
- **学習ポイント**: 複数サーバー管理、認証、エラーハンドリング

## 段階的学習ステップ

このプロジェクトには、LLM統合を段階的に学習するための3つのステップが用意されています：

### Step 1: Flutter x Gemini 基本接続

```bash
cd step1
flutter run
```

**学習内容:**

- Flutter から Gemini API への基本的な接続
- シンプルなチャット機能の実装
- API キーの設定と認証
- ツール機能は未実装（確認用ボタンあり）

**特徴:**

- 最小限のコード構成
- Gemini との対話のみ
- エラーハンドリングの基本

### Step 2: Flutter x Gemini x ローカルツール

```bash
cd step2
flutter run
```

**学習内容:**

- Function Calling の実装
- ローカルツールの定義と実行
- ツールの手動実行とAI自動選択
- ツール実行結果の処理

**実装されているツール:**

1. **hello_gemini**: Gemini への挨拶ツール
2. **calculate**: 2つの整数の計算ツール
3. **web_search**: Web検索のモック実装

**特徴:**

- ツール一覧表示機能
- 手動ツール実行ダイアログ
- AI による自動ツール選択
- 実行結果の可視化

### Step 3: Flutter x Gemini x MCP (完全版)

```bash
cd step3
flutter run
```

**学習内容:**

- MCP (Model Context Protocol) サーバーとの接続
- 複数のMCPクライアント管理
- 動的なサーバー追加・削除
- 外部サービス（Notion、Spotify）との統合
- Step 1, 2の機能も統合された完全版

**特徴:**

- 本格的なMCPサーバー連携
- サーバー状態管理
- 認証とエラーハンドリング
- 実用的なツール群
- Step 1, 2の画面も含む統合版として実装

**追加ファイル:**

- **step1_chat_screen.dart**: Step 1の機能をStep 3内で利用可能にした画面
- **step2_chat_screen.dart**: Step 2の機能をStep 3内で利用可能にした画面
- **mcp_tools.dart**: MCPツールの管理とGemini形式への変換
- **step2_local_tools.dart**: Step 2のローカルツールをStep 3で再利用

## 推奨学習順序

1. **Step 1** でGemini APIとの基本接続を理解
2. **Step 2** でFunction Callingとローカルツールを体験
3. **Step 3** でMCPサーバーとの本格連携を学習

各ステップは独立して動作し、段階的に複雑さが増していきます。

## 詳細ドキュメント

各ステップの詳細なファイル構成と実装内容については、`docs/`ディレクトリ内のドキュメントを参照してください：

- [docs/README.md](docs/README.md) - ドキュメント一覧と学習の流れ
- [docs/step1.md](docs/step1.md) - Step 1の詳細な実装解説
- [docs/step2.md](docs/step2.md) - Step 2の詳細な実装解説
- [docs/step3.md](docs/step3.md) - Step 3の詳細な実装解説

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
