// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'financial_attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FinancialAttachment {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId;@JsonKey(name: 'uploaded_by') String get uploadedBy;@JsonKey(name: 'bucket_id') String get bucketId;@JsonKey(name: 'object_path') String get objectPath;@JsonKey(name: 'mime_type') String get mimeType;@JsonKey(name: 'file_size_bytes') int? get fileSizeBytes; AttachmentStatus get status;@JsonKey(name: 'processing_started_at') DateTime? get processingStartedAt;@JsonKey(name: 'processing_completed_at') DateTime? get processingCompletedAt;@JsonKey(name: 'error_message') String? get errorMessage;@JsonKey(name: 'extracted_json') Map<String, dynamic>? get extractedJson;@JsonKey(name: 'suggested_transaction_json') Map<String, dynamic>? get suggestedTransactionJson;@JsonKey(name: 'confidence_score') double? get confidenceScore;@JsonKey(name: 'dedup_key') String? get dedupKey;@JsonKey(name: 'matched_lancamento_id') String? get matchedLancamentoId;@JsonKey(name: 'linked_lancamento_id') String? get linkedLancamentoId;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;@JsonKey(name: 'deleted_at') DateTime? get deletedAt;
/// Create a copy of FinancialAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FinancialAttachmentCopyWith<FinancialAttachment> get copyWith => _$FinancialAttachmentCopyWithImpl<FinancialAttachment>(this as FinancialAttachment, _$identity);

  /// Serializes this FinancialAttachment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FinancialAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.bucketId, bucketId) || other.bucketId == bucketId)&&(identical(other.objectPath, objectPath) || other.objectPath == objectPath)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.status, status) || other.status == status)&&(identical(other.processingStartedAt, processingStartedAt) || other.processingStartedAt == processingStartedAt)&&(identical(other.processingCompletedAt, processingCompletedAt) || other.processingCompletedAt == processingCompletedAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&const DeepCollectionEquality().equals(other.extractedJson, extractedJson)&&const DeepCollectionEquality().equals(other.suggestedTransactionJson, suggestedTransactionJson)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.dedupKey, dedupKey) || other.dedupKey == dedupKey)&&(identical(other.matchedLancamentoId, matchedLancamentoId) || other.matchedLancamentoId == matchedLancamentoId)&&(identical(other.linkedLancamentoId, linkedLancamentoId) || other.linkedLancamentoId == linkedLancamentoId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,uploadedBy,bucketId,objectPath,mimeType,fileSizeBytes,status,processingStartedAt,processingCompletedAt,errorMessage,const DeepCollectionEquality().hash(extractedJson),const DeepCollectionEquality().hash(suggestedTransactionJson),confidenceScore,dedupKey,matchedLancamentoId,linkedLancamentoId,createdAt,updatedAt,deletedAt]);

@override
String toString() {
  return 'FinancialAttachment(id: $id, tenantId: $tenantId, uploadedBy: $uploadedBy, bucketId: $bucketId, objectPath: $objectPath, mimeType: $mimeType, fileSizeBytes: $fileSizeBytes, status: $status, processingStartedAt: $processingStartedAt, processingCompletedAt: $processingCompletedAt, errorMessage: $errorMessage, extractedJson: $extractedJson, suggestedTransactionJson: $suggestedTransactionJson, confidenceScore: $confidenceScore, dedupKey: $dedupKey, matchedLancamentoId: $matchedLancamentoId, linkedLancamentoId: $linkedLancamentoId, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $FinancialAttachmentCopyWith<$Res>  {
  factory $FinancialAttachmentCopyWith(FinancialAttachment value, $Res Function(FinancialAttachment) _then) = _$FinancialAttachmentCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'uploaded_by') String uploadedBy,@JsonKey(name: 'bucket_id') String bucketId,@JsonKey(name: 'object_path') String objectPath,@JsonKey(name: 'mime_type') String mimeType,@JsonKey(name: 'file_size_bytes') int? fileSizeBytes, AttachmentStatus status,@JsonKey(name: 'processing_started_at') DateTime? processingStartedAt,@JsonKey(name: 'processing_completed_at') DateTime? processingCompletedAt,@JsonKey(name: 'error_message') String? errorMessage,@JsonKey(name: 'extracted_json') Map<String, dynamic>? extractedJson,@JsonKey(name: 'suggested_transaction_json') Map<String, dynamic>? suggestedTransactionJson,@JsonKey(name: 'confidence_score') double? confidenceScore,@JsonKey(name: 'dedup_key') String? dedupKey,@JsonKey(name: 'matched_lancamento_id') String? matchedLancamentoId,@JsonKey(name: 'linked_lancamento_id') String? linkedLancamentoId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'deleted_at') DateTime? deletedAt
});




}
/// @nodoc
class _$FinancialAttachmentCopyWithImpl<$Res>
    implements $FinancialAttachmentCopyWith<$Res> {
  _$FinancialAttachmentCopyWithImpl(this._self, this._then);

  final FinancialAttachment _self;
  final $Res Function(FinancialAttachment) _then;

/// Create a copy of FinancialAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? uploadedBy = null,Object? bucketId = null,Object? objectPath = null,Object? mimeType = null,Object? fileSizeBytes = freezed,Object? status = null,Object? processingStartedAt = freezed,Object? processingCompletedAt = freezed,Object? errorMessage = freezed,Object? extractedJson = freezed,Object? suggestedTransactionJson = freezed,Object? confidenceScore = freezed,Object? dedupKey = freezed,Object? matchedLancamentoId = freezed,Object? linkedLancamentoId = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,bucketId: null == bucketId ? _self.bucketId : bucketId // ignore: cast_nullable_to_non_nullable
as String,objectPath: null == objectPath ? _self.objectPath : objectPath // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AttachmentStatus,processingStartedAt: freezed == processingStartedAt ? _self.processingStartedAt : processingStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,processingCompletedAt: freezed == processingCompletedAt ? _self.processingCompletedAt : processingCompletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,extractedJson: freezed == extractedJson ? _self.extractedJson : extractedJson // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,suggestedTransactionJson: freezed == suggestedTransactionJson ? _self.suggestedTransactionJson : suggestedTransactionJson // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,confidenceScore: freezed == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as double?,dedupKey: freezed == dedupKey ? _self.dedupKey : dedupKey // ignore: cast_nullable_to_non_nullable
as String?,matchedLancamentoId: freezed == matchedLancamentoId ? _self.matchedLancamentoId : matchedLancamentoId // ignore: cast_nullable_to_non_nullable
as String?,linkedLancamentoId: freezed == linkedLancamentoId ? _self.linkedLancamentoId : linkedLancamentoId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FinancialAttachment].
extension FinancialAttachmentPatterns on FinancialAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FinancialAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FinancialAttachment() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FinancialAttachment value)  $default,){
final _that = this;
switch (_that) {
case _FinancialAttachment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FinancialAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _FinancialAttachment() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'uploaded_by')  String uploadedBy, @JsonKey(name: 'bucket_id')  String bucketId, @JsonKey(name: 'object_path')  String objectPath, @JsonKey(name: 'mime_type')  String mimeType, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes,  AttachmentStatus status, @JsonKey(name: 'processing_started_at')  DateTime? processingStartedAt, @JsonKey(name: 'processing_completed_at')  DateTime? processingCompletedAt, @JsonKey(name: 'error_message')  String? errorMessage, @JsonKey(name: 'extracted_json')  Map<String, dynamic>? extractedJson, @JsonKey(name: 'suggested_transaction_json')  Map<String, dynamic>? suggestedTransactionJson, @JsonKey(name: 'confidence_score')  double? confidenceScore, @JsonKey(name: 'dedup_key')  String? dedupKey, @JsonKey(name: 'matched_lancamento_id')  String? matchedLancamentoId, @JsonKey(name: 'linked_lancamento_id')  String? linkedLancamentoId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FinancialAttachment() when $default != null:
return $default(_that.id,_that.tenantId,_that.uploadedBy,_that.bucketId,_that.objectPath,_that.mimeType,_that.fileSizeBytes,_that.status,_that.processingStartedAt,_that.processingCompletedAt,_that.errorMessage,_that.extractedJson,_that.suggestedTransactionJson,_that.confidenceScore,_that.dedupKey,_that.matchedLancamentoId,_that.linkedLancamentoId,_that.createdAt,_that.updatedAt,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'uploaded_by')  String uploadedBy, @JsonKey(name: 'bucket_id')  String bucketId, @JsonKey(name: 'object_path')  String objectPath, @JsonKey(name: 'mime_type')  String mimeType, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes,  AttachmentStatus status, @JsonKey(name: 'processing_started_at')  DateTime? processingStartedAt, @JsonKey(name: 'processing_completed_at')  DateTime? processingCompletedAt, @JsonKey(name: 'error_message')  String? errorMessage, @JsonKey(name: 'extracted_json')  Map<String, dynamic>? extractedJson, @JsonKey(name: 'suggested_transaction_json')  Map<String, dynamic>? suggestedTransactionJson, @JsonKey(name: 'confidence_score')  double? confidenceScore, @JsonKey(name: 'dedup_key')  String? dedupKey, @JsonKey(name: 'matched_lancamento_id')  String? matchedLancamentoId, @JsonKey(name: 'linked_lancamento_id')  String? linkedLancamentoId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _FinancialAttachment():
return $default(_that.id,_that.tenantId,_that.uploadedBy,_that.bucketId,_that.objectPath,_that.mimeType,_that.fileSizeBytes,_that.status,_that.processingStartedAt,_that.processingCompletedAt,_that.errorMessage,_that.extractedJson,_that.suggestedTransactionJson,_that.confidenceScore,_that.dedupKey,_that.matchedLancamentoId,_that.linkedLancamentoId,_that.createdAt,_that.updatedAt,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'uploaded_by')  String uploadedBy, @JsonKey(name: 'bucket_id')  String bucketId, @JsonKey(name: 'object_path')  String objectPath, @JsonKey(name: 'mime_type')  String mimeType, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes,  AttachmentStatus status, @JsonKey(name: 'processing_started_at')  DateTime? processingStartedAt, @JsonKey(name: 'processing_completed_at')  DateTime? processingCompletedAt, @JsonKey(name: 'error_message')  String? errorMessage, @JsonKey(name: 'extracted_json')  Map<String, dynamic>? extractedJson, @JsonKey(name: 'suggested_transaction_json')  Map<String, dynamic>? suggestedTransactionJson, @JsonKey(name: 'confidence_score')  double? confidenceScore, @JsonKey(name: 'dedup_key')  String? dedupKey, @JsonKey(name: 'matched_lancamento_id')  String? matchedLancamentoId, @JsonKey(name: 'linked_lancamento_id')  String? linkedLancamentoId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _FinancialAttachment() when $default != null:
return $default(_that.id,_that.tenantId,_that.uploadedBy,_that.bucketId,_that.objectPath,_that.mimeType,_that.fileSizeBytes,_that.status,_that.processingStartedAt,_that.processingCompletedAt,_that.errorMessage,_that.extractedJson,_that.suggestedTransactionJson,_that.confidenceScore,_that.dedupKey,_that.matchedLancamentoId,_that.linkedLancamentoId,_that.createdAt,_that.updatedAt,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FinancialAttachment extends FinancialAttachment {
  const _FinancialAttachment({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, @JsonKey(name: 'uploaded_by') required this.uploadedBy, @JsonKey(name: 'bucket_id') required this.bucketId, @JsonKey(name: 'object_path') required this.objectPath, @JsonKey(name: 'mime_type') required this.mimeType, @JsonKey(name: 'file_size_bytes') this.fileSizeBytes, required this.status, @JsonKey(name: 'processing_started_at') this.processingStartedAt, @JsonKey(name: 'processing_completed_at') this.processingCompletedAt, @JsonKey(name: 'error_message') this.errorMessage, @JsonKey(name: 'extracted_json') final  Map<String, dynamic>? extractedJson, @JsonKey(name: 'suggested_transaction_json') final  Map<String, dynamic>? suggestedTransactionJson, @JsonKey(name: 'confidence_score') this.confidenceScore, @JsonKey(name: 'dedup_key') this.dedupKey, @JsonKey(name: 'matched_lancamento_id') this.matchedLancamentoId, @JsonKey(name: 'linked_lancamento_id') this.linkedLancamentoId, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'deleted_at') this.deletedAt}): _extractedJson = extractedJson,_suggestedTransactionJson = suggestedTransactionJson,super._();
  factory _FinancialAttachment.fromJson(Map<String, dynamic> json) => _$FinancialAttachmentFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey(name: 'uploaded_by') final  String uploadedBy;
@override@JsonKey(name: 'bucket_id') final  String bucketId;
@override@JsonKey(name: 'object_path') final  String objectPath;
@override@JsonKey(name: 'mime_type') final  String mimeType;
@override@JsonKey(name: 'file_size_bytes') final  int? fileSizeBytes;
@override final  AttachmentStatus status;
@override@JsonKey(name: 'processing_started_at') final  DateTime? processingStartedAt;
@override@JsonKey(name: 'processing_completed_at') final  DateTime? processingCompletedAt;
@override@JsonKey(name: 'error_message') final  String? errorMessage;
 final  Map<String, dynamic>? _extractedJson;
@override@JsonKey(name: 'extracted_json') Map<String, dynamic>? get extractedJson {
  final value = _extractedJson;
  if (value == null) return null;
  if (_extractedJson is EqualUnmodifiableMapView) return _extractedJson;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _suggestedTransactionJson;
@override@JsonKey(name: 'suggested_transaction_json') Map<String, dynamic>? get suggestedTransactionJson {
  final value = _suggestedTransactionJson;
  if (value == null) return null;
  if (_suggestedTransactionJson is EqualUnmodifiableMapView) return _suggestedTransactionJson;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'confidence_score') final  double? confidenceScore;
@override@JsonKey(name: 'dedup_key') final  String? dedupKey;
@override@JsonKey(name: 'matched_lancamento_id') final  String? matchedLancamentoId;
@override@JsonKey(name: 'linked_lancamento_id') final  String? linkedLancamentoId;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
@override@JsonKey(name: 'deleted_at') final  DateTime? deletedAt;

/// Create a copy of FinancialAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FinancialAttachmentCopyWith<_FinancialAttachment> get copyWith => __$FinancialAttachmentCopyWithImpl<_FinancialAttachment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FinancialAttachmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FinancialAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.bucketId, bucketId) || other.bucketId == bucketId)&&(identical(other.objectPath, objectPath) || other.objectPath == objectPath)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.status, status) || other.status == status)&&(identical(other.processingStartedAt, processingStartedAt) || other.processingStartedAt == processingStartedAt)&&(identical(other.processingCompletedAt, processingCompletedAt) || other.processingCompletedAt == processingCompletedAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&const DeepCollectionEquality().equals(other._extractedJson, _extractedJson)&&const DeepCollectionEquality().equals(other._suggestedTransactionJson, _suggestedTransactionJson)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.dedupKey, dedupKey) || other.dedupKey == dedupKey)&&(identical(other.matchedLancamentoId, matchedLancamentoId) || other.matchedLancamentoId == matchedLancamentoId)&&(identical(other.linkedLancamentoId, linkedLancamentoId) || other.linkedLancamentoId == linkedLancamentoId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,uploadedBy,bucketId,objectPath,mimeType,fileSizeBytes,status,processingStartedAt,processingCompletedAt,errorMessage,const DeepCollectionEquality().hash(_extractedJson),const DeepCollectionEquality().hash(_suggestedTransactionJson),confidenceScore,dedupKey,matchedLancamentoId,linkedLancamentoId,createdAt,updatedAt,deletedAt]);

@override
String toString() {
  return 'FinancialAttachment(id: $id, tenantId: $tenantId, uploadedBy: $uploadedBy, bucketId: $bucketId, objectPath: $objectPath, mimeType: $mimeType, fileSizeBytes: $fileSizeBytes, status: $status, processingStartedAt: $processingStartedAt, processingCompletedAt: $processingCompletedAt, errorMessage: $errorMessage, extractedJson: $extractedJson, suggestedTransactionJson: $suggestedTransactionJson, confidenceScore: $confidenceScore, dedupKey: $dedupKey, matchedLancamentoId: $matchedLancamentoId, linkedLancamentoId: $linkedLancamentoId, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$FinancialAttachmentCopyWith<$Res> implements $FinancialAttachmentCopyWith<$Res> {
  factory _$FinancialAttachmentCopyWith(_FinancialAttachment value, $Res Function(_FinancialAttachment) _then) = __$FinancialAttachmentCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'uploaded_by') String uploadedBy,@JsonKey(name: 'bucket_id') String bucketId,@JsonKey(name: 'object_path') String objectPath,@JsonKey(name: 'mime_type') String mimeType,@JsonKey(name: 'file_size_bytes') int? fileSizeBytes, AttachmentStatus status,@JsonKey(name: 'processing_started_at') DateTime? processingStartedAt,@JsonKey(name: 'processing_completed_at') DateTime? processingCompletedAt,@JsonKey(name: 'error_message') String? errorMessage,@JsonKey(name: 'extracted_json') Map<String, dynamic>? extractedJson,@JsonKey(name: 'suggested_transaction_json') Map<String, dynamic>? suggestedTransactionJson,@JsonKey(name: 'confidence_score') double? confidenceScore,@JsonKey(name: 'dedup_key') String? dedupKey,@JsonKey(name: 'matched_lancamento_id') String? matchedLancamentoId,@JsonKey(name: 'linked_lancamento_id') String? linkedLancamentoId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'deleted_at') DateTime? deletedAt
});




}
/// @nodoc
class __$FinancialAttachmentCopyWithImpl<$Res>
    implements _$FinancialAttachmentCopyWith<$Res> {
  __$FinancialAttachmentCopyWithImpl(this._self, this._then);

  final _FinancialAttachment _self;
  final $Res Function(_FinancialAttachment) _then;

/// Create a copy of FinancialAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? uploadedBy = null,Object? bucketId = null,Object? objectPath = null,Object? mimeType = null,Object? fileSizeBytes = freezed,Object? status = null,Object? processingStartedAt = freezed,Object? processingCompletedAt = freezed,Object? errorMessage = freezed,Object? extractedJson = freezed,Object? suggestedTransactionJson = freezed,Object? confidenceScore = freezed,Object? dedupKey = freezed,Object? matchedLancamentoId = freezed,Object? linkedLancamentoId = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(_FinancialAttachment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,bucketId: null == bucketId ? _self.bucketId : bucketId // ignore: cast_nullable_to_non_nullable
as String,objectPath: null == objectPath ? _self.objectPath : objectPath // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AttachmentStatus,processingStartedAt: freezed == processingStartedAt ? _self.processingStartedAt : processingStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,processingCompletedAt: freezed == processingCompletedAt ? _self.processingCompletedAt : processingCompletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,extractedJson: freezed == extractedJson ? _self._extractedJson : extractedJson // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,suggestedTransactionJson: freezed == suggestedTransactionJson ? _self._suggestedTransactionJson : suggestedTransactionJson // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,confidenceScore: freezed == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as double?,dedupKey: freezed == dedupKey ? _self.dedupKey : dedupKey // ignore: cast_nullable_to_non_nullable
as String?,matchedLancamentoId: freezed == matchedLancamentoId ? _self.matchedLancamentoId : matchedLancamentoId // ignore: cast_nullable_to_non_nullable
as String?,linkedLancamentoId: freezed == linkedLancamentoId ? _self.linkedLancamentoId : linkedLancamentoId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
