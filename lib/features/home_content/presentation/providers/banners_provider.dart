import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/banners_repository.dart';
import '../../domain/models/banner.dart';

/// Provider do repository de banners
final bannersRepositoryProvider = Provider<BannersRepository>((ref) {
  return BannersRepository(Supabase.instance.client);
});

/// Provider de todos os banners (incluindo inativos) - usado no painel admin
final allBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final repo = ref.watch(bannersRepositoryProvider);
  return repo.getAllBanners();
});

/// Provider de banners ativos (para exibição no app) - mantido para compatibilidade
final activeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final repo = ref.watch(bannersRepositoryProvider);
  return repo.getActiveBanners();
});

/// Provider de banners ativos com realtime (para tela Home do app) - USAR ESTE NA HOME!
final activeBannersStreamProvider = StreamProvider.autoDispose<List<HomeBanner>>((ref) {
  final repo = ref.watch(bannersRepositoryProvider);
  return repo.watchActiveBanners();
});

/// Provider de banner por ID
final bannerByIdProvider = FutureProvider.family<HomeBanner?, String>((ref, id) async {
  final repo = ref.watch(bannersRepositoryProvider);
  return repo.getBannerById(id);
});

/// Provider para contar total de banners
final bannersCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(bannersRepositoryProvider);
  return repo.countBanners();
});

/// Provider para contar banners ativos
final activeBannersCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(bannersRepositoryProvider);
  return repo.countActiveBanners();
});

