# mcp_notion_client

## 概要

mcp_clientライブラリを使用して gemini経由でNotion MCPサーバーにsse接続するサンプルアプリです。
sse接続するサーバーは、ローカルPC上に立ててアプリはそこへ接続しています

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

```shell
OPENAPI_MCP_HEADERS='{"Authorization":"Bearer ntn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","Notion-Version":"2022-06-28"}' \
npx -y supergateway --stdio "npx -y @notionhq/notion-mcp-server"
```

notionのtokenは
[インテグレーションページ](https://www.notion.so/profile/integrations)で作成したapi keyを適用してください
また、[こちら](https://notion.notion.site/Notion-MCP-1d0efdeead058054a339ffe6b38649e1)のCursorでの設定方法の5.に記載されているように操作したいページにMCPの接続設定をしておかないと操作できないため、注意してください。

### page idの取得方法

こちらのページを参照してください

<https://booknotion.site/setting-pageid>
