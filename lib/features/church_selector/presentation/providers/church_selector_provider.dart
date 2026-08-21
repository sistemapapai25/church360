import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../branches/presentation/providers/branches_provider.dart';
import '../../data/church_selector_repository.dart';

final churchSelectorRepositoryProvider = Provider<ChurchSelectorRepository>((
  ref,
) {
  return ChurchSelectorRepository(Supabase.instance.client);
});

/// True quando o usuário tem vínculo em mais de uma unidade da rede —
/// controla a visibilidade do item "Trocar de igreja" na aba Mais.
final hasMultipleUnitsProvider = FutureProvider<bool>((ref) async {
  final units = await ref.watch(myNetworkUnitsProvider.future);
  return units.length > 1;
});
