// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'processed_audio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProcessedAudio {

 String get title; String get markdown; String get transcription; String get subTitle;
/// Create a copy of ProcessedAudio
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProcessedAudioCopyWith<ProcessedAudio> get copyWith => _$ProcessedAudioCopyWithImpl<ProcessedAudio>(this as ProcessedAudio, _$identity);

  /// Serializes this ProcessedAudio to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProcessedAudio&&(identical(other.title, title) || other.title == title)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.subTitle, subTitle) || other.subTitle == subTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,markdown,transcription,subTitle);

@override
String toString() {
  return 'ProcessedAudio(title: $title, markdown: $markdown, transcription: $transcription, subTitle: $subTitle)';
}


}

/// @nodoc
abstract mixin class $ProcessedAudioCopyWith<$Res>  {
  factory $ProcessedAudioCopyWith(ProcessedAudio value, $Res Function(ProcessedAudio) _then) = _$ProcessedAudioCopyWithImpl;
@useResult
$Res call({
 String title, String markdown, String transcription, String subTitle
});




}
/// @nodoc
class _$ProcessedAudioCopyWithImpl<$Res>
    implements $ProcessedAudioCopyWith<$Res> {
  _$ProcessedAudioCopyWithImpl(this._self, this._then);

  final ProcessedAudio _self;
  final $Res Function(ProcessedAudio) _then;

/// Create a copy of ProcessedAudio
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? markdown = null,Object? transcription = null,Object? subTitle = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,transcription: null == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String,subTitle: null == subTitle ? _self.subTitle : subTitle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProcessedAudio].
extension ProcessedAudioPatterns on ProcessedAudio {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String markdown,  String transcription,  String subTitle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProcessedAudio() when $default != null:
return $default(_that.title,_that.markdown,_that.transcription,_that.subTitle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String markdown,  String transcription,  String subTitle)  $default,) {final _that = this;
switch (_that) {
case _ProcessedAudio():
return $default(_that.title,_that.markdown,_that.transcription,_that.subTitle);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String markdown,  String transcription,  String subTitle)?  $default,) {final _that = this;
switch (_that) {
case _ProcessedAudio() when $default != null:
return $default(_that.title,_that.markdown,_that.transcription,_that.subTitle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProcessedAudio implements ProcessedAudio {
  const _ProcessedAudio({required this.title, required this.markdown, required this.transcription, required this.subTitle});
  factory _ProcessedAudio.fromJson(Map<String, dynamic> json) => _$ProcessedAudioFromJson(json);

@override final  String title;
@override final  String markdown;
@override final  String transcription;
@override final  String subTitle;

/// Create a copy of ProcessedAudio
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProcessedAudioCopyWith<_ProcessedAudio> get copyWith => __$ProcessedAudioCopyWithImpl<_ProcessedAudio>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProcessedAudioToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProcessedAudio&&(identical(other.title, title) || other.title == title)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.subTitle, subTitle) || other.subTitle == subTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,markdown,transcription,subTitle);

@override
String toString() {
  return 'ProcessedAudio(title: $title, markdown: $markdown, transcription: $transcription, subTitle: $subTitle)';
}


}

/// @nodoc
abstract mixin class _$ProcessedAudioCopyWith<$Res> implements $ProcessedAudioCopyWith<$Res> {
  factory _$ProcessedAudioCopyWith(_ProcessedAudio value, $Res Function(_ProcessedAudio) _then) = __$ProcessedAudioCopyWithImpl;
@override @useResult
$Res call({
 String title, String markdown, String transcription, String subTitle
});




}
/// @nodoc
class __$ProcessedAudioCopyWithImpl<$Res>
    implements _$ProcessedAudioCopyWith<$Res> {
  __$ProcessedAudioCopyWithImpl(this._self, this._then);

  final _ProcessedAudio _self;
  final $Res Function(_ProcessedAudio) _then;

/// Create a copy of ProcessedAudio
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? markdown = null,Object? transcription = null,Object? subTitle = null,}) {
  return _then(_ProcessedAudio(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,transcription: null == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String,subTitle: null == subTitle ? _self.subTitle : subTitle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
