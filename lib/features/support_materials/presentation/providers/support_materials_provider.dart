import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/support_materials_repository.dart';
import '../../domain/models/support_material.dart';
import '../../domain/models/support_material_module.dart';
import '../../domain/models/support_material_link.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final supportMaterialsRepositoryProvider = Provider<SupportMaterialsRepository>((ref) {
  return SupportMaterialsRepository(Supabase.instance.client);
});

// =====================================================
// MATERIAIS PROVIDERS
// =====================================================

/// Provider para buscar todos os materiais
final allMaterialsProvider = FutureProvider<List<SupportMaterial>>((ref) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getAllMaterials();
});

/// Provider para buscar material por ID
final materialByIdProvider = FutureProvider.family<SupportMaterial?, String>((ref, id) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getMaterialById(id);
});

/// Provider para buscar materiais por categoria
final materialsByCategoryProvider = FutureProvider.family<List<SupportMaterial>, String>((ref, category) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getMaterialsByCategory(category);
});

/// Provider para buscar materiais por tipo
final materialsByTypeProvider = FutureProvider.family<List<SupportMaterial>, SupportMaterialType>((ref, type) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getMaterialsByType(type);
});

// =====================================================
// MÓDULOS PROVIDERS
// =====================================================

/// Provider para buscar módulos de um material
final modulesByMaterialProvider = FutureProvider.family<List<SupportMaterialModule>, String>((ref, materialId) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getModulesByMaterial(materialId);
});

/// Provider para buscar módulo por ID
final moduleByIdProvider = FutureProvider.family<SupportMaterialModule?, String>((ref, id) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getModuleById(id);
});

// =====================================================
// VINCULAÇÕES PROVIDERS
// =====================================================

/// Provider para buscar vinculações de um material
final linksByMaterialProvider = FutureProvider.family<List<SupportMaterialLink>, String>((ref, materialId) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getLinksByMaterial(materialId);
});

/// Provider para buscar materiais vinculados a uma entidade
final materialsByEntityProvider = FutureProvider.family<List<SupportMaterial>, ({MaterialLinkType linkType, String entityId})>((ref, params) async {
  final repository = ref.watch(supportMaterialsRepositoryProvider);
  return repository.getMaterialsByEntity(params.linkType, params.entityId);
});

