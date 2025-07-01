import 'package:flutter/material.dart';

class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  final ValueNotifier<ThemeData> themeNotifier = ValueNotifier(
    ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
  );

  // HEXカラーコードからColorを作成
  static Color? parseHexColor(String hexCode) {
    try {
      // #を削除し、大文字に変換
      String code = hexCode.replaceAll('#', '').toUpperCase();
      
      // 3文字の短縮形の場合は6文字に展開
      if (code.length == 3) {
        code = code.split('').map((c) => '$c$c').join();
      }
      
      // 6文字または8文字（アルファ付き）でない場合はnull
      if (code.length != 6 && code.length != 8) {
        return null;
      }
      
      // アルファ値がない場合は追加
      if (code.length == 6) {
        code = 'FF$code';
      }
      
      return Color(int.parse(code, radix: 16));
    } catch (e) {
      return null;
    }
  }

  // 自然言語の色名をColorに変換
  static Color? parseColorFromText(String colorText) {
    final lowerText = colorText.toLowerCase().trim();
    
    // まずHEXコードかチェック
    if (lowerText.startsWith('#') || lowerText.matchAsPrefix(r'^[0-9a-fA-F]{3,8}$') != null) {
      final hexColor = parseHexColor(lowerText);
      if (hexColor != null) {
        return hexColor;
      }
    }
    
    // 基本的な色の対応
    final colorMap = {
      '赤': Colors.red,
      'あか': Colors.red,
      'red': Colors.red,
      '青': Colors.blue,
      'あお': Colors.blue,
      'blue': Colors.blue,
      '緑': Colors.green,
      'みどり': Colors.green,
      'green': Colors.green,
      '黄': Colors.yellow,
      '黄色': Colors.yellow,
      'きいろ': Colors.yellow,
      'yellow': Colors.yellow,
      '紫': Colors.purple,
      'むらさき': Colors.purple,
      'purple': Colors.purple,
      'ピンク': Colors.pink,
      'pink': Colors.pink,
      'オレンジ': Colors.orange,
      'orange': Colors.orange,
      '茶': Colors.brown,
      '茶色': Colors.brown,
      'ちゃいろ': Colors.brown,
      'brown': Colors.brown,
      '黒': Colors.black,
      'くろ': Colors.black,
      'black': Colors.black,
      '白': Colors.white,
      'しろ': Colors.white,
      'white': Colors.white,
      '灰': Colors.grey,
      '灰色': Colors.grey,
      'グレー': Colors.grey,
      'grey': Colors.grey,
      'gray': Colors.grey,
      '水色': Colors.lightBlue,
      'みずいろ': Colors.lightBlue,
      'light blue': Colors.lightBlue,
      '深緑': Colors.green.shade800,
      'ふかみどり': Colors.green.shade800,
      'dark green': Colors.green.shade800,
      '濃い青': Colors.blue.shade800,
      'こいあお': Colors.blue.shade800,
      'dark blue': Colors.blue.shade800,
      '薄紫': Colors.purple.shade300,
      'うすむらさき': Colors.purple.shade300,
      'light purple': Colors.purple.shade300,
      'インディゴ': Colors.indigo,
      'indigo': Colors.indigo,
      'シアン': Colors.cyan,
      'cyan': Colors.cyan,
      'ライム': Colors.lime,
      'lime': Colors.lime,
      'アンバー': Colors.amber,
      'amber': Colors.amber,
    };

    // 完全一致を探す
    for (final entry in colorMap.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  void updateTheme(Color seedColor) {
    themeNotifier.value = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      useMaterial3: true,
    );
  }

  void updateThemeFromText(String colorText) {
    final color = parseColorFromText(colorText);
    if (color != null) {
      updateTheme(color);
    }
  }
}