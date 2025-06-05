import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/services.dart';
import '../lib/firebase_options.dart';

void main() {
  group('Firebase AI Thinking Tests', () {
    setUpAll(() async {
      // Flutter binding初期化
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Firebase初期化
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    });

    test('Firebase AI thinking model response analysis', () async {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) {
        print('⚠️ GEMINI_API_KEY environment variable not set, skipping test');
        return;
      }

      try {
        final ai = FirebaseAI.googleAI();
        
        // thinking対応モデルを作成
        final model = ai.generativeModel(
          model: 'gemini-2.0-flash-thinking-exp',
          generationConfig: GenerationConfig(
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 2048,
          ),
        );

        print('🧪 Testing Firebase AI thinking model...');
        
        final prompt = '2+2は何ですか？計算の過程も含めて詳しく説明してください。';
        final response = await model.generateContent([Content.text(prompt)]);

        print('📊 Firebase AI Response Analysis:');
        print('Candidates count: ${response.candidates.length}');
        
        bool thinkingInfoFound = false;
        
        for (var i = 0; i < response.candidates.length; i++) {
          final candidate = response.candidates[i];
          print('\n--- Candidate $i ---');
          print('Text length: ${candidate.text?.length ?? 0}');
          print('Finish Reason: ${candidate.finishReason}');
          print('Content parts count: ${candidate.content.parts.length}');
          
          // Content partsの詳細分析
          for (var j = 0; j < candidate.content.parts.length; j++) {
            final part = candidate.content.parts[j];
            final partString = part.toString();
            
            print('\nPart $j:');
            print('Type: ${part.runtimeType}');
            print('Content preview: ${partString.length > 200 ? partString.substring(0, 200) + "..." : partString}');
            
            // thinking関連キーワードをチェック
            final lowerContent = partString.toLowerCase();
            final thinkingKeywords = [
              'thinking', 'reasoning', 'thought', 'analysis',
              '考え', '思考', '分析', 'ステップ'
            ];
            
            for (final keyword in thinkingKeywords) {
              if (lowerContent.contains(keyword)) {
                print('🧠 Thinking keyword "$keyword" found in part $j!');
                thinkingInfoFound = true;
                
                // thinking情報がある場合の詳細ログ
                if (partString.length < 1000) {
                  print('Full thinking content: $partString');
                } else {
                  print('Thinking content (first 500 chars): ${partString.substring(0, 500)}...');
                }
              }
            }
          }
          
          //候補のテキスト全体もチェック
          if (candidate.text != null) {
            final fullText = candidate.text!.toLowerCase();
            if (fullText.contains('thinking') || fullText.contains('reasoning') || 
                fullText.contains('考え') || fullText.contains('思考')) {
              print('🧠 Thinking information detected in candidate text!');
              thinkingInfoFound = true;
            }
            
            print('\nFull response text:');
            print(candidate.text!.length > 500 ? 
                  '${candidate.text!.substring(0, 500)}...' : 
                  candidate.text!);
          }
        }
        
        // 結果の総評
        print('\n🔍 === FIREBASE AI THINKING ANALYSIS RESULTS ===');
        if (thinkingInfoFound) {
          print('✅ Thinking information was detected in Firebase AI response!');
          print('🎉 Firebase AI appears to provide thinking information natively');
        } else {
          print('❌ No thinking information detected in Firebase AI response');
          print('💡 Firebase AI may not provide native thinking information');
        }
        print('======================================================\n');
        
        expect(response.candidates.isNotEmpty, true);
        
      } catch (e, stackTrace) {
        print('❌ Error testing Firebase AI: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Compare Google Generative AI vs Firebase AI response structure', () async {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) {
        print('⚠️ GEMINI_API_KEY environment variable not set, skipping test');
        return;
      }

      print('🔄 Comparing response structures...');
      
      // Firebase AI test
      try {
        final ai = FirebaseAI.googleAI();
        final firebaseModel = ai.generativeModel(model: 'gemini-2.0-flash-thinking-exp');
        final firebaseResponse = await firebaseModel.generateContent([
          Content.text('簡単な足し算: 1+1は？')
        ]);
        
        print('\n📱 Firebase AI Response Structure:');
        print('Response type: ${firebaseResponse.runtimeType}');
        print('Has candidates: ${firebaseResponse.candidates.isNotEmpty}');
        if (firebaseResponse.candidates.isNotEmpty) {
          final candidate = firebaseResponse.candidates.first;
          print('Candidate type: ${candidate.runtimeType}');
          print('Content parts: ${candidate.content.parts.length}');
          print('Has text: ${candidate.text != null}');
        }
        
      } catch (e) {
        print('Firebase AI test failed: $e');
      }
      
      // Google Generative AI comparison would go here
      // Note: We're focusing on Firebase AI for this investigation
      
      print('✅ Response structure comparison completed');
    });
  });
}