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

## ファイル構成

### メインファイル
- `lib/main.dart` - アプリのエントリーポイント、MyAppウィジェットの定義

### 画面（Screens）
- `lib/screens/chat_screen.dart` - メインのチャット画面、MCP初期化とUI管理

### サービス（Services）
- `lib/services/gemini_mcp_bridge.dart` - GeminiとMCPサーバー間の橋渡し、思考プロセス機能
- `lib/services/mcp_client_manager.dart` - 複数MCPサーバーの接続管理

### モデル（Models）
- `lib/models/chat_message.dart` - チャットメッセージとthinking表示のUIコンポーネント
- `lib/models/mcp_server_status.dart` - MCPサーバーの状態管理

### コンポーネント（Components）
- `lib/components/server_status_panel.dart` - MCPサーバー状態表示パネル
- `lib/components/add_server_dialog.dart` - 新しいMCPサーバー追加ダイアログ

### 設定ファイル
- `CLAUDE.md` - Claude Code用の開発ガイダンス
- `pubspec.yaml` - Flutterプロジェクトの依存関係とメタデータ
- `analysis_options.yaml` - Dartコード解析設定

## 主要機能

### 1. MCP接続管理
- 複数のMCPサーバーへの同時接続
- サーバーの動的追加・削除
- 接続状態のリアルタイム表示

### 2. AIチャット機能
- Gemini APIを使用した自然言語処理
- MCPツールの自動選択と実行
- 会話履歴の管理

### 3. 思考プロセス可視化
- AIの思考プロセスをリアルタイム表示
- 4段階の思考ステップ（分析・計画・実行・完了）
- 進行状況のビジュアル表示
