import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/ministry_type_catalog_repository.dart';
import '../../domain/ministry_type_catalog.dart';

final ministryTypeCatalogRepositoryProvider =
    Provider<MinistryTypeCatalogRepository>((ref) {
      return MinistryTypeCatalogRepository(Supabase.instance.client);
    });

/// O catálogo vindo do banco.
///
/// Uma consulta por sessão: a tabela só muda por migration, então não há o que
/// invalidar em runtime. Quem precisa do catálogo dentro de um `build` usa o
/// [ministryTypeCatalogSyncProvider] abaixo, que já resolve o "ainda não
/// chegou".
final ministryTypeCatalogProvider = FutureProvider<MinistryTypeCatalog>((
  ref,
) async {
  final repo = ref.watch(ministryTypeCatalogRepositoryProvider);
  final catalog = await repo.fetch();
  // Catálogo vazio é falha de leitura disfarçada — RLS, tabela ausente num
  // restore, filtro que não casou. Devolver vazio deixaria todo ministério
  // sem aba nenhuma, então o fallback embutido vale mais.
  if (catalog.types.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'ministry_type: catálogo voltou vazio do banco; usando o embutido.',
      );
    }
    return MinistryTypeCatalog.fallback;
  }
  return catalog;
});

/// O catálogo para quem precisa dele já, dentro de um `build`.
///
/// Enquanto a consulta não volta — e se ela falhar — devolve
/// [MinistryTypeCatalog.fallback], que é cópia do seed da migration. Assim a
/// tela abre com as abas certas no primeiro frame e não pisca; quando o banco
/// responde, o provider reconstrói com o que ele disser.
///
/// É por isso que o app não trava se a tabela sumir: ele fica um passo atrás
/// do banco, nunca sem catálogo.
final ministryTypeCatalogSyncProvider = Provider<MinistryTypeCatalog>((ref) {
  return ref
      .watch(ministryTypeCatalogProvider)
      .maybeWhen(
        data: (catalog) => catalog,
        orElse: () => MinistryTypeCatalog.fallback,
      );
});
