// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'localsend_compat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LsEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LsEvent()';
}


}

/// @nodoc
class $LsEventCopyWith<$Res>  {
$LsEventCopyWith(LsEvent _, $Res Function(LsEvent) __);
}


/// Adds pattern-matching-related methods to [LsEvent].
extension LsEventPatterns on LsEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LsEvent_Started value)?  started,TResult Function( LsEvent_Stopped value)?  stopped,TResult Function( LsEvent_Discovered value)?  discovered,TResult Function( LsEvent_Registered value)?  registered,TResult Function( LsEvent_Incoming value)?  incoming,TResult Function( LsEvent_Received value)?  received,TResult Function( LsEvent_ReceiveFailed value)?  receiveFailed,TResult Function( LsEvent_SessionEnd value)?  sessionEnd,TResult Function( LsEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LsEvent_Started() when started != null:
return started(_that);case LsEvent_Stopped() when stopped != null:
return stopped(_that);case LsEvent_Discovered() when discovered != null:
return discovered(_that);case LsEvent_Registered() when registered != null:
return registered(_that);case LsEvent_Incoming() when incoming != null:
return incoming(_that);case LsEvent_Received() when received != null:
return received(_that);case LsEvent_ReceiveFailed() when receiveFailed != null:
return receiveFailed(_that);case LsEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that);case LsEvent_Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LsEvent_Started value)  started,required TResult Function( LsEvent_Stopped value)  stopped,required TResult Function( LsEvent_Discovered value)  discovered,required TResult Function( LsEvent_Registered value)  registered,required TResult Function( LsEvent_Incoming value)  incoming,required TResult Function( LsEvent_Received value)  received,required TResult Function( LsEvent_ReceiveFailed value)  receiveFailed,required TResult Function( LsEvent_SessionEnd value)  sessionEnd,required TResult Function( LsEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case LsEvent_Started():
return started(_that);case LsEvent_Stopped():
return stopped(_that);case LsEvent_Discovered():
return discovered(_that);case LsEvent_Registered():
return registered(_that);case LsEvent_Incoming():
return incoming(_that);case LsEvent_Received():
return received(_that);case LsEvent_ReceiveFailed():
return receiveFailed(_that);case LsEvent_SessionEnd():
return sessionEnd(_that);case LsEvent_Error():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LsEvent_Started value)?  started,TResult? Function( LsEvent_Stopped value)?  stopped,TResult? Function( LsEvent_Discovered value)?  discovered,TResult? Function( LsEvent_Registered value)?  registered,TResult? Function( LsEvent_Incoming value)?  incoming,TResult? Function( LsEvent_Received value)?  received,TResult? Function( LsEvent_ReceiveFailed value)?  receiveFailed,TResult? Function( LsEvent_SessionEnd value)?  sessionEnd,TResult? Function( LsEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case LsEvent_Started() when started != null:
return started(_that);case LsEvent_Stopped() when stopped != null:
return stopped(_that);case LsEvent_Discovered() when discovered != null:
return discovered(_that);case LsEvent_Registered() when registered != null:
return registered(_that);case LsEvent_Incoming() when incoming != null:
return incoming(_that);case LsEvent_Received() when received != null:
return received(_that);case LsEvent_ReceiveFailed() when receiveFailed != null:
return receiveFailed(_that);case LsEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that);case LsEvent_Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int port,  bool multicastOk,  String? multicastError)?  started,TResult Function()?  stopped,TResult Function( String alias,  String version,  String ip,  int port,  bool https,  String? deviceModel)?  discovered,TResult Function( String alias,  String ip)?  registered,TResult Function( String alias,  String ip,  BigInt files,  BigInt totalBytes)?  incoming,TResult Function( String name,  String path)?  received,TResult Function( String name,  String error)?  receiveFailed,TResult Function( BigInt received,  BigInt failed,  String reason)?  sessionEnd,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LsEvent_Started() when started != null:
return started(_that.port,_that.multicastOk,_that.multicastError);case LsEvent_Stopped() when stopped != null:
return stopped();case LsEvent_Discovered() when discovered != null:
return discovered(_that.alias,_that.version,_that.ip,_that.port,_that.https,_that.deviceModel);case LsEvent_Registered() when registered != null:
return registered(_that.alias,_that.ip);case LsEvent_Incoming() when incoming != null:
return incoming(_that.alias,_that.ip,_that.files,_that.totalBytes);case LsEvent_Received() when received != null:
return received(_that.name,_that.path);case LsEvent_ReceiveFailed() when receiveFailed != null:
return receiveFailed(_that.name,_that.error);case LsEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that.received,_that.failed,_that.reason);case LsEvent_Error() when error != null:
return error(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int port,  bool multicastOk,  String? multicastError)  started,required TResult Function()  stopped,required TResult Function( String alias,  String version,  String ip,  int port,  bool https,  String? deviceModel)  discovered,required TResult Function( String alias,  String ip)  registered,required TResult Function( String alias,  String ip,  BigInt files,  BigInt totalBytes)  incoming,required TResult Function( String name,  String path)  received,required TResult Function( String name,  String error)  receiveFailed,required TResult Function( BigInt received,  BigInt failed,  String reason)  sessionEnd,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case LsEvent_Started():
return started(_that.port,_that.multicastOk,_that.multicastError);case LsEvent_Stopped():
return stopped();case LsEvent_Discovered():
return discovered(_that.alias,_that.version,_that.ip,_that.port,_that.https,_that.deviceModel);case LsEvent_Registered():
return registered(_that.alias,_that.ip);case LsEvent_Incoming():
return incoming(_that.alias,_that.ip,_that.files,_that.totalBytes);case LsEvent_Received():
return received(_that.name,_that.path);case LsEvent_ReceiveFailed():
return receiveFailed(_that.name,_that.error);case LsEvent_SessionEnd():
return sessionEnd(_that.received,_that.failed,_that.reason);case LsEvent_Error():
return error(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int port,  bool multicastOk,  String? multicastError)?  started,TResult? Function()?  stopped,TResult? Function( String alias,  String version,  String ip,  int port,  bool https,  String? deviceModel)?  discovered,TResult? Function( String alias,  String ip)?  registered,TResult? Function( String alias,  String ip,  BigInt files,  BigInt totalBytes)?  incoming,TResult? Function( String name,  String path)?  received,TResult? Function( String name,  String error)?  receiveFailed,TResult? Function( BigInt received,  BigInt failed,  String reason)?  sessionEnd,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case LsEvent_Started() when started != null:
return started(_that.port,_that.multicastOk,_that.multicastError);case LsEvent_Stopped() when stopped != null:
return stopped();case LsEvent_Discovered() when discovered != null:
return discovered(_that.alias,_that.version,_that.ip,_that.port,_that.https,_that.deviceModel);case LsEvent_Registered() when registered != null:
return registered(_that.alias,_that.ip);case LsEvent_Incoming() when incoming != null:
return incoming(_that.alias,_that.ip,_that.files,_that.totalBytes);case LsEvent_Received() when received != null:
return received(_that.name,_that.path);case LsEvent_ReceiveFailed() when receiveFailed != null:
return receiveFailed(_that.name,_that.error);case LsEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that.received,_that.failed,_that.reason);case LsEvent_Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class LsEvent_Started extends LsEvent {
  const LsEvent_Started({required this.port, required this.multicastOk, this.multicastError}): super._();
  

/// 实际监听的 HTTP 端口（可能与配置不同，已被占用而降级）。
 final  int port;
/// 多播 socket 是否绑上。绑不上时只能靠主动探测发现对端。
 final  bool multicastOk;
/// 多播绑不上的原因，直接展示给用户比写进代码注释里更省事。
 final  String? multicastError;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_StartedCopyWith<LsEvent_Started> get copyWith => _$LsEvent_StartedCopyWithImpl<LsEvent_Started>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Started&&(identical(other.port, port) || other.port == port)&&(identical(other.multicastOk, multicastOk) || other.multicastOk == multicastOk)&&(identical(other.multicastError, multicastError) || other.multicastError == multicastError));
}


@override
int get hashCode {
    return Object.hash(runtimeType,port,multicastOk,multicastError);
}

@override
String toString() {
    return 'LsEvent.started(port: $port, multicastOk: $multicastOk, multicastError: $multicastError)';
}


}

/// @nodoc
abstract mixin class $LsEvent_StartedCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_StartedCopyWith(LsEvent_Started value, $Res Function(LsEvent_Started) _then) = _$LsEvent_StartedCopyWithImpl;
@useResult
$Res call({
 int port, bool multicastOk, String? multicastError
});




}
/// @nodoc
class _$LsEvent_StartedCopyWithImpl<$Res>
    implements $LsEvent_StartedCopyWith<$Res> {
  _$LsEvent_StartedCopyWithImpl(this._self, this._then);

  final LsEvent_Started _self;
  final $Res Function(LsEvent_Started) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? port = null,Object? multicastOk = null,Object? multicastError = freezed,}) {
  return _then(LsEvent_Started(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,multicastOk: null == multicastOk ? _self.multicastOk : multicastOk // ignore: cast_nullable_to_non_nullable
as bool,multicastError: freezed == multicastError ? _self.multicastError : multicastError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class LsEvent_Stopped extends LsEvent {
  const LsEvent_Stopped(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Stopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LsEvent.stopped()';
}


}




/// @nodoc


class LsEvent_Discovered extends LsEvent {
  const LsEvent_Discovered({required this.alias, required this.version, required this.ip, required this.port, required this.https, this.deviceModel}): super._();
  

 final  String alias;
 final  String version;
 final  String ip;
 final  int port;
 final  bool https;
 final  String? deviceModel;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_DiscoveredCopyWith<LsEvent_Discovered> get copyWith => _$LsEvent_DiscoveredCopyWithImpl<LsEvent_Discovered>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Discovered&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.version, version) || other.version == version)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.port, port) || other.port == port)&&(identical(other.https, https) || other.https == https)&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel));
}


@override
int get hashCode {
    return Object.hash(runtimeType,alias,version,ip,port,https,deviceModel);
}

@override
String toString() {
    return 'LsEvent.discovered(alias: $alias, version: $version, ip: $ip, port: $port, https: $https, deviceModel: $deviceModel)';
}


}

/// @nodoc
abstract mixin class $LsEvent_DiscoveredCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_DiscoveredCopyWith(LsEvent_Discovered value, $Res Function(LsEvent_Discovered) _then) = _$LsEvent_DiscoveredCopyWithImpl;
@useResult
$Res call({
 String alias, String version, String ip, int port, bool https, String? deviceModel
});




}
/// @nodoc
class _$LsEvent_DiscoveredCopyWithImpl<$Res>
    implements $LsEvent_DiscoveredCopyWith<$Res> {
  _$LsEvent_DiscoveredCopyWithImpl(this._self, this._then);

  final LsEvent_Discovered _self;
  final $Res Function(LsEvent_Discovered) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? alias = null,Object? version = null,Object? ip = null,Object? port = null,Object? https = null,Object? deviceModel = freezed,}) {
  return _then(LsEvent_Discovered(
alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,https: null == https ? _self.https : https // ignore: cast_nullable_to_non_nullable
as bool,deviceModel: freezed == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class LsEvent_Registered extends LsEvent {
  const LsEvent_Registered({required this.alias, required this.ip}): super._();
  

 final  String alias;
 final  String ip;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_RegisteredCopyWith<LsEvent_Registered> get copyWith => _$LsEvent_RegisteredCopyWithImpl<LsEvent_Registered>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Registered&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.ip, ip) || other.ip == ip));
}


@override
int get hashCode {
    return Object.hash(runtimeType,alias,ip);
}

@override
String toString() {
    return 'LsEvent.registered(alias: $alias, ip: $ip)';
}


}

/// @nodoc
abstract mixin class $LsEvent_RegisteredCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_RegisteredCopyWith(LsEvent_Registered value, $Res Function(LsEvent_Registered) _then) = _$LsEvent_RegisteredCopyWithImpl;
@useResult
$Res call({
 String alias, String ip
});




}
/// @nodoc
class _$LsEvent_RegisteredCopyWithImpl<$Res>
    implements $LsEvent_RegisteredCopyWith<$Res> {
  _$LsEvent_RegisteredCopyWithImpl(this._self, this._then);

  final LsEvent_Registered _self;
  final $Res Function(LsEvent_Registered) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? alias = null,Object? ip = null,}) {
  return _then(LsEvent_Registered(
alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LsEvent_Incoming extends LsEvent {
  const LsEvent_Incoming({required this.alias, required this.ip, required this.files, required this.totalBytes}): super._();
  

 final  String alias;
 final  String ip;
 final  BigInt files;
 final  BigInt totalBytes;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_IncomingCopyWith<LsEvent_Incoming> get copyWith => _$LsEvent_IncomingCopyWithImpl<LsEvent_Incoming>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Incoming&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.files, files) || other.files == files)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,alias,ip,files,totalBytes);
}

@override
String toString() {
    return 'LsEvent.incoming(alias: $alias, ip: $ip, files: $files, totalBytes: $totalBytes)';
}


}

/// @nodoc
abstract mixin class $LsEvent_IncomingCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_IncomingCopyWith(LsEvent_Incoming value, $Res Function(LsEvent_Incoming) _then) = _$LsEvent_IncomingCopyWithImpl;
@useResult
$Res call({
 String alias, String ip, BigInt files, BigInt totalBytes
});




}
/// @nodoc
class _$LsEvent_IncomingCopyWithImpl<$Res>
    implements $LsEvent_IncomingCopyWith<$Res> {
  _$LsEvent_IncomingCopyWithImpl(this._self, this._then);

  final LsEvent_Incoming _self;
  final $Res Function(LsEvent_Incoming) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? alias = null,Object? ip = null,Object? files = null,Object? totalBytes = null,}) {
  return _then(LsEvent_Incoming(
alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as BigInt,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class LsEvent_Received extends LsEvent {
  const LsEvent_Received({required this.name, required this.path}): super._();
  

 final  String name;
 final  String path;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_ReceivedCopyWith<LsEvent_Received> get copyWith => _$LsEvent_ReceivedCopyWithImpl<LsEvent_Received>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Received&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,path);
}

@override
String toString() {
    return 'LsEvent.received(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class $LsEvent_ReceivedCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_ReceivedCopyWith(LsEvent_Received value, $Res Function(LsEvent_Received) _then) = _$LsEvent_ReceivedCopyWithImpl;
@useResult
$Res call({
 String name, String path
});




}
/// @nodoc
class _$LsEvent_ReceivedCopyWithImpl<$Res>
    implements $LsEvent_ReceivedCopyWith<$Res> {
  _$LsEvent_ReceivedCopyWithImpl(this._self, this._then);

  final LsEvent_Received _self;
  final $Res Function(LsEvent_Received) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,}) {
  return _then(LsEvent_Received(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LsEvent_ReceiveFailed extends LsEvent {
  const LsEvent_ReceiveFailed({required this.name, required this.error}): super._();
  

 final  String name;
 final  String error;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_ReceiveFailedCopyWith<LsEvent_ReceiveFailed> get copyWith => _$LsEvent_ReceiveFailedCopyWithImpl<LsEvent_ReceiveFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_ReceiveFailed&&(identical(other.name, name) || other.name == name)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,error);
}

@override
String toString() {
    return 'LsEvent.receiveFailed(name: $name, error: $error)';
}


}

/// @nodoc
abstract mixin class $LsEvent_ReceiveFailedCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_ReceiveFailedCopyWith(LsEvent_ReceiveFailed value, $Res Function(LsEvent_ReceiveFailed) _then) = _$LsEvent_ReceiveFailedCopyWithImpl;
@useResult
$Res call({
 String name, String error
});




}
/// @nodoc
class _$LsEvent_ReceiveFailedCopyWithImpl<$Res>
    implements $LsEvent_ReceiveFailedCopyWith<$Res> {
  _$LsEvent_ReceiveFailedCopyWithImpl(this._self, this._then);

  final LsEvent_ReceiveFailed _self;
  final $Res Function(LsEvent_ReceiveFailed) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? error = null,}) {
  return _then(LsEvent_ReceiveFailed(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LsEvent_SessionEnd extends LsEvent {
  const LsEvent_SessionEnd({required this.received, required this.failed, required this.reason}): super._();
  

 final  BigInt received;
 final  BigInt failed;
 final  String reason;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_SessionEndCopyWith<LsEvent_SessionEnd> get copyWith => _$LsEvent_SessionEndCopyWithImpl<LsEvent_SessionEnd>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_SessionEnd&&(identical(other.received, received) || other.received == received)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,received,failed,reason);
}

@override
String toString() {
    return 'LsEvent.sessionEnd(received: $received, failed: $failed, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $LsEvent_SessionEndCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_SessionEndCopyWith(LsEvent_SessionEnd value, $Res Function(LsEvent_SessionEnd) _then) = _$LsEvent_SessionEndCopyWithImpl;
@useResult
$Res call({
 BigInt received, BigInt failed, String reason
});




}
/// @nodoc
class _$LsEvent_SessionEndCopyWithImpl<$Res>
    implements $LsEvent_SessionEndCopyWith<$Res> {
  _$LsEvent_SessionEndCopyWithImpl(this._self, this._then);

  final LsEvent_SessionEnd _self;
  final $Res Function(LsEvent_SessionEnd) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? received = null,Object? failed = null,Object? reason = null,}) {
  return _then(LsEvent_SessionEnd(
received: null == received ? _self.received : received // ignore: cast_nullable_to_non_nullable
as BigInt,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as BigInt,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LsEvent_Error extends LsEvent {
  const LsEvent_Error({required this.message}): super._();
  

 final  String message;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LsEvent_ErrorCopyWith<LsEvent_Error> get copyWith => _$LsEvent_ErrorCopyWithImpl<LsEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LsEvent_Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'LsEvent.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $LsEvent_ErrorCopyWith<$Res> implements $LsEventCopyWith<$Res> {
  factory $LsEvent_ErrorCopyWith(LsEvent_Error value, $Res Function(LsEvent_Error) _then) = _$LsEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$LsEvent_ErrorCopyWithImpl<$Res>
    implements $LsEvent_ErrorCopyWith<$Res> {
  _$LsEvent_ErrorCopyWithImpl(this._self, this._then);

  final LsEvent_Error _self;
  final $Res Function(LsEvent_Error) _then;

/// Create a copy of LsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(LsEvent_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
