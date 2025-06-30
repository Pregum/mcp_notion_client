import 'package:flutter/material.dart';
import 'package:mcp_notion_client/screens/step1_chat_screen.dart';

Future<void> main() async {
  runApp(const Step1App());
}

class Step1App extends StatelessWidget {
  const Step1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step1: Flutter x Gemini',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Step1ChatScreen(),
    );
  }
}