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
      final created = await repo.createBeneficiario(
        Beneficiario(
          id: const Uuid().v4(),
          name: data['name'] as String,
          documento: data['documento'] as String?,
          phone: data['phone'] as String?,
          email: data['email'] as String?,
          observacoes: data['observacoes'] as String?,
          createdAt: DateTime.now(),
          tenantId: SupabaseConstants.currentTenantId,
        ),
      );
      ref.invalidate(allBeneficiariosProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beneficiário criado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return created;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar beneficiário: $e')),
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
        );
      },
    );

    if (data == null) return null;

    // Convert string tipo to TipoCategoria enum
    final tipoStr = data['tipo'] as String;
    final tipoCategoria = tipoStr == 'DESPESA' ? TipoCategoria.despesa : TipoCategoria.receita;

    try {
      final repo = ref.read(categoriasRepositoryProvider);
      final created = await repo.createCategoria(
        Categoria(
          id: const Uuid().v4(),
          name: data['name'] as String,
          tipo: tipoCategoria,
          ordem: 0,
          createdAt: DateTime.now(),
          tenantId: SupabaseConstants.currentTenantId,
        ),
      );
      ref.invalidate(categoriasByTipoProvider(tipoCategoria));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categoria criada com sucesso!'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      return created;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar categoria: $e')),
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
      final created = await repo.createConta(
        ContaFinanceira(
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
        ),
      );
      ref.invalidate(allContasProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso!'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      return created;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar conta: $e')),
        );
      }
      return null;
    }
  }
}
