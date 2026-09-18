import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/church_selector/presentation/providers/church_selector_provider.dart';
import '../../features/ministries/presentation/providers/ministries_provider.dart';
import '../../features/permissions/providers/permissions_providers.dart'
    hide supabaseClientProvider;
import '../data/repositories/more_menu_layout_repository.dart';
import '../domain/models/more_menu_item.dart';

/// Repositório do layout pessoal da aba "Mais" (F6).
final moreMenuLayoutRepositoryProvider = Provider<MoreMenuLayoutRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MoreMenuLayoutRepository(supabase);
});

/// Preferências cruas salvas pelo usuário atual: `item_key -> (visível, ordem)`.
///
/// `FutureProvider`, não `StreamProvider`: Realtime nunca foi habilitado por
/// migration neste projeto, então `onPostgresChanges` pode simplesmente nunca
/// disparar. Quem grava invalida ([saveMoreMenuLayoutProvider]).
final currentUserMoreMenuPreferencesProvider =
    FutureProvider<Map<String, MoreMenuPreference>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  final repository = ref.watch(moreMenuLayoutRepositoryProvider);
  return repository.getMyLayout(userId);
});

/// O layout resolvido: o registro cruzado com a preferência salva, na ordem
/// em que a aba Mais deve renderizar. **Sem aplicar gate** — cada item
/// continua embrulhado no gate dele lá na tela. Ordem nunca ressuscita item
/// negado.
///
/// Três regras que evitam falha silenciosa:
///
/// 1. Chave salva que não existe mais no registro é ignorada (item removido
///    do app numa versão futura). Sai de graça: a iteração é pelo registro.
/// 2. Chave do registro sem linha salva entra **no fim, visível** — senão um
///    card novo lançado depois ficaria invisível para todo mundo que já
///    configurou a tela uma vez, sem ninguém perceber.
/// 3. Quem nunca configurou nada recebe o registro inteiro na ordem canônica.
final moreMenuLayoutProvider =
    FutureProvider<List<(MoreMenuItem, bool)>>((ref) async {
  final prefs = await ref.watch(currentUserMoreMenuPreferencesProvider.future);
  if (prefs.isEmpty) {
    return [for (final item in kMoreMenuRegistry) (item, true)];
  }

  final salvos = <(MoreMenuItem, bool, int)>[];
  final novos = <(MoreMenuItem, bool)>[];
  for (final item in kMoreMenuRegistry) {
    final pref = prefs[item.key];
    if (pref == null) {
      novos.add((item, true));
    } else {
      salvos.add((item, pref.isVisible, pref.sortOrder));
    }
  }
  salvos.sort((a, b) => a.$3.compareTo(b.$3));

  return [
    for (final (item, isVisible, _) in salvos) (item, isVisible),
    ...novos,
  ];
});

/// As chaves que esta pessoa realmente pode ver, aplicando os mesmos gates do
/// `_MoreTab`.
///
/// Existe para a tela de configuração: oferecer "Liderança" a quem não tem
/// acesso ao Dashboard seria porta dos fundos — é exatamente o que a
/// `get_user_dashboard_widgets` evita do lado do Dashboard.
///
/// Erra para o lado de **esconder**: gate que não resolveu não entra.
final moreMenuAllowedKeysProvider = FutureProvider<Set<String>>((ref) async {
  final canAccessDashboard =
      await ref.watch(currentUserCanAccessDashboardProvider.future);
  final ministerios = await ref.watch(currentMemberMinistriesProvider.future);
  final hasMultipleUnits = await ref.watch(hasMultipleUnitsProvider.future);

  return {
    for (final item in kMoreMenuRegistry)
      if (switch (item.key) {
        'leadership' => canAccessDashboard,
        'my_ministries' => ministerios.isNotEmpty,
        'switch_church' => hasMultipleUnits,
        _ => true,
      })
        item.key,
  };
});

/// O que a tela de configuração lista: o layout resolvido, restrito ao que
/// esta pessoa vê de fato.
final moreMenuSettingsProvider =
    FutureProvider<List<(MoreMenuItem, bool)>>((ref) async {
  final layout = await ref.watch(moreMenuLayoutProvider.future);
  final allowed = await ref.watch(moreMenuAllowedKeysProvider.future);
  return [
    for (final entry in layout)
      if (allowed.contains(entry.$1.key)) entry,
  ];
});

void _invalidateMoreMenuChain(Ref ref) {
  // A dependência primeiro: `invalidate` recomputa o provider e seus
  // dependentes, nunca as dependências dele. Invalidar só a folha faria o
  // `await` cair no cache e nada iria ao banco.
  ref.invalidate(currentUserMoreMenuPreferencesProvider);
  ref.invalidate(moreMenuLayoutProvider);
  ref.invalidate(moreMenuSettingsProvider);
}

/// Grava a ordem escolhida na tela de configuração.
///
/// [visiveisNaTela] vem só com os itens que passaram pelo gate. Os demais são
/// anexados no fim, preservando o `is_visible` salvo, por um motivo concreto:
/// se fossem omitidos, as linhas antigas deles ficariam com `sort_order` dos
/// antigos índices e colidiriam com os novos. Uma pessoa que ganhe acesso ao
/// Dashboard depois veria "Liderança" numa posição arbitrária em vez do fim.
final saveMoreMenuLayoutProvider =
    Provider<Future<void> Function(List<(MoreMenuItem, bool)>)>((ref) {
  return (visiveisNaTela) async {
    final repository = ref.read(moreMenuLayoutRepositoryProvider);
    final prefs = await ref.read(currentUserMoreMenuPreferencesProvider.future);
    final naTela = {for (final (item, _) in visiveisNaTela) item.key};

    final resto = <(MoreMenuItem, bool)>[
      for (final item in kMoreMenuRegistry)
        if (!naTela.contains(item.key))
          (item, prefs[item.key]?.isVisible ?? true),
    ];

    await repository.saveLayout([...visiveisNaTela, ...resto]);
    _invalidateMoreMenuChain(ref);
  };
});

/// "Restaurar padrão": regrava o registro inteiro na ordem canônica, tudo
/// visível — o estado de quem nunca configurou nada.
final resetMoreMenuLayoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(moreMenuLayoutRepositoryProvider);
    await repository.saveLayout(
      [for (final item in kMoreMenuRegistry) (item, true)],
    );
    _invalidateMoreMenuChain(ref);
  };
});
