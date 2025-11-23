import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/banner.dart';

/// Repository para gerenciar banners da Home
class BannersRepository {
  final SupabaseClient _supabase;

  BannersRepository(this._supabase);

  /// Buscar todos os banners (ordenados por order_index)
  Future<List<HomeBanner>> getAllBanners() async {
    try {
      final response = await _supabase
          .from('home_banner')
          .select()
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => HomeBanner.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar apenas banners ativos (para exibição no app)
  Future<List<HomeBanner>> getActiveBanners() async {
    try {
      final response = await _supabase
          .from('home_banner')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => HomeBanner.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Stream de banners ativos com realtime
  Stream<List<HomeBanner>> watchActiveBanners() {
    return _supabase
        .from('home_banner')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('order_index', ascending: true)
        .map((data) => data.map((json) => HomeBanner.fromJson(json)).toList());
  }

  /// Buscar banner por ID
  Future<HomeBanner?> getBannerById(String id) async {
    try {
      final response = await _supabase
          .from('home_banner')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return HomeBanner.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo banner
  Future<HomeBanner> createBanner(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('home_banner')
          .insert(data)
          .select()
          .single();

      return HomeBanner.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar banner
  Future<HomeBanner> updateBanner(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('home_banner')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return HomeBanner.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar banner
  Future<void> deleteBanner(String id) async {
    try {
      await _supabase.from('home_banner').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Ativar/desativar banner
  Future<HomeBanner> toggleBannerActive(String id, bool isActive) async {
    try {
      final response = await _supabase
          .from('home_banner')
          .update({'is_active': isActive})
          .eq('id', id)
          .select()
          .single();

      return HomeBanner.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar ordem dos banners
  /// Recebe uma lista de IDs na ordem desejada
  Future<void> updateBannersOrder(List<String> bannerIds) async {
    try {
      // Atualizar cada banner com seu novo order_index
      for (int i = 0; i < bannerIds.length; i++) {
        await _supabase
            .from('home_banner')
            .update({'order_index': i})
            .eq('id', bannerIds[i]);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Contar total de banners
  Future<int> countBanners() async {
    try {
      final response = await _supabase
          .from('home_banner')
          .select()
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Contar banners ativos
  Future<int> countActiveBanners() async {
    try {
      final response = await _supabase
          .from('home_banner')
          .select()
          .eq('is_active', true)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }
}

