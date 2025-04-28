import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mcp_server_config.dart';

part 'settings_provider.g.dart';
part 'settings_provider.freezed.dart';

@riverpod
class SettingsProvider extends _$SettingsProvider {
  // SharedPreferences用のキー
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _mcpServersKey = 'mcp_servers';

  @override
  SettingsState build() {
    return SettingsState();
  }

  // 初期化メソッド
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final geminiApiKey = prefs.getString(_apiKeyKey);

    final serversJson = prefs.getString(_mcpServersKey);
    if (serversJson != null) {
      final List<dynamic> serversList = jsonDecode(serversJson);
      final mcpServers =
          serversList
              .map((server) => McpServerConfig.fromJson(server))
              .toList();
      state = state.copyWith(
        geminiApiKey: geminiApiKey,
        mcpServers: mcpServers,
      );
    }
  }

  // Gemini API Keyの保存
  Future<void> saveApiKey(String apiKey) async {
    state = state.copyWith(geminiApiKey: apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  // MCP サーバーの追加
  Future<void> addMcpServer(McpServerConfig server) async {
    state = state.copyWith(mcpServers: [...state.mcpServers, server]);
    await _saveMcpServers();
  }

  // MCP サーバーの更新
  Future<void> updateMcpServer(int index, McpServerConfig server) async {
    if (index >= 0 && index < state.mcpServers.length) {
      final updatedServers =
          state.mcpServers.map((e) => e.copyWith(isConnected: false)).toList();
      updatedServers[index] = server;
      state = state.copyWith(mcpServers: updatedServers);
      await _saveMcpServers();
    }
  }

  // MCP サーバーの削除
  Future<void> removeMcpServer(int index) async {
    if (index >= 0 && index < state.mcpServers.length) {
      final updatedServers =
          state.mcpServers.map((e) => e.copyWith(isConnected: false)).toList();
      updatedServers.removeAt(index);
      state = state.copyWith(mcpServers: updatedServers);
      await _saveMcpServers();
    }
  }

  // MCP サーバーの保存
  Future<void> _saveMcpServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mcpServersKey, jsonEncode(state.mcpServers));
  }

  // MCP サーバーの接続状態の切り替え
  Future<void> toggleServerConnection(int index) async {
    if (index >= 0 && index < state.mcpServers.length) {
      final updatedServers =
          state.mcpServers.map((e) => e.copyWith(isConnected: false)).toList();
      updatedServers[index] = updatedServers[index].copyWith(isConnected: true);
      state = state.copyWith(mcpServers: updatedServers);
      await _saveMcpServers();
    }
  }
}

@freezed
sealed class SettingsState with _$SettingsState {
  factory SettingsState({
    String? geminiApiKey,
    @Default([]) List<McpServerConfig> mcpServers,
  }) = _SettingsState;

  const SettingsState._();

  // String? get geminiApiKey => _geminiApiKey;
  // List<McpServerConfig> get mcpServers => _mcpServers;
}
