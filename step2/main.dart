import 'package:flutter/material.dart';
import 'lib/screens/chat_screen.dart';
import 'lib/services/theme_manager.dart';

Future<void> main() async {
  runApp(const Step2App());
}

class Step2App extends StatelessWidget {
  const Step2App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    
    return ValueListenableBuilder<ThemeData>(
      valueListenable: themeManager.themeNotifier,
      builder: (context, theme, child) {
        return MaterialApp(
          title: 'Step2: Flutter x Gemini x Local Tools',
          theme: theme,
          home: const ChatScreen(),
        );
      },
    );
  }
}