import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart';

late final Client mcp;                // ← 型を Client に

Future<void> initMcp() async {
  mcp = McpClient.createClient(
    name: 'MuseumJourney',
    version: '1.0.0',
    capabilities: ClientCapabilities(sampling: true),
  );

  final transport = await McpClient.createSseTransport(
    serverUrl: 'http://10.0.2.2:8080/sse',
  );
  await mcp.connect(transport);

  // ✅ これでエラーは出ない
  final tools = await mcp.listTools();
  debugPrint('tools: ${tools.map((t) => t.name)}');
}