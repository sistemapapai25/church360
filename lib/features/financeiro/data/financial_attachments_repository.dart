import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../domain/models/financial_attachment.dart';
import '../../../core/constants/supabase_constants.dart';

/// Repository para gerenciar anexos/comprovantes financeiros
class FinancialAttachmentsRepository {
  final SupabaseClient _supabase;
  static const String _tableName = 'financial_attachments';
  static const String _bucketName = 'comprovantes';

  FinancialAttachmentsRepository(this._supabase);

  /// Cria um novo anexo e faz upload do arquivo
  Future<FinancialAttachment> createAttachment({
    required File file,
    required String mimeType,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');

    final tenantId = SupabaseConstants.currentTenantId;
    final fileExtension = path.extension(file.path);
    final fileName = '${const Uuid().v4()}$fileExtension';
    final objectPath = '$tenantId/receipts/$fileName';

    // 1. Upload do arquivo para Storage
    await _supabase.storage.from(_bucketName).upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    // 2. Criar registro no banco
    final data = {
      'tenant_id': tenantId,
      'uploaded_by': userId,
      'bucket_id': _bucketName,
      'object_path': objectPath,
      'mime_type': mimeType,
      'file_size_bytes': await file.length(),
      'status': 'uploaded',
    };

    final response = await _supabase
        .from(_tableName)
        .insert(data)
        .select()
        .single();

    return FinancialAttachment.fromJson(response);
  }

  /// Cria um novo anexo a partir de bytes (para web)
  Future<FinancialAttachment> createAttachmentFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado');

    final tenantId = SupabaseConstants.currentTenantId;
    final fileExtension = path.extension(fileName);
    final uniqueFileName = '${const Uuid().v4()}$fileExtension';
    final objectPath = '$tenantId/receipts/$uniqueFileName';

    // 1. Upload do arquivo para Storage
    await _supabase.storage.from(_bucketName).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    // 2. Criar registro no banco
    final data = {
      'tenant_id': tenantId,
      'uploaded_by': userId,
      'bucket_id': _bucketName,
      'object_path': objectPath,
      'mime_type': mimeType,
      'file_size_bytes': bytes.length,
      'status': 'uploaded',
    };

    final response = await _supabase
        .from(_tableName)
        .insert(data)
        .select()
        .single();

    return FinancialAttachment.fromJson(response);
  }

  /// Busca um anexo por ID
  Future<FinancialAttachment?> getAttachmentById(String id) async {
    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (response == null) return null;
    return FinancialAttachment.fromJson(response);
  }

  /// Lista todos os anexos do tenant
  Future<List<FinancialAttachment>> getAllAttachments({
    AttachmentStatus? status,
    bool onlyUnlinked = false,
  }) async {
    dynamic query = _supabase
        .from(_tableName)
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .isFilter('deleted_at', null);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    if (onlyUnlinked) {
      query = query.isFilter('linked_lancamento_id', null);
    }

    query = query.order('created_at', ascending: false);

    final response = await query as List<dynamic>;
    return response
        .map((json) => FinancialAttachment.fromJson(json))
        .toList();
  }

  /// Atualiza o status do anexo
  Future<FinancialAttachment> updateStatus({
    required String id,
    required AttachmentStatus status,
    String? errorMessage,
  }) async {
    final data = <String, dynamic>{
      'status': status.name,
    };

    if (status == AttachmentStatus.processing) {
      data['processing_started_at'] = DateTime.now().toIso8601String();
    } else if (status == AttachmentStatus.ready ||
        status == AttachmentStatus.failed) {
      data['processing_completed_at'] = DateTime.now().toIso8601String();
    }

    if (errorMessage != null) {
      data['error_message'] = errorMessage;
    }

    final response = await _supabase
        .from(_tableName)
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return FinancialAttachment.fromJson(response);
  }

  /// Vincula o anexo a um lançamento
  Future<FinancialAttachment> linkToLancamento({
    required String attachmentId,
    required String lancamentoId,
  }) async {
    final response = await _supabase
        .from(_tableName)
        .update({'linked_lancamento_id': lancamentoId})
        .eq('id', attachmentId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return FinancialAttachment.fromJson(response);
  }

  /// Gera uma signed URL para preview do arquivo
  Future<String> generateSignedUrl(String objectPath,
      {int expiresInSeconds = 3600}) async {
    return await _supabase.storage
        .from(_bucketName)
        .createSignedUrl(objectPath, expiresInSeconds);
  }

  /// Deleta um anexo (soft delete)
  Future<void> deleteAttachment(String id) async {
    await _supabase.rpc('soft_delete_financial_attachment', params: {
      'attachment_id': id,
    });
  }
}

