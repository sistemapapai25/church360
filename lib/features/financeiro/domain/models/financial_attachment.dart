// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'financial_attachment.freezed.dart';
part 'financial_attachment.g.dart';

/// Status do processamento do anexo
enum AttachmentStatus {
  @JsonValue('uploaded')
  uploaded,
  @JsonValue('processing')
  processing,
  @JsonValue('ready')
  ready,
  @JsonValue('failed')
  failed,
}

/// Model para anexos/comprovantes financeiros com análise de IA
@freezed
abstract class FinancialAttachment with _$FinancialAttachment {
  const FinancialAttachment._();

  const factory FinancialAttachment({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'uploaded_by') required String uploadedBy,
    @JsonKey(name: 'bucket_id') required String bucketId,
    @JsonKey(name: 'object_path') required String objectPath,
    @JsonKey(name: 'mime_type') required String mimeType,
    @JsonKey(name: 'file_size_bytes') int? fileSizeBytes,
    required AttachmentStatus status,
    @JsonKey(name: 'processing_started_at') DateTime? processingStartedAt,
    @JsonKey(name: 'processing_completed_at') DateTime? processingCompletedAt,
    @JsonKey(name: 'error_message') String? errorMessage,
    @JsonKey(name: 'extracted_json') Map<String, dynamic>? extractedJson,
    @JsonKey(name: 'suggested_transaction_json')
    Map<String, dynamic>? suggestedTransactionJson,
    @JsonKey(name: 'confidence_score') double? confidenceScore,
    @JsonKey(name: 'dedup_key') String? dedupKey,
    @JsonKey(name: 'matched_lancamento_id') String? matchedLancamentoId,
    @JsonKey(name: 'linked_lancamento_id') String? linkedLancamentoId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'deleted_at') DateTime? deletedAt,
  }) = _FinancialAttachment;

  factory FinancialAttachment.fromJson(Map<String, dynamic> json) =>
      _$FinancialAttachmentFromJson(json);
}

/// Extension para helpers
extension FinancialAttachmentX on FinancialAttachment {
  /// Retorna true se o anexo está processando
  bool get isProcessing => status == AttachmentStatus.processing;

  /// Retorna true se o anexo está pronto
  bool get isReady => status == AttachmentStatus.ready;

  /// Retorna true se houve erro
  bool get hasFailed => status == AttachmentStatus.failed;

  /// Retorna true se está vinculado a um lançamento
  bool get isLinked => linkedLancamentoId != null;

  /// Retorna true se foi encontrado um match (possível duplicata)
  bool get hasMatch => matchedLancamentoId != null;

  /// Retorna o nível de confiança como enum
  ConfidenceLevel get confidenceLevel {
    if (confidenceScore == null) return ConfidenceLevel.unknown;
    if (confidenceScore! >= 0.80) return ConfidenceLevel.high;
    if (confidenceScore! >= 0.60) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  /// Retorna o tamanho do arquivo formatado
  String get formattedFileSize {
    if (fileSizeBytes == null) return 'Desconhecido';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Retorna true se é uma imagem
  bool get isImage => mimeType.startsWith('image/');

  /// Retorna true se é um PDF
  bool get isPdf => mimeType == 'application/pdf';

  /// Retorna o nome do arquivo a partir do path
  String get fileName {
    final parts = objectPath.split('/');
    return parts.isNotEmpty ? parts.last : 'arquivo';
  }
}

/// Nível de confiança da IA
enum ConfidenceLevel {
  unknown,
  low,
  medium,
  high,
}

/// Extension para ConfidenceLevel
extension ConfidenceLevelX on ConfidenceLevel {
  String get label {
    switch (this) {
      case ConfidenceLevel.high:
        return 'Alta confiança';
      case ConfidenceLevel.medium:
        return 'Revisar';
      case ConfidenceLevel.low:
        return 'Baixa confiança';
      case ConfidenceLevel.unknown:
        return 'Desconhecido';
    }
  }

  String get emoji {
    switch (this) {
      case ConfidenceLevel.high:
        return '✅';
      case ConfidenceLevel.medium:
        return '⚠️';
      case ConfidenceLevel.low:
        return '❌';
      case ConfidenceLevel.unknown:
        return '❓';
    }
  }
}
