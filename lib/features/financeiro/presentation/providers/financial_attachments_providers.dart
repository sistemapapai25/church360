import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/financial_attachments_repository.dart';
import '../../domain/models/financial_attachment.dart';

/// Provider do repository
final financialAttachmentsRepositoryProvider =
    Provider<FinancialAttachmentsRepository>((ref) {
  return FinancialAttachmentsRepository(Supabase.instance.client);
});

/// Provider para buscar um anexo por ID
final attachmentByIdProvider = FutureProvider.family
    .autoDispose<FinancialAttachment?, String>((ref, id) async {
  final repo = ref.watch(financialAttachmentsRepositoryProvider);
  return repo.getAttachmentById(id);
});

/// Provider para listar todos os anexos
final allAttachmentsProvider =
    FutureProvider.autoDispose<List<FinancialAttachment>>((ref) async {
  final repo = ref.watch(financialAttachmentsRepositoryProvider);
  return repo.getAllAttachments();
});

/// Provider para listar anexos não vinculados (pendentes)
final unlinkedAttachmentsProvider =
    FutureProvider.autoDispose<List<FinancialAttachment>>((ref) async {
  final repo = ref.watch(financialAttachmentsRepositoryProvider);
  return repo.getAllAttachments(onlyUnlinked: true);
});

/// Provider para listar anexos prontos (processados com sucesso)
final readyAttachmentsProvider =
    FutureProvider.autoDispose<List<FinancialAttachment>>((ref) async {
  final repo = ref.watch(financialAttachmentsRepositoryProvider);
  return repo.getAllAttachments(status: AttachmentStatus.ready);
});

/// Provider para gerar signed URL
final signedUrlProvider =
    FutureProvider.family.autoDispose<String, String>((ref, objectPath) async {
  final repo = ref.watch(financialAttachmentsRepositoryProvider);
  return repo.generateSignedUrl(objectPath);
});

