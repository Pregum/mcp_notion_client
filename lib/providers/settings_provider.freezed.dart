// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsState {

 String? get geminiApiKey; List<McpServerConfig> get mcpServers;
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsStateCopyWith<SettingsState> get copyWith => _$SettingsStateCopyWithImpl<SettingsState>(this as SettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsState&&(identical(other.geminiApiKey, geminiApiKey) || other.geminiApiKey == geminiApiKey)&&const DeepCollectionEquality().equals(other.mcpServers, mcpServers));
}


@override
int get hashCode => Object.hash(runtimeType,geminiApiKey,const DeepCollectionEquality().hash(mcpServers));

@override
String toString() {
  return 'SettingsState(geminiApiKey: $geminiApiKey, mcpServers: $mcpServers)';
}


}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res>  {
  factory $SettingsStateCopyWith(SettingsState value, $Res Function(SettingsState) _then) = _$SettingsStateCopyWithImpl;
@useResult
$Res call({
 String? geminiApiKey, List<McpServerConfig> mcpServers
});




}
/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? geminiApiKey = freezed,Object? mcpServers = null,}) {
  return _then(_self.copyWith(
geminiApiKey: freezed == geminiApiKey ? _self.geminiApiKey : geminiApiKey // ignore: cast_nullable_to_non_nullable
as String?,mcpServers: null == mcpServers ? _self.mcpServers : mcpServers // ignore: cast_nullable_to_non_nullable
as List<McpServerConfig>,
  ));
}

}


/// @nodoc


class _SettingsState extends SettingsState {
   _SettingsState({this.geminiApiKey, final  List<McpServerConfig> mcpServers = const []}): _mcpServers = mcpServers,super._();
  

@override final  String? geminiApiKey;
 final  List<McpServerConfig> _mcpServers;
@override@JsonKey() List<McpServerConfig> get mcpServers {
  if (_mcpServers is EqualUnmodifiableListView) return _mcpServers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mcpServers);
}


/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsStateCopyWith<_SettingsState> get copyWith => __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsState&&(identical(other.geminiApiKey, geminiApiKey) || other.geminiApiKey == geminiApiKey)&&const DeepCollectionEquality().equals(other._mcpServers, _mcpServers));
}


@override
int get hashCode => Object.hash(runtimeType,geminiApiKey,const DeepCollectionEquality().hash(_mcpServers));

@override
String toString() {
  return 'SettingsState(geminiApiKey: $geminiApiKey, mcpServers: $mcpServers)';
}


}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res> implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(_SettingsState value, $Res Function(_SettingsState) _then) = __$SettingsStateCopyWithImpl;
@override @useResult
$Res call({
 String? geminiApiKey, List<McpServerConfig> mcpServers
});




}
/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? geminiApiKey = freezed,Object? mcpServers = null,}) {
  return _then(_SettingsState(
geminiApiKey: freezed == geminiApiKey ? _self.geminiApiKey : geminiApiKey // ignore: cast_nullable_to_non_nullable
as String?,mcpServers: null == mcpServers ? _self._mcpServers : mcpServers // ignore: cast_nullable_to_non_nullable
as List<McpServerConfig>,
  ));
}


}

// dart format on
