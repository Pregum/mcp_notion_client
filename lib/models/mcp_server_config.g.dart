// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_server_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McpServerConfig _$McpServerConfigFromJson(Map<String, dynamic> json) =>
    _McpServerConfig(
      name: json['name'] as String,
      command: json['command'] as String,
      args: (json['args'] as List<dynamic>).map((e) => e as String).toList(),
      env:
          (json['env'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      isConnected: json['isConnected'] as bool? ?? false,
    );

Map<String, dynamic> _$McpServerConfigToJson(_McpServerConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'command': instance.command,
      'args': instance.args,
      'env': instance.env,
      'isConnected': instance.isConnected,
    };
