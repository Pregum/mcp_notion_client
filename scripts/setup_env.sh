#!/bin/bash

# Google Services設定ファイル生成スクリプト
# 使用方法: ./scripts/setup_env.sh

echo "🔧 Google Services設定ファイルを生成しています..."

# 環境変数の確認
if [ -z "$FIREBASE_API_KEY_ANDROID" ]; then
    echo "⚠️  警告: FIREBASE_API_KEY_ANDROID が設定されていません"
fi

if [ -z "$FIREBASE_API_KEY_IOS" ]; then
    echo "⚠️  警告: FIREBASE_API_KEY_IOS が設定されていません"
fi

# Dartスクリプトを実行
dart run scripts/generate_google_services.dart

echo "✅ セットアップ完了"
echo ""
echo "📝 必要な環境変数:"
echo "  FIREBASE_API_KEY_ANDROID"
echo "  FIREBASE_API_KEY_IOS"
echo "  FIREBASE_API_KEY_MACOS"
echo "  FIREBASE_API_KEY_WEB"
echo "  FIREBASE_PROJECT_NUMBER (オプション)"
echo "  FIREBASE_PROJECT_ID (オプション)"
echo "  FIREBASE_STORAGE_BUCKET (オプション)"
echo "  FIREBASE_ANDROID_APP_ID (オプション)"
echo "  FIREBASE_IOS_APP_ID (オプション)"
echo "  ANDROID_PACKAGE_NAME (オプション)"
echo "  IOS_BUNDLE_ID (オプション)"