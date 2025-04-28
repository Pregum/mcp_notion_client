// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_server_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpServerConfig {

 String get name; String get command; List<String> get args; Map<String, String> get env; bool get isConnected;
/// Create a copy of McpServerConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpServerConfigCopyWith<McpServerConfig> get copyWith => _$McpServerConfigCopyWithImpl<McpServerConfig>(this as McpServerConfig, _$identity);

  /// Serializes this McpServerConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other.args, args)&&const DeepCollectionEquality().equals(other.env, env)&&(identical(other.isConnected, isConnected) || other.isConnected == isConnected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,command,const DeepCollectionEquality().hash(args),const DeepCollectionEquality().hash(env),isConnected);

@override
String toString() {
  return 'McpServerConfig(name: $name, command: $command, args: $args, env: $env, isConnected: $isConnected)';
}


}

/// @nodoc
abstract mixin class $McpServerConfigCopyWith<$Res>  {
  factory $McpServerConfigCopyWith(McpServerConfig value, $Res Function(McpServerConfig) _then) = _$McpServerConfigCopyWithImpl;
@useResult
$Res call({
 String name, String command, List<String> args, Map<String, String> env, bool isConnected
});




}
/// @nodoc
class _$McpServerConfigCopyWithImpl<$Res>
    implements $McpServerConfigCopyWith<$Res> {
  _$McpServerConfigCopyWithImpl(this._self, this._then);

  final McpServerConfig _self;
  final $Res Function(McpServerConfig) _then;

/// Create a copy of McpServerConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? command = null,Object? args = null,Object? env = null,Object? isConnected = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>,env: null == env ? _self.env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>,isConnected: null == isConnected ? _self.isConnected : isConnected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _McpServerConfig implements McpServerConfig {
  const _McpServerConfig({required this.name, required this.command, required final  List<String> args, final  Map<String, String> env = const {}, this.isConnected = false}): _args = args,_env = env;
  factory _McpServerConfig.fromJson(Map<String, dynamic> json) => _$McpServerConfigFromJson(json);

@override final  String name;
@override final  String command;
 final  List<String> _args;
@override List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}

 final  Map<String, String> _env;
@override@JsonKey() Map<String, String> get env {
  if (_env is EqualUnmodifiableMapView) return _env;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_env);
}

@override@JsonKey() final  bool isConnected;

/// Create a copy of McpServerConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpServerConfigCopyWith<_McpServerConfig> get copyWith => __$McpServerConfigCopyWithImpl<_McpServerConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McpServerConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpServerConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other._args, _args)&&const DeepCollectionEquality().equals(other._env, _env)&&(identical(other.isConnected, isConnected) || other.isConnected == isConnected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,command,const DeepCollectionEquality().hash(_args),const DeepCollectionEquality().hash(_env),isConnected);

@override
String toString() {
  return 'McpServerConfig(name: $name, command: $command, args: $args, env: $env, isConnected: $isConnected)';
}


}

/// @nodoc
abstract mixin class _$McpServerConfigCopyWith<$Res> implements $McpServerConfigCopyWith<$Res> {
  factory _$McpServerConfigCopyWith(_McpServerConfig value, $Res Function(_McpServerConfig) _then) = __$McpServerConfigCopyWithImpl;
@override @useResult
$Res call({
 String name, String command, List<String> args, Map<String, String> env, bool isConnected
});




}
/// @nodoc
class __$McpServerConfigCopyWithImpl<$Res>
    implements _$McpServerConfigCopyWith<$Res> {
  __$McpServerConfigCopyWithImpl(this._self, this._then);

  final _McpServerConfig _self;
  final $Res Function(_McpServerConfig) _then;

/// Create a copy of McpServerConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? command = null,Object? args = null,Object? env = null,Object? isConnected = null,}) {
  return _then(_McpServerConfig(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,env: null == env ? _self._env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>,isConnected: null == isConnected ? _self.isConnected : isConnected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
