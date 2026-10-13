// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transfer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransferEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TransferEvent()';
}


}

/// @nodoc
class $TransferEventCopyWith<$Res>  {
$TransferEventCopyWith(TransferEvent _, $Res Function(TransferEvent) __);
}


/// Adds pattern-matching-related methods to [TransferEvent].
extension TransferEventPatterns on TransferEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransferEvent_TextReceived value)?  textReceived,TResult Function( TransferEvent_FileReceived value)?  fileReceived,TResult Function( TransferEvent_PeerRegistered value)?  peerRegistered,TResult Function( TransferEvent_ServerStarted value)?  serverStarted,TResult Function( TransferEvent_ServerStopped value)?  serverStopped,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransferEvent_TextReceived() when textReceived != null:
return textReceived(_that);case TransferEvent_FileReceived() when fileReceived != null:
return fileReceived(_that);case TransferEvent_PeerRegistered() when peerRegistered != null:
return peerRegistered(_that);case TransferEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that);case TransferEvent_ServerStopped() when serverStopped != null:
return serverStopped(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransferEvent_TextReceived value)  textReceived,required TResult Function( TransferEvent_FileReceived value)  fileReceived,required TResult Function( TransferEvent_PeerRegistered value)  peerRegistered,required TResult Function( TransferEvent_ServerStarted value)  serverStarted,required TResult Function( TransferEvent_ServerStopped value)  serverStopped,}){
final _that = this;
switch (_that) {
case TransferEvent_TextReceived():
return textReceived(_that);case TransferEvent_FileReceived():
return fileReceived(_that);case TransferEvent_PeerRegistered():
return peerRegistered(_that);case TransferEvent_ServerStarted():
return serverStarted(_that);case TransferEvent_ServerStopped():
return serverStopped(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransferEvent_TextReceived value)?  textReceived,TResult? Function( TransferEvent_FileReceived value)?  fileReceived,TResult? Function( TransferEvent_PeerRegistered value)?  peerRegistered,TResult? Function( TransferEvent_ServerStarted value)?  serverStarted,TResult? Function( TransferEvent_ServerStopped value)?  serverStopped,}){
final _that = this;
switch (_that) {
case TransferEvent_TextReceived() when textReceived != null:
return textReceived(_that);case TransferEvent_FileReceived() when fileReceived != null:
return fileReceived(_that);case TransferEvent_PeerRegistered() when peerRegistered != null:
return peerRegistered(_that);case TransferEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that);case TransferEvent_ServerStopped() when serverStopped != null:
return serverStopped(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String from,  String kind,  String text)?  textReceived,TResult Function( String from,  String name,  String path,  BigInt size)?  fileReceived,TResult Function( ConnectInfo info)?  peerRegistered,TResult Function( int port)?  serverStarted,TResult Function()?  serverStopped,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransferEvent_TextReceived() when textReceived != null:
return textReceived(_that.from,_that.kind,_that.text);case TransferEvent_FileReceived() when fileReceived != null:
return fileReceived(_that.from,_that.name,_that.path,_that.size);case TransferEvent_PeerRegistered() when peerRegistered != null:
return peerRegistered(_that.info);case TransferEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that.port);case TransferEvent_ServerStopped() when serverStopped != null:
return serverStopped();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String from,  String kind,  String text)  textReceived,required TResult Function( String from,  String name,  String path,  BigInt size)  fileReceived,required TResult Function( ConnectInfo info)  peerRegistered,required TResult Function( int port)  serverStarted,required TResult Function()  serverStopped,}) {final _that = this;
switch (_that) {
case TransferEvent_TextReceived():
return textReceived(_that.from,_that.kind,_that.text);case TransferEvent_FileReceived():
return fileReceived(_that.from,_that.name,_that.path,_that.size);case TransferEvent_PeerRegistered():
return peerRegistered(_that.info);case TransferEvent_ServerStarted():
return serverStarted(_that.port);case TransferEvent_ServerStopped():
return serverStopped();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String from,  String kind,  String text)?  textReceived,TResult? Function( String from,  String name,  String path,  BigInt size)?  fileReceived,TResult? Function( ConnectInfo info)?  peerRegistered,TResult? Function( int port)?  serverStarted,TResult? Function()?  serverStopped,}) {final _that = this;
switch (_that) {
case TransferEvent_TextReceived() when textReceived != null:
return textReceived(_that.from,_that.kind,_that.text);case TransferEvent_FileReceived() when fileReceived != null:
return fileReceived(_that.from,_that.name,_that.path,_that.size);case TransferEvent_PeerRegistered() when peerRegistered != null:
return peerRegistered(_that.info);case TransferEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that.port);case TransferEvent_ServerStopped() when serverStopped != null:
return serverStopped();case _:
  return null;

}
}

}

/// @nodoc


class TransferEvent_TextReceived extends TransferEvent {
  const TransferEvent_TextReceived({required this.from, required this.kind, required this.text}): super._();
  

 final  String from;
 final  String kind;
 final  String text;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferEvent_TextReceivedCopyWith<TransferEvent_TextReceived> get copyWith => _$TransferEvent_TextReceivedCopyWithImpl<TransferEvent_TextReceived>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferEvent_TextReceived&&(identical(other.from, from) || other.from == from)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,from,kind,text);
}

@override
String toString() {
    return 'TransferEvent.textReceived(from: $from, kind: $kind, text: $text)';
}


}

/// @nodoc
abstract mixin class $TransferEvent_TextReceivedCopyWith<$Res> implements $TransferEventCopyWith<$Res> {
  factory $TransferEvent_TextReceivedCopyWith(TransferEvent_TextReceived value, $Res Function(TransferEvent_TextReceived) _then) = _$TransferEvent_TextReceivedCopyWithImpl;
@useResult
$Res call({
 String from, String kind, String text
});




}
/// @nodoc
class _$TransferEvent_TextReceivedCopyWithImpl<$Res>
    implements $TransferEvent_TextReceivedCopyWith<$Res> {
  _$TransferEvent_TextReceivedCopyWithImpl(this._self, this._then);

  final TransferEvent_TextReceived _self;
  final $Res Function(TransferEvent_TextReceived) _then;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? from = null,Object? kind = null,Object? text = null,}) {
  return _then(TransferEvent_TextReceived(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TransferEvent_FileReceived extends TransferEvent {
  const TransferEvent_FileReceived({required this.from, required this.name, required this.path, required this.size}): super._();
  

 final  String from;
 final  String name;
 final  String path;
 final  BigInt size;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferEvent_FileReceivedCopyWith<TransferEvent_FileReceived> get copyWith => _$TransferEvent_FileReceivedCopyWithImpl<TransferEvent_FileReceived>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferEvent_FileReceived&&(identical(other.from, from) || other.from == from)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.size, size) || other.size == size));
}


@override
int get hashCode {
    return Object.hash(runtimeType,from,name,path,size);
}

@override
String toString() {
    return 'TransferEvent.fileReceived(from: $from, name: $name, path: $path, size: $size)';
}


}

/// @nodoc
abstract mixin class $TransferEvent_FileReceivedCopyWith<$Res> implements $TransferEventCopyWith<$Res> {
  factory $TransferEvent_FileReceivedCopyWith(TransferEvent_FileReceived value, $Res Function(TransferEvent_FileReceived) _then) = _$TransferEvent_FileReceivedCopyWithImpl;
@useResult
$Res call({
 String from, String name, String path, BigInt size
});




}
/// @nodoc
class _$TransferEvent_FileReceivedCopyWithImpl<$Res>
    implements $TransferEvent_FileReceivedCopyWith<$Res> {
  _$TransferEvent_FileReceivedCopyWithImpl(this._self, this._then);

  final TransferEvent_FileReceived _self;
  final $Res Function(TransferEvent_FileReceived) _then;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? from = null,Object? name = null,Object? path = null,Object? size = null,}) {
  return _then(TransferEvent_FileReceived(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class TransferEvent_PeerRegistered extends TransferEvent {
  const TransferEvent_PeerRegistered({required this.info}): super._();
  

 final  ConnectInfo info;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferEvent_PeerRegisteredCopyWith<TransferEvent_PeerRegistered> get copyWith => _$TransferEvent_PeerRegisteredCopyWithImpl<TransferEvent_PeerRegistered>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferEvent_PeerRegistered&&(identical(other.info, info) || other.info == info));
}


@override
int get hashCode {
    return Object.hash(runtimeType,info);
}

@override
String toString() {
    return 'TransferEvent.peerRegistered(info: $info)';
}


}

/// @nodoc
abstract mixin class $TransferEvent_PeerRegisteredCopyWith<$Res> implements $TransferEventCopyWith<$Res> {
  factory $TransferEvent_PeerRegisteredCopyWith(TransferEvent_PeerRegistered value, $Res Function(TransferEvent_PeerRegistered) _then) = _$TransferEvent_PeerRegisteredCopyWithImpl;
@useResult
$Res call({
 ConnectInfo info
});




}
/// @nodoc
class _$TransferEvent_PeerRegisteredCopyWithImpl<$Res>
    implements $TransferEvent_PeerRegisteredCopyWith<$Res> {
  _$TransferEvent_PeerRegisteredCopyWithImpl(this._self, this._then);

  final TransferEvent_PeerRegistered _self;
  final $Res Function(TransferEvent_PeerRegistered) _then;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(TransferEvent_PeerRegistered(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as ConnectInfo,
  ));
}


}

/// @nodoc


class TransferEvent_ServerStarted extends TransferEvent {
  const TransferEvent_ServerStarted({required this.port}): super._();
  

 final  int port;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferEvent_ServerStartedCopyWith<TransferEvent_ServerStarted> get copyWith => _$TransferEvent_ServerStartedCopyWithImpl<TransferEvent_ServerStarted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferEvent_ServerStarted&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode {
    return Object.hash(runtimeType,port);
}

@override
String toString() {
    return 'TransferEvent.serverStarted(port: $port)';
}


}

/// @nodoc
abstract mixin class $TransferEvent_ServerStartedCopyWith<$Res> implements $TransferEventCopyWith<$Res> {
  factory $TransferEvent_ServerStartedCopyWith(TransferEvent_ServerStarted value, $Res Function(TransferEvent_ServerStarted) _then) = _$TransferEvent_ServerStartedCopyWithImpl;
@useResult
$Res call({
 int port
});




}
/// @nodoc
class _$TransferEvent_ServerStartedCopyWithImpl<$Res>
    implements $TransferEvent_ServerStartedCopyWith<$Res> {
  _$TransferEvent_ServerStartedCopyWithImpl(this._self, this._then);

  final TransferEvent_ServerStarted _self;
  final $Res Function(TransferEvent_ServerStarted) _then;

/// Create a copy of TransferEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? port = null,}) {
  return _then(TransferEvent_ServerStarted(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class TransferEvent_ServerStopped extends TransferEvent {
  const TransferEvent_ServerStopped(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferEvent_ServerStopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TransferEvent.serverStopped()';
}


}




// dart format on
