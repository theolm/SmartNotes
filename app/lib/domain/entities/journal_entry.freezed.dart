// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JournalEntry {

 String get id; DateTime get createdAt; DateTime get updatedAt; EntryStatus get status; String? get audioPath; String? get transcription; String? get formattedNote; String? get title; String? get languageCode; String? get subTitle; DateTime? get entryDate;
/// Create a copy of JournalEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JournalEntryCopyWith<JournalEntry> get copyWith => _$JournalEntryCopyWithImpl<JournalEntry>(this as JournalEntry, _$identity);

  /// Serializes this JournalEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.formattedNote, formattedNote) || other.formattedNote == formattedNote)&&(identical(other.title, title) || other.title == title)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.subTitle, subTitle) || other.subTitle == subTitle)&&(identical(other.entryDate, entryDate) || other.entryDate == entryDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,updatedAt,status,audioPath,transcription,formattedNote,title,languageCode,subTitle,entryDate);

@override
String toString() {
  return 'JournalEntry(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, status: $status, audioPath: $audioPath, transcription: $transcription, formattedNote: $formattedNote, title: $title, languageCode: $languageCode, subTitle: $subTitle, entryDate: $entryDate)';
}


}

/// @nodoc
abstract mixin class $JournalEntryCopyWith<$Res>  {
  factory $JournalEntryCopyWith(JournalEntry value, $Res Function(JournalEntry) _then) = _$JournalEntryCopyWithImpl;
@useResult
$Res call({
 String id, DateTime createdAt, DateTime updatedAt, EntryStatus status, String? audioPath, String? transcription, String? formattedNote, String? title, String? languageCode, String? subTitle, DateTime? entryDate
});




}
/// @nodoc
class _$JournalEntryCopyWithImpl<$Res>
    implements $JournalEntryCopyWith<$Res> {
  _$JournalEntryCopyWithImpl(this._self, this._then);

  final JournalEntry _self;
  final $Res Function(JournalEntry) _then;

/// Create a copy of JournalEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? updatedAt = null,Object? status = null,Object? audioPath = freezed,Object? transcription = freezed,Object? formattedNote = freezed,Object? title = freezed,Object? languageCode = freezed,Object? subTitle = freezed,Object? entryDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntryStatus,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,transcription: freezed == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String?,formattedNote: freezed == formattedNote ? _self.formattedNote : formattedNote // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,languageCode: freezed == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String?,subTitle: freezed == subTitle ? _self.subTitle : subTitle // ignore: cast_nullable_to_non_nullable
as String?,entryDate: freezed == entryDate ? _self.entryDate : entryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [JournalEntry].
extension JournalEntryPatterns on JournalEntry {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  DateTime updatedAt,  EntryStatus status,  String? audioPath,  String? transcription,  String? formattedNote,  String? title,  String? languageCode,  String? subTitle,  DateTime? entryDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalEntry() when $default != null:
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.status,_that.audioPath,_that.transcription,_that.formattedNote,_that.title,_that.languageCode,_that.subTitle,_that.entryDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  DateTime updatedAt,  EntryStatus status,  String? audioPath,  String? transcription,  String? formattedNote,  String? title,  String? languageCode,  String? subTitle,  DateTime? entryDate)  $default,) {final _that = this;
switch (_that) {
case _JournalEntry():
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.status,_that.audioPath,_that.transcription,_that.formattedNote,_that.title,_that.languageCode,_that.subTitle,_that.entryDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime createdAt,  DateTime updatedAt,  EntryStatus status,  String? audioPath,  String? transcription,  String? formattedNote,  String? title,  String? languageCode,  String? subTitle,  DateTime? entryDate)?  $default,) {final _that = this;
switch (_that) {
case _JournalEntry() when $default != null:
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.status,_that.audioPath,_that.transcription,_that.formattedNote,_that.title,_that.languageCode,_that.subTitle,_that.entryDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JournalEntry extends JournalEntry {
  const _JournalEntry({required this.id, required this.createdAt, required this.updatedAt, required this.status, this.audioPath, this.transcription, this.formattedNote, this.title, this.languageCode, this.subTitle, this.entryDate}): super._();
  factory _JournalEntry.fromJson(Map<String, dynamic> json) => _$JournalEntryFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  EntryStatus status;
@override final  String? audioPath;
@override final  String? transcription;
@override final  String? formattedNote;
@override final  String? title;
@override final  String? languageCode;
@override final  String? subTitle;
@override final  DateTime? entryDate;

/// Create a copy of JournalEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JournalEntryCopyWith<_JournalEntry> get copyWith => __$JournalEntryCopyWithImpl<_JournalEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JournalEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.formattedNote, formattedNote) || other.formattedNote == formattedNote)&&(identical(other.title, title) || other.title == title)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.subTitle, subTitle) || other.subTitle == subTitle)&&(identical(other.entryDate, entryDate) || other.entryDate == entryDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,updatedAt,status,audioPath,transcription,formattedNote,title,languageCode,subTitle,entryDate);

@override
String toString() {
  return 'JournalEntry(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, status: $status, audioPath: $audioPath, transcription: $transcription, formattedNote: $formattedNote, title: $title, languageCode: $languageCode, subTitle: $subTitle, entryDate: $entryDate)';
}


}

/// @nodoc
abstract mixin class _$JournalEntryCopyWith<$Res> implements $JournalEntryCopyWith<$Res> {
  factory _$JournalEntryCopyWith(_JournalEntry value, $Res Function(_JournalEntry) _then) = __$JournalEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, DateTime updatedAt, EntryStatus status, String? audioPath, String? transcription, String? formattedNote, String? title, String? languageCode, String? subTitle, DateTime? entryDate
});




}
/// @nodoc
class __$JournalEntryCopyWithImpl<$Res>
    implements _$JournalEntryCopyWith<$Res> {
  __$JournalEntryCopyWithImpl(this._self, this._then);

  final _JournalEntry _self;
  final $Res Function(_JournalEntry) _then;

/// Create a copy of JournalEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? updatedAt = null,Object? status = null,Object? audioPath = freezed,Object? transcription = freezed,Object? formattedNote = freezed,Object? title = freezed,Object? languageCode = freezed,Object? subTitle = freezed,Object? entryDate = freezed,}) {
  return _then(_JournalEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntryStatus,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,transcription: freezed == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String?,formattedNote: freezed == formattedNote ? _self.formattedNote : formattedNote // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,languageCode: freezed == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String?,subTitle: freezed == subTitle ? _self.subTitle : subTitle // ignore: cast_nullable_to_non_nullable
as String?,entryDate: freezed == entryDate ? _self.entryDate : entryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
