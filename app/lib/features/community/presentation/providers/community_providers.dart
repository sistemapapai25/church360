import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/community_repository.dart';
import '../../domain/models/community_post.dart';
import '../../domain/models/classified.dart';

// Repository Provider
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final supabase = Supabase.instance.client;
  return CommunityRepository(supabase);
});

// Posts Provider
final communityPostsProvider = FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPosts();
});

// Classifieds Provider
final classifiedsProvider = FutureProvider.autoDispose<List<Classified>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getClassifieds();
});

// Pending Posts Provider
final pendingPostsProvider = FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPendingPosts();
});

// Pending Classifieds Provider
final pendingClassifiedsProvider = FutureProvider.autoDispose<List<Classified>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPendingClassifieds();
});
