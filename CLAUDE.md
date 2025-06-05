# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that bridges Gemini AI with Notion via MCP (Model Context Protocol). The app connects to Notion MCP servers running locally via SSE (Server-Sent Events) and provides a chat interface for natural language interaction with Notion.

## Core Architecture

### MCP Bridge Pattern
- `GeminiMcpBridge` (`lib/services/gemini_mcp_bridge.dart`) orchestrates communication between Gemini and MCP servers
- Converts MCP tool definitions to Gemini function declarations
- Handles function calling flow: user input → Gemini → MCP tool execution → response summarization

### Client Management
- `McpClientManager` (`lib/services/mcp_client_manager.dart`) manages multiple MCP server connections
- Supports adding/removing servers dynamically
- Handles connection failures gracefully
- Default servers: Notion MCP (port 8000), Spotify MCP (port 8001)

### State Architecture
- Chat history maintained in `GeminiMcpBridge`
- Server statuses tracked in `McpClientManager`
- UI state managed in `ChatScreen` with Flutter's StatefulWidget

## Development Commands

### Setup
```bash
flutter pub get
```

### Run Development
```bash
flutter run
```

### Build for Production
```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build macos      # macOS
```

### Code Generation
```bash
dart run build_runner build            # Generate freezed/json models
dart run build_runner build --delete-conflicting-outputs  # Force regenerate
```

### Testing
```bash
flutter test
```

### Linting
```bash
flutter analyze
```

## Environment Configuration

Create `.env` file with:
```
GEMINI_API_KEY=your_gemini_api_key
NOTION_API_KEY=ntn_your_notion_api_key  
SERVER_IP=your_local_ip_address
```

## MCP Server Setup

Run Notion MCP server locally using supergateway:
```bash
OPENAPI_MCP_HEADERS='{"Authorization":"Bearer ntn_your_notion_api_key","Notion-Version":"2022-06-28"}' \
npx -y supergateway --stdio "npx -y @notionhq/notion-mcp-server"
```

## Key Dependencies

- `mcp_client: ^0.1.7` - MCP protocol implementation
- `google_generative_ai: ^0.4.6` - Gemini API client
- `flutter_gemini: ^3.0.0-dev.1` - Additional Gemini utilities
- `hooks_riverpod: ^2.4.9` - State management (though not heavily used)
- `freezed: ^3.0.4` - Code generation for immutable classes

## File Structure Notes

- `lib/services/` - Core business logic and external service integrations
- `lib/models/` - Data models with freezed code generation
- `lib/components/` - Reusable UI components
- `lib/screens/` - Top-level screen widgets
- Error handling focuses on connection failures and API authentication issues