import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/tag.dart';

/// Provider do repositório de tags
final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  return TagsRepository(Supabase.instance.client);
});

/// Repositório de tags
class TagsRepository {
  final SupabaseClient _supabase;

  TagsRepository(this._supabase);

  /// Buscar todas as tags
  Future<List<Tag>> getAllTags() async {
    try {
      final response = await _supabase
          .from('tag')
          .select('''
            *,
            member_tag(count)
          ''')
          .order('name', ascending: true);

      return (response as List).map((data) {
        final tagData = Map<String, dynamic>.from(data);
        
        // Contar membros
        if (tagData['member_tag'] != null) {
          final memberTags = tagData['member_tag'];
          if (memberTags is List && memberTags.isNotEmpty) {
            tagData['member_count'] = memberTags[0]['count'];
          } else {
            tagData['member_count'] = 0;
          }
        }
        
        return Tag.fromJson(tagData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar tag por ID
  Future<Tag?> getTagById(String id) async {
    try {
      final response = await _supabase
          .from('tag')
          .select('''
            *,
            member_tag(count)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final data = Map<String, dynamic>.from(response);
      
      if (data['member_tag'] != null) {
        final memberTags = data['member_tag'];
        if (memberTags is List && memberTags.isNotEmpty) {
          data['member_count'] = memberTags[0]['count'];
        } else {
          data['member_count'] = 0;
        }
      }

      return Tag.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar tag
  Future<Tag> createTag(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('tag')
          .insert(data)
          .select()
          .single();

      return Tag.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar tag
  Future<Tag> updateTag(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('tag')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return Tag.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar tag
  Future<void> deleteTag(String id) async {
    try {
      await _supabase.from('tag').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar tags de um membro
  Future<List<Tag>> getMemberTags(String memberId) async {
    try {
      final response = await _supabase
          .from('member_tag')
          .select('''
            tag_id,
            tag:tag_id (
              id,
              name,
              color,
              category,
              created_at
            )
          ''')
          .eq('user_id', memberId);

      return (response as List).map((data) {
        final tagData = data['tag'];
        return Tag.fromJson(tagData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar membros de uma tag
  Future<List<String>> getTagMembers(String tagId) async {
    try {
      final response = await _supabase
          .from('member_tag')
          .select('user_id')
          .eq('tag_id', tagId);

      return (response as List).map((data) => data['user_id'] as String).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Adicionar tag a um membro
  Future<void> addTagToMember(String memberId, String tagId) async {
    try {
      await _supabase.from('member_tag').insert({
        'user_id': memberId,
        'tag_id': tagId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Remover tag de um membro
  Future<void> removeTagFromMember(String memberId, String tagId) async {
    try {
      await _supabase
          .from('member_tag')
          .delete()
          .eq('user_id', memberId)
          .eq('tag_id', tagId);
    } catch (e) {
      rethrow;
    }
  }

  /// Contar total de tags
  Future<int> getTotalTagsCount() async {
    try {
      final response = await _supabase
          .from('tag')
          .select()
          .count();
      
      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar tags mais usadas
  Future<List<Tag>> getMostUsedTags({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('tag')
          .select('''
            *,
            member_tag(count)
          ''')
          .order('name', ascending: true);

      final tags = (response as List).map((data) {
        final tagData = Map<String, dynamic>.from(data);
        
        if (tagData['member_tag'] != null) {
          final memberTags = tagData['member_tag'];
          if (memberTags is List && memberTags.isNotEmpty) {
            tagData['member_count'] = memberTags[0]['count'];
          } else {
            tagData['member_count'] = 0;
          }
        }
        
        return Tag.fromJson(tagData);
      }).toList();

      // Ordenar por contagem de membros
      tags.sort((a, b) => (b.memberCount ?? 0).compareTo(a.memberCount ?? 0));

      return tags.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }
}
