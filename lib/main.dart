import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mcp_client/mcp_client.dart';

Future<void> main() async {
  // 2. MCPクライアントの初期化
  await setupMcpClient();
  // 3. Gemini モデルの用意
  await prepareGemini();
  runApp(const MyApp());
}

Future<void> prepareGemini() async {
  // Gemini 2.5 Pro は Function Calling がデフォルト有効。
  final gemini = GenerativeModel(
    model:
        'gemini-2.5-pro', // 2025-04 GA モデル  [oai_citation:10‡IT Pro](https://www.itpro.com/cloud/live/google-cloud-next-2025-all-the-news-and-updates-live?utm_source=chatgpt.com)
    apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
  );
}

Future<void> setupMcpClient() async {
  final mcp = McpClient.createClient(
    name: 'MuseumJourney',
    version: '1.0.0',
    capabilities: ClientCapabilities(
      sampling: true, // Gemini による LLM 生成も流せる
    ),
  );

  // Android エミュ とのローカル接続例 (SSE)
  final transport = await McpClient.createSseTransport(
    serverUrl: 'http://10.0.2.2:8080/sse',
  );
  await mcp.connect(transport); // 🔑 ここでハンドシェイク
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
