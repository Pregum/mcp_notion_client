import 'package:flutter/material.dart';
import 'lib/screens/chat_screen.dart';

Future<void> main() async {
  runApp(const Step2App());
}

class Step2App extends StatelessWidget {
  const Step2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step2: Flutter x Gemini x Local Tools',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}