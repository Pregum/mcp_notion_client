import 'package:flutter/material.dart';
import 'lib/screens/chat_screen.dart';

Future<void> main() async {
  runApp(const Step3App());
}

class Step3App extends StatelessWidget {
  const Step3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step3: Flutter x Gemini x MCP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
