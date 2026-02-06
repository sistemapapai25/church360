// =====================================================
// CHURCH 360 - FINANCIAL PROVIDERS (RIVERPOD)
// =====================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/lancamentos_repository.dart';
import '../../data/categorias_repository.dart';
import '../../data/beneficiarios_repository.dart';
import '../../data/contas_repository.dart';
import '../../domain/models/lancamento.dart';
import '../../domain/models/categoria.dart';
import '../../domain/models/beneficiario.dart';
import '../../domain/models/conta_financeira.dart';
import '../../domain/models/dashboard_data.dart';

// =====================================================
// REPOSITORY PROVIDERS
// =====================================================

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final lancamentosRepositoryProvider = Provider<LancamentosRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LancamentosRepository(supabase);
});

final categoriasRepositoryProvider = Provider<CategoriasRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CategoriasRepository(supabase);
});

final beneficiariosRepositoryProvider = Provider<BeneficiariosRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return BeneficiariosRepository(supabase);
});

final contasRepositoryProvider = Provider<ContasRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ContasRepository(supabase);
});

// =====================================================
// DATA PROVIDERS
// =====================================================

/// Provider: Todos os lançamentos
final allLancamentosProvider = FutureProvider.autoDispose<List<Lancamento>>((ref) async {
  final repo = ref.watch(lancamentosRepositoryProvider);
  return repo.getAllLancamentos();
});

/// Provider: Lançamentos com filtros
final filteredLancamentosProvider = FutureProvider.autoDispose.family<
    List<Lancamento>,
    LancamentosFilter
>((ref, filter) async {
  final repo = ref.watch(lancamentosRepositoryProvider);
  return repo.getAllLancamentos(
    startDate: filter.startDate,
    endDate: filter.endDate,
    tipo: filter.tipo,
    status: filter.status,
    categoriaId: filter.categoriaId,
    beneficiarioId: filter.beneficiarioId,
    contaId: filter.contaId,
  );
});

/// Provider: Lançamentos vencidos
final lancamentosVencidosProvider = FutureProvider.autoDispose<List<Lancamento>>((ref) async {
  final repo = ref.watch(lancamentosRepositoryProvider);
  return repo.getLancamentosVencidos();
});

/// Provider: Lançamento por ID
final lancamentoByIdProvider = FutureProvider.autoDispose.family<Lancamento?, String>((ref, id) async {
  final repo = ref.watch(lancamentosRepositoryProvider);
  return repo.getLancamentoById(id);
});

/// Provider: Todas as categorias
final allCategoriasProvider = FutureProvider.autoDispose<List<Categoria>>((ref) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.getAllCategorias();
});

/// Provider: Categorias por tipo
final categoriasByTipoProvider = FutureProvider.autoDispose.family<
    List<Categoria>,
    TipoCategoria
>((ref, tipo) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.getAllCategorias(tipo: tipo);
});

/// Provider: Categorias hierárquicas
final categoriasHierarquicasProvider = FutureProvider.autoDispose<List<Categoria>>((ref) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.getCategoriasHierarquicas();
});

/// Provider: Categoria por ID
final categoriaByIdProvider = FutureProvider.autoDispose.family<Categoria?, String>((ref, id) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.getCategoriaById(id);
});

/// Provider: Todos os beneficiários
final allBeneficiariosProvider = FutureProvider.autoDispose<List<Beneficiario>>((ref) async {
  final repo = ref.watch(beneficiariosRepositoryProvider);
  return repo.getAllBeneficiarios();
});

/// Provider: Beneficiário por ID
final beneficiarioByIdProvider = FutureProvider.autoDispose.family<Beneficiario?, String>((ref, id) async {
  final repo = ref.watch(beneficiariosRepositoryProvider);
  return repo.getBeneficiarioById(id);
});

/// Provider: Buscar beneficiários por nome
final searchBeneficiariosProvider = FutureProvider.autoDispose.family<
    List<Beneficiario>,
    String
>((ref, searchTerm) async {
  final repo = ref.watch(beneficiariosRepositoryProvider);
  return repo.searchBeneficiariosByName(searchTerm);
});

/// Provider: Todas as contas
final allContasProvider = FutureProvider.autoDispose<List<ContaFinanceira>>((ref) async {
  final repo = ref.watch(contasRepositoryProvider);
  return repo.getAllContas();
});

/// Provider: Conta por ID
final contaByIdProvider = FutureProvider.autoDispose.family<ContaFinanceira?, String>((ref, id) async {
  final repo = ref.watch(contasRepositoryProvider);
  return repo.getContaById(id);
});

/// Provider: Dados do dashboard
final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final repo = ref.watch(contasRepositoryProvider);
  return repo.getDashboardData();
});

/// Provider: Dados do dashboard com filtro de período
final dashboardDataByPeriodProvider = FutureProvider.autoDispose.family<
    DashboardData,
    DashboardPeriodFilter
>((ref, filter) async {
  final repo = ref.watch(contasRepositoryProvider);
  return repo.getDashboardData(
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

// =====================================================
// FILTER MODELS
// =====================================================

/// Filtro para lançamentos
class LancamentosFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final TipoLancamento? tipo;
  final StatusLancamento? status;
  final String? categoriaId;
  final String? beneficiarioId;
  final String? contaId;

  const LancamentosFilter({
    this.startDate,
    this.endDate,
    this.tipo,
    this.status,
    this.categoriaId,
    this.beneficiarioId,
    this.contaId,
  });
}

/// Filtro para dashboard por período
class DashboardPeriodFilter {
  final DateTime? startDate;
  final DateTime? endDate;

  const DashboardPeriodFilter({
    this.startDate,
    this.endDate,
  });
}

