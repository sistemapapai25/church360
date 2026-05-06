import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../domain/models/beneficiario.dart';
import '../../domain/models/categoria.dart';
import '../../domain/models/conta_financeira.dart';
import '../providers/financeiro_providers.dart';
import 'quick_account_form.dart';
import 'quick_beneficiary_form.dart';
import 'quick_category_form.dart';
import '../../../../core/errors/app_error_handler.dart';

class FinanceiroQuickCreate {
  static Future<Beneficiario?> createBeneficiario(
    BuildContext context,
    WidgetRef ref, {
    String? initialName,
  }) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return QuickBeneficiaryForm(
          onSave: (data) => Navigator.of(context).pop(data),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );

    if (data == null) return null;

    try {
      final repo = ref.read(beneficiariosRepositoryProvider);
      final candidate = Beneficiario(
        id: const Uuid().v4(),
        name: data['name'] as String,
        documento: data['documento'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        observacoes: data['observacoes'] as String?,
        createdAt: DateTime.now(),
        tenantId: SupabaseConstants.currentTenantId,
      );

      final created = await repo.createBeneficiario(
        candidate,
        returnCreatedRow: true,
      );
      ref.invalidate(allBeneficiariosProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created.id == candidate.id
                  ? 'Beneficiário criado com sucesso!'
                  : 'Este beneficiário já existia. Selecionamos o existente.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      return created;
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.quick_create.beneficiary',
          fallbackMessage:
              'Nao foi possivel criar o beneficiario. ${e.toString()}',
        );
      }
      return null;
    }
  }

  static Future<Beneficiario?> editBeneficiario(
    BuildContext context,
    WidgetRef ref, {
    required Beneficiario beneficiario,
  }) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return QuickBeneficiaryForm(
          title: 'Editar Beneficiário',
          initialData: {
            'name': beneficiario.name,
            'documento': beneficiario.documento,
            'phone': beneficiario.phone,
            'email': beneficiario.email,
            'observacoes': beneficiario.observacoes,
          },
          onSave: (data) => Navigator.of(context).pop(data),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );

    if (data == null) return null;

    try {
      final repo = ref.read(beneficiariosRepositoryProvider);
      final updated = beneficiario.copyWith(
        name: (data['name'] as String).trim(),
        documento: data['documento'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        observacoes: data['observacoes'] as String?,
      );
      await repo.updateBeneficiario(updated);
      ref.invalidate(allBeneficiariosProvider);
      return updated;
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.quick_edit.beneficiary',
          fallbackMessage: 'Nao foi possivel editar o beneficiario. ${e.toString()}',
        );
      }
      return null;
    }
  }

  static Future<Categoria?> createCategoria(
    BuildContext context,
    WidgetRef ref, {
    required TipoCategoria tipo,
    String? initialName,
  }) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return QuickCategoryForm(
          onSave: (data) => Navigator.of(context).pop(data),
          onCancel: () => Navigator.of(context).pop(),
          fixedTipo: tipo == TipoCategoria.receita ? 'RECEITA' : 'DESPESA',
        );
      },
    );

    if (data == null) return null;

    // Forçar o tipo conforme a tela de lançamento (evita criar RECEITA e tentar selecionar em DESPESA, e vice-versa).
    final tipoCategoria = tipo;

    try {
      final repo = ref.read(categoriasRepositoryProvider);
      final candidate = Categoria(
        id: const Uuid().v4(),
        name: data['name'] as String,
        tipo: tipoCategoria,
        ordem: 0,
        createdAt: DateTime.now(),
        tenantId: SupabaseConstants.currentTenantId,
      );

      final created = await repo.createCategoria(
        candidate,
        returnCreatedRow: true,
      );
      ref.invalidate(categoriasByTipoProvider(tipoCategoria));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created.id == candidate.id
                  ? 'Categoria criada com sucesso!'
                  : 'Esta categoria já existia. Selecionamos a existente.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }

      return created;
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.quick_create.category',
          fallbackMessage:
              'Nao foi possivel criar a categoria. ${e.toString()}',
        );
      }
      return null;
    }
  }

  static Future<Categoria?> editCategoria(
    BuildContext context,
    WidgetRef ref, {
    required Categoria categoria,
    required TipoCategoria fixedTipo,
  }) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return QuickCategoryForm(
          title: 'Editar Categoria',
          fixedTipo: fixedTipo == TipoCategoria.receita ? 'RECEITA' : 'DESPESA',
          initialData: {
            'name': categoria.name,
            'tipo': fixedTipo == TipoCategoria.receita ? 'RECEITA' : 'DESPESA',
          },
          onSave: (data) => Navigator.of(context).pop(data),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );

    if (data == null) return null;

    try {
      final repo = ref.read(categoriasRepositoryProvider);
      final updated = categoria.copyWith(
        name: (data['name'] as String).trim(),
        tipo: fixedTipo,
      );
      await repo.updateCategoria(updated);
      ref.invalidate(categoriasByTipoProvider(fixedTipo));
      return updated;
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.quick_edit.category',
          fallbackMessage: 'Nao foi possivel editar a categoria. ${e.toString()}',
        );
      }
      return null;
    }
  }

  static Future<ContaFinanceira?> createConta(
    BuildContext context,
    WidgetRef ref, {
    String? initialName,
    String? initialInstituicao,
  }) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return QuickAccountForm(
          onSave: (data) => Navigator.of(context).pop(data),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );

    if (data == null) return null;

    final saldo = (data['saldo_inicial'] as double?) ?? 0.0;

    try {
      final repo = ref.read(contasRepositoryProvider);
      final candidate = ContaFinanceira(
        id: const Uuid().v4(),
        nome: data['nome'] as String,
        tipo: data['tipo'] as String,
        instituicao: data['instituicao'] as String?,
        agencia: data['agencia'] as String?,
        numero: data['numero'] as String?,
        saldoInicial: saldo,
        saldoInicialEm: saldo > 0 ? DateTime.now() : null,
        createdAt: DateTime.now(),
        tenantId: SupabaseConstants.currentTenantId,
      );
      final created = await repo.createConta(candidate, returnCreatedRow: true);
      ref.invalidate(allContasProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created.id == candidate.id
                  ? 'Conta criada com sucesso!'
                  : 'Esta conta já existia. Selecionamos a existente.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      return created;
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.quick_create.account',
          fallbackMessage: 'Nao foi possivel criar a conta. ${e.toString()}',
        );
      }
      return null;
    }
  }

  static Future<ContaFinanceira?> editConta(
    BuildContext context,
    WidgetRef ref, {
    required ContaFinanceira conta,
  }) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return QuickAccountForm(
          title: 'Editar Conta Financeira',
          initialData: {
            'nome': conta.nome,
            'tipo': conta.tipo,
            'instituicao': conta.instituicao,
            'agencia': conta.agencia,
            'numero': conta.numero,
            'saldo_inicial': conta.saldoInicial,
          },
          onSave: (data) => Navigator.of(context).pop(data),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );

    if (data == null) return null;

    try {
      final repo = ref.read(contasRepositoryProvider);
      final saldo = (data['saldo_inicial'] as double?) ?? conta.saldoInicial;
      final updated = conta.copyWith(
        nome: (data['nome'] as String).trim(),
        tipo: (data['tipo'] as String).trim(),
        instituicao: data['instituicao'] as String?,
        agencia: data['agencia'] as String?,
        numero: data['numero'] as String?,
        saldoInicial: saldo,
      );
      await repo.updateConta(updated);
      ref.invalidate(allContasProvider);
      return updated;
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.quick_edit.account',
          fallbackMessage: 'Nao foi possivel editar a conta. ${e.toString()}',
        );
      }
      return null;
    }
  }
}
