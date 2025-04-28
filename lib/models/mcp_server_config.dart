import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_server_config.freezed.dart';
part 'mcp_server_config.g.dart';

@freezed
sealed class McpServerConfig with _$McpServerConfig {
  const factory McpServerConfig({
    required String name,
    required String command,
    required List<String> args,
    @Default({}) Map<String, String> env,
    @Default(false) bool isConnected,
  }) = _McpServerConfig;

  factory McpServerConfig.fromJson(Map<String, dynamic> json) =>
      _$McpServerConfigFromJson(json);
}
