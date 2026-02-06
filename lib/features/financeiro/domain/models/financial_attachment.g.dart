// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FinancialAttachment _$FinancialAttachmentFromJson(Map<String, dynamic> json) =>
    _FinancialAttachment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      uploadedBy: json['uploaded_by'] as String,
      bucketId: json['bucket_id'] as String,
      objectPath: json['object_path'] as String,
      mimeType: json['mime_type'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      status: $enumDecode(_$AttachmentStatusEnumMap, json['status']),
      processingStartedAt: json['processing_started_at'] == null
          ? null
          : DateTime.parse(json['processing_started_at'] as String),
      processingCompletedAt: json['processing_completed_at'] == null
          ? null
          : DateTime.parse(json['processing_completed_at'] as String),
      errorMessage: json['error_message'] as String?,
      extractedJson: json['extracted_json'] as Map<String, dynamic>?,
      suggestedTransactionJson:
          json['suggested_transaction_json'] as Map<String, dynamic>?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      dedupKey: json['dedup_key'] as String?,
      matchedLancamentoId: json['matched_lancamento_id'] as String?,
      linkedLancamentoId: json['linked_lancamento_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
    );

Map<String, dynamic> _$FinancialAttachmentToJson(
  _FinancialAttachment instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'uploaded_by': instance.uploadedBy,
  'bucket_id': instance.bucketId,
  'object_path': instance.objectPath,
  'mime_type': instance.mimeType,
  'file_size_bytes': instance.fileSizeBytes,
  'status': _$AttachmentStatusEnumMap[instance.status]!,
  'processing_started_at': instance.processingStartedAt?.toIso8601String(),
  'processing_completed_at': instance.processingCompletedAt?.toIso8601String(),
  'error_message': instance.errorMessage,
  'extracted_json': instance.extractedJson,
  'suggested_transaction_json': instance.suggestedTransactionJson,
  'confidence_score': instance.confidenceScore,
  'dedup_key': instance.dedupKey,
  'matched_lancamento_id': instance.matchedLancamentoId,
  'linked_lancamento_id': instance.linkedLancamentoId,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'deleted_at': instance.deletedAt?.toIso8601String(),
};

const _$AttachmentStatusEnumMap = {
  AttachmentStatus.uploaded: 'uploaded',
  AttachmentStatus.processing: 'processing',
  AttachmentStatus.ready: 'ready',
  AttachmentStatus.failed: 'failed',
};
