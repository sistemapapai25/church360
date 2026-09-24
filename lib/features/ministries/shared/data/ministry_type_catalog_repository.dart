import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ministry_type_catalog.dart';

/// Leitura do catálogo `public.ministry_type`.
///
/// Só leitura, e não por descuido: a tabela não tem policy de escrita e os
/// grants de INSERT/UPDATE/DELETE foram revogados de `anon` e de
/// `authenticated` na migration `20260924000200`. Ela muda por migration.
///
/// Sem filtro de tenant, também de propósito: o catálogo é global (não tem
/// coluna `tenant_id`). Ele descreve o que o app sabe montar, não dado de
/// igreja — a justificativa longa está no cabeçalho da migration.
class MinistryTypeCatalogRepository {
  final SupabaseClient _supabase;

  MinistryTypeCatalogRepository(this._supabase);

  Future<MinistryTypeCatalog> fetch() async {
    final rows = await _supabase
        .from('ministry_type')
        .select(
          'code, label, description, tabs, route_suffix, '
          'offered_on_create, sort_order',
        )
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return MinistryTypeCatalog.fromRows(
      (rows as List).cast<Map<String, dynamic>>(),
    );
  }
}
