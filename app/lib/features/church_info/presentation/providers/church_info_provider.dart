import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/church_info_repository.dart';
import '../../domain/models/church_info.dart';

/// Provider do repository de informações da igreja
final churchInfoRepositoryProvider = Provider<ChurchInfoRepository>((ref) {
  return ChurchInfoRepository(Supabase.instance.client);
});

/// Provider de informações da igreja
final churchInfoProvider = FutureProvider<ChurchInfo?>((ref) async {
  final repo = ref.watch(churchInfoRepositoryProvider);
  return repo.getChurchInfo();
});

