import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/community_post.dart';
import '../domain/models/classified.dart';

class CommunityRepository {
  final SupabaseClient _supabase;
  bool? _classifiedDealStatusSupported;

  CommunityRepository(this._supabase);

  Future<String?> _effectiveUserId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
  }

  Exception _commentsNotEnabledException() {
    return Exception('Comentários ainda não estão habilitados. Execute o SQL community_updates.sql no Supabase.');
  }
  Exception _classifiedCommentsNotEnabledException() {
    return Exception('Comentários ainda não estão habilitados. Execute o SQL community_updates.sql no Supabase.');
  }
  Exception _devotionalCommentsNotEnabledException() {
    return Exception('Comentários ainda não estão habilitados. Execute o SQL community_updates.sql no Supabase.');
  }

  bool _isMissingDealStatusColumn(PostgrestException e) {
    final message = e.message.toLowerCase();
    return e.code == '42703' && message.contains('deal_status') && message.contains('does not exist');
  }

  Future<bool> _supportsClassifiedDealStatus() async {
    final cached = _classifiedDealStatusSupported;
    if (cached != null) return cached;

    try {
      await _supabase.from('classifieds').select('deal_status').limit(1);
      _classifiedDealStatusSupported = true;
      return true;
    } on PostgrestException catch (e) {
      if (_isMissingDealStatusColumn(e)) {
        _classifiedDealStatusSupported = false;
        return false;
      }
      rethrow;
    }
  }


  // --- Posts (Mural) ---

  Future<List<CommunityPost>> getPosts({int limit = 20, int offset = 0}) async {
    final userId = await _effectiveUserId();

    final List<dynamic> response = await _supabase
        .from('community_posts')
        .select('*, author:user_account!community_posts_author_id_fkey(full_name, avatar_url, photo_url, foto, nickname, phone)')
        .eq('status', 'approved')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final ids = <String>[];
    for (final j in response) {
      final id = (j is Map<String, dynamic>) ? j['id'] : null;
      if (id == null) continue;
      final s = id.toString();
      if (s.trim().isEmpty) continue;
      ids.add(s);
    }

    final likesById = <String, int>{};
    if (ids.isNotEmpty) {
      final reactsForCount = await _supabase
          .from('community_reactions')
          .select('item_id')
          .eq('item_type', 'post')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .inFilter('item_id', ids);

      for (final r in (reactsForCount as List)) {
        final itemId = r['item_id']?.toString();
        if (itemId == null || itemId.trim().isEmpty) continue;
        likesById[itemId] = (likesById[itemId] ?? 0) + 1;
      }
    }

    Map<String, String?> myReactions = {};
    if (userId != null && ids.isNotEmpty) {
      final reacts = await _supabase
          .from('community_reactions')
          .select('item_id, reaction')
          .eq('item_type', 'post')
          .eq('user_id', userId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .inFilter('item_id', ids);
      for (final r in (reacts as List)) {
        final itemId = r['item_id']?.toString();
        if (itemId == null || itemId.trim().isEmpty) continue;
        myReactions[itemId] = r['reaction']?.toString();
      }
    }

    return response.map((json) {
      final id = json['id']?.toString();
      final mr = id != null ? myReactions[id] : null;
      if (id != null && id.trim().isNotEmpty) {
        json['likes_count'] = likesById[id] ?? 0;
      }
      json['my_reaction'] = mr;
      json['is_liked_by_me'] = mr != null;
      return CommunityPost.fromJson(json);
    }).toList();
  }

  Future<void> toggleLike(String postId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final existingLike = await _supabase
        .from('community_reactions')
        .select('reaction')
        .eq('item_type', 'post')
        .eq('item_id', postId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existingLike != null) {
      await removeReaction(postId);
    } else {
      await setReaction(postId, 'like');
    }
  }

  Future<void> setReaction(String postId, String reaction) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final existing = await _supabase
        .from('community_reactions')
        .select('reaction')
        .eq('item_type', 'post')
        .eq('item_id', postId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('community_reactions').insert({
        'item_type': 'post',
        'item_id': postId,
        'user_id': userId,
        'reaction': reaction,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
      return;
    }

    final currentReaction = existing['reaction']?.toString();
    if (currentReaction == reaction) return;

    await _supabase
        .from('community_reactions')
        .update({'reaction': reaction})
        .eq('item_type', 'post')
        .eq('item_id', postId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<void> removeReaction(String postId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final existing = await _supabase
        .from('community_reactions')
        .select('id')
        .eq('item_type', 'post')
        .eq('item_id', postId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existing == null) return;

    await _supabase
        .from('community_reactions')
        .delete()
        .eq('item_type', 'post')
        .eq('item_id', postId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }


  Future<void> createPost(String content, String type, {bool isPublic = false, bool allowWhatsappContact = false}) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    await _supabase.from('community_posts').insert({
      'author_id': userId,
      'content': content,
      'type': type,
      'status': 'pending_approval', // Sempre pendente
      'is_public': isPublic,
      'allow_whatsapp_contact': allowWhatsappContact,
      'tenant_id': SupabaseConstants.currentTenantId,
    });
  }

  Future<List<CommunityPost>> getPendingPosts() async {
    final response = await _supabase
        .from('community_posts')
        .select('*, author:user_account!community_posts_author_id_fkey(full_name, avatar_url, nickname)')
        .eq('status', 'pending_approval')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: true);

    return response.map((json) {
       // Pending posts don't need 'is_liked_by_me' check usually, but for consistency:
       json['is_liked_by_me'] = false; 
       return CommunityPost.fromJson(json);
    }).toList();
  }

  Future<void> updatePostStatus(String id, String status) async {
    await _supabase
        .from('community_posts')
        .update({'status': status})
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // --- Comments ---
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final response = await _supabase
          .from('community_comments')
          .select('*, author:user_account(full_name, avatar_url, nickname)')
          .eq('item_type', 'post')
          .eq('item_id', postId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'PGRST205' || message.contains('could not find the table')) {
        if (message.contains('community_comments')) {
          throw _commentsNotEnabledException();
        }
      }
      rethrow;
    }
  }

  Future<void> addComment(String postId, String content) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    try {
      await _supabase.from('community_comments').insert({
        'item_type': 'post',
        'item_id': postId,
        'user_id': userId,
        'content': content,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'PGRST205' || message.contains('could not find the table')) {
        if (message.contains('community_comments')) {
          throw _commentsNotEnabledException();
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDevotionalComments(String devotionalId) async {
    try {
      final response = await _supabase
          .from('community_comments')
          .select('*, author:user_account(full_name, avatar_url, nickname)')
          .eq('item_type', 'devotional')
          .eq('item_id', devotionalId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'PGRST205' || message.contains('could not find the table')) {
        if (message.contains('community_comments')) {
          throw _devotionalCommentsNotEnabledException();
        }
      }
      rethrow;
    }
  }

  Future<void> addDevotionalComment(String devotionalId, String content) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    try {
      await _supabase.from('community_comments').insert({
        'item_type': 'devotional',
        'item_id': devotionalId,
        'user_id': userId,
        'content': content,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'PGRST205' || message.contains('could not find the table')) {
        if (message.contains('community_comments')) {
          throw _devotionalCommentsNotEnabledException();
        }
      }
      rethrow;
    }
  }

  // --- Classificados ---

  Future<List<Classified>> getClassifieds({int limit = 20, int offset = 0}) async {
    final userId = await _effectiveUserId();
    final List<dynamic> response = await _supabase
        .from('classifieds')
        .select('*, author:user_account!classifieds_author_id_fkey(full_name, avatar_url, photo_url, foto, nickname)')
        .eq('status', 'approved')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final ids = <String>[];
    for (final j in response) {
      final id = (j as Map)['id'];
      if (id == null) continue;
      final s = id.toString();
      if (s.trim().isEmpty) continue;
      ids.add(s);
    }

    final likesById = <String, int>{};
    if (ids.isNotEmpty) {
      final reactsForCount = await _supabase
          .from('community_reactions')
          .select('item_id')
          .eq('item_type', 'classified')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .inFilter('item_id', ids);

      for (final r in (reactsForCount as List)) {
        final itemId = r['item_id']?.toString();
        if (itemId == null || itemId.trim().isEmpty) continue;
        likesById[itemId] = (likesById[itemId] ?? 0) + 1;
      }
    }

    Map<String, String?> myReactions = {};
    if (userId != null && ids.isNotEmpty) {
      final reacts = await _supabase
          .from('community_reactions')
          .select('item_id, reaction')
          .eq('item_type', 'classified')
          .eq('user_id', userId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .inFilter('item_id', ids);
      for (final r in (reacts as List)) {
        final itemId = r['item_id']?.toString();
        if (itemId == null || itemId.trim().isEmpty) continue;
        myReactions[itemId] = r['reaction']?.toString();
      }
    }

    return response.map((json) {
      final id = json['id']?.toString();
      final mr = id != null ? myReactions[id] : null;
      if (id != null && id.trim().isNotEmpty) {
        json['likes_count'] = likesById[id] ?? 0;
      } else {
        json['likes_count'] = 0;
      }
      json['my_reaction'] = mr;
      json['is_liked_by_me'] = mr != null;
      return Classified.fromJson(json);
    }).toList();
  }

  Future<List<Classified>> getPendingClassifieds() async {
    final response = await _supabase
        .from('classifieds')
        .select('*, author:user_account(full_name, avatar_url, nickname)')
        .eq('status', 'pending_approval')
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: true);

    return response.map((json) => Classified.fromJson(json)).toList();
  }

  Future<void> updateClassifiedStatus(String id, String status) async {
    await _supabase
        .from('classifieds')
        .update({'status': status})
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<void> createClassified(Classified classified) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final data = classified.toJson();
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');
    data['author_id'] = userId;
    data['status'] = 'pending_approval';
    if (!await _supportsClassifiedDealStatus()) {
      data.remove('deal_status');
    }
    data['tenant_id'] = SupabaseConstants.currentTenantId;

    await _supabase.from('classifieds').insert(data);
  }

  Future<void> updateClassified(Classified classified) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final data = <String, dynamic>{
      'title': classified.title,
      'description': classified.description,
      'price': classified.price,
      'category': classified.category,
      'contact_info': classified.contactInfo,
      'image_urls': classified.imageUrls,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (await _supportsClassifiedDealStatus()) {
      data['deal_status'] = classified.dealStatus;
    }

    try {
      await _supabase.from('classifieds').update(data).eq('id', classified.id);
    } on PostgrestException catch (e) {
      if (_isMissingDealStatusColumn(e)) {
        throw Exception('Status do classificado ainda não está habilitado. Execute o SQL community_updates.sql no Supabase.');
      }
      rethrow;
    }
  }

  Future<void> setClassifiedDealStatus(String id, String dealStatus) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    if (!await _supportsClassifiedDealStatus()) {
      throw Exception('Status do classificado ainda não está habilitado. Execute o SQL community_updates.sql no Supabase.');
    }

    try {
      await _supabase.from('classifieds').update({
        'deal_status': dealStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).eq('tenant_id', SupabaseConstants.currentTenantId);
    } on PostgrestException catch (e) {
      if (_isMissingDealStatusColumn(e)) {
        throw Exception('Status do classificado ainda não está habilitado. Execute o SQL community_updates.sql no Supabase.');
      }
      rethrow;
    }
  }

  Future<void> toggleClassifiedLike(String classifiedId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');
    final existing = await _supabase
        .from('community_reactions')
        .select('reaction')
        .eq('item_type', 'classified')
        .eq('item_id', classifiedId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();
    if (existing != null) {
      await removeClassifiedReaction(classifiedId);
    } else {
      await setClassifiedReaction(classifiedId, 'like');
    }
  }

  Future<void> setClassifiedReaction(String classifiedId, String reaction) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');
    final existing = await _supabase
        .from('community_reactions')
        .select('reaction')
        .eq('item_type', 'classified')
        .eq('item_id', classifiedId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();
    if (existing == null) {
      await _supabase.from('community_reactions').insert({
        'item_type': 'classified',
        'item_id': classifiedId,
        'user_id': userId,
        'reaction': reaction,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
      return;
    }
    final currentReaction = existing['reaction']?.toString();
    if (currentReaction == reaction) return;
    await _supabase
        .from('community_reactions')
        .update({'reaction': reaction})
        .eq('item_type', 'classified')
        .eq('item_id', classifiedId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<void> removeClassifiedReaction(String classifiedId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');
    final existing = await _supabase
        .from('community_reactions')
        .select('id')
        .eq('item_type', 'classified')
        .eq('item_id', classifiedId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();
    if (existing == null) return;
    await _supabase
        .from('community_reactions')
        .delete()
        .eq('item_type', 'classified')
        .eq('item_id', classifiedId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<List<Map<String, dynamic>>> getClassifiedComments(String classifiedId) async {
    try {
      final response = await _supabase
          .from('community_comments')
          .select('*, author:user_account(full_name, avatar_url, nickname)')
          .eq('item_type', 'classified')
          .eq('item_id', classifiedId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'PGRST205' || message.contains('could not find the table')) {
        if (message.contains('community_comments')) {
          throw _classifiedCommentsNotEnabledException();
        }
      }
      rethrow;
    }
  }

  Future<void> addClassifiedComment(String classifiedId, String content) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');
    try {
      await _supabase.from('community_comments').insert({
        'item_type': 'classified',
        'item_id': classifiedId,
        'user_id': userId,
        'content': content,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'PGRST205' || message.contains('could not find the table')) {
        if (message.contains('community_comments')) {
          throw _classifiedCommentsNotEnabledException();
        }
      }
      rethrow;
    }
  }

  Future<void> toggleDevotionalLike(String devotionalId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final existingLike = await _supabase
        .from('community_reactions')
        .select('reaction')
        .eq('item_type', 'devotional')
        .eq('item_id', devotionalId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existingLike != null) {
      await removeDevotionalReaction(devotionalId);
    } else {
      await setDevotionalReaction(devotionalId, 'like');
    }
  }

  Future<void> setDevotionalReaction(String devotionalId, String reaction) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final existing = await _supabase
        .from('community_reactions')
        .select('reaction')
        .eq('item_type', 'devotional')
        .eq('item_id', devotionalId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('community_reactions').insert({
        'item_type': 'devotional',
        'item_id': devotionalId,
        'user_id': userId,
        'reaction': reaction,
        'tenant_id': SupabaseConstants.currentTenantId,
      });
      return;
    }

    final currentReaction = existing['reaction']?.toString();
    if (currentReaction == reaction) return;

    await _supabase
        .from('community_reactions')
        .update({'reaction': reaction})
        .eq('item_type', 'devotional')
        .eq('item_id', devotionalId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  Future<void> removeDevotionalReaction(String devotionalId) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final existing = await _supabase
        .from('community_reactions')
        .select('id')
        .eq('item_type', 'devotional')
        .eq('item_id', devotionalId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (existing == null) return;

    await _supabase
        .from('community_reactions')
        .delete()
        .eq('item_type', 'devotional')
        .eq('item_id', devotionalId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }
}
