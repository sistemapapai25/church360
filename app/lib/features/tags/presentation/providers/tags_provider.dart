import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/tag.dart';
import '../../data/tags_repository.dart';

/// Provider de todas as tags
final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final repository = ref.watch(tagsRepositoryProvider);
  return repository.getAllTags();
});

/// Provider de tag por ID
final tagByIdProvider = FutureProvider.family<Tag?, String>((ref, id) async {
  final repository = ref.watch(tagsRepositoryProvider);
  return repository.getTagById(id);
});

/// Provider de tags de um membro
final memberTagsProvider = FutureProvider.family<List<Tag>, String>((ref, memberId) async {
  final repository = ref.watch(tagsRepositoryProvider);
  return repository.getMemberTags(memberId);
});

/// Provider de membros de uma tag
final tagMembersProvider = FutureProvider.family<List<String>, String>((ref, tagId) async {
  final repository = ref.watch(tagsRepositoryProvider);
  return repository.getTagMembers(tagId);
});

/// Provider de contagem total de tags
final totalTagsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(tagsRepositoryProvider);
  return repository.getTotalTagsCount();
});

/// Provider de tags mais usadas
final mostUsedTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final repository = ref.watch(tagsRepositoryProvider);
  return repository.getMostUsedTags(limit: 5);
});

