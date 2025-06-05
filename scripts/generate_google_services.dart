import 'dart:convert';
import 'dart:io';

/// Google Services設定ファイルを環境変数から動的に生成するスクリプト
void main() {
  generateAndroidGoogleServices();
  generateIosGoogleServiceInfo();
  print('Google Services設定ファイルを生成しました。');
}

void generateAndroidGoogleServices() {
  final projectNumber = Platform.environment['FIREBASE_PROJECT_NUMBER'] ?? '98948773919';
  final projectId = Platform.environment['FIREBASE_PROJECT_ID'] ?? 'chat-hands-on';
  final storageBucket = Platform.environment['FIREBASE_STORAGE_BUCKET'] ?? 'chat-hands-on.firebasestorage.app';
  final appId = Platform.environment['FIREBASE_ANDROID_APP_ID'] ?? '1:98948773919:android:f8f94ee7c7db6d1b6a3d2a';
  final apiKey = Platform.environment['FIREBASE_API_KEY_ANDROID'] ?? '';
  final packageName = Platform.environment['ANDROID_PACKAGE_NAME'] ?? 'com.example.mcp_notion_client';

  if (apiKey.isEmpty) {
    print('警告: FIREBASE_API_KEY_ANDROID が設定されていません');
  }

  final googleServicesJson = {
    "project_info": {
      "project_number": projectNumber,
      "project_id": projectId,
      "storage_bucket": storageBucket
    },
    "client": [
      {
        "client_info": {
          "mobilesdk_app_id": appId,
          "android_client_info": {
            "package_name": packageName
          }
        },
        "oauth_client": [],
        "api_key": [
          {
            "current_key": apiKey
          }
        ],
        "services": {
          "appinvite_service": {
            "other_platform_oauth_client": []
          }
        }
      }
    ],
    "configuration_version": "1"
  };

  final androidDir = Directory('android/app');
  if (!androidDir.existsSync()) {
    androidDir.createSync(recursive: true);
  }

  final file = File('android/app/google-services.json');
  file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(googleServicesJson));
  print('✅ android/app/google-services.json を生成しました');
}

void generateIosGoogleServiceInfo() {
  final apiKey = Platform.environment['FIREBASE_API_KEY_IOS'] ?? '';
  final gcmSenderId = Platform.environment['FIREBASE_PROJECT_NUMBER'] ?? '98948773919';
  final bundleId = Platform.environment['IOS_BUNDLE_ID'] ?? 'com.example.mcpNotionClient';
  final projectId = Platform.environment['FIREBASE_PROJECT_ID'] ?? 'chat-hands-on';
  final storageBucket = Platform.environment['FIREBASE_STORAGE_BUCKET'] ?? 'chat-hands-on.firebasestorage.app';
  final googleAppId = Platform.environment['FIREBASE_IOS_APP_ID'] ?? '1:98948773919:ios:c9bb3f1d569266bf6a3d2a';

  if (apiKey.isEmpty) {
    print('警告: FIREBASE_API_KEY_IOS が設定されていません');
  }

  final plistContent = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>$apiKey</string>
	<key>GCM_SENDER_ID</key>
	<string>$gcmSenderId</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>$bundleId</string>
	<key>PROJECT_ID</key>
	<string>$projectId</string>
	<key>STORAGE_BUCKET</key>
	<string>$storageBucket</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<true></true>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<true></true>
	<key>GOOGLE_APP_ID</key>
	<string>$googleAppId</string>
</dict>
</plist>''';

  final iosDir = Directory('ios/Runner');
  if (!iosDir.existsSync()) {
    iosDir.createSync(recursive: true);
  }

  final file = File('ios/Runner/GoogleService-Info.plist');
  file.writeAsStringSync(plistContent);
  print('✅ ios/Runner/GoogleService-Info.plist を生成しました');
}