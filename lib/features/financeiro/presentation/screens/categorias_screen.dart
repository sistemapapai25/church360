// =====================================================
// CHURCH 360 - CATEGORIAS SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/categoria.dart';
import '../../../../core/design/community_design.dart';

class CategoriasScreen extends ConsumerWidget {
  const CategoriasScreen({super.key});

  // static const _financialGreen = Color(0xFF1D6E45); // Unused for now

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Categorias'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/financial');
              }
            },
          ),
        ),
        body: _buildBody(context, ref),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final categoriasAsync = ref.watch(categoriasHierarquicasProvider);

    return categoriasAsync.when(
      data: (categorias) => _buildCategoriasList(context, categorias),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar categorias: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasList(BuildContext context, List<Categoria> categorias) {
    if (categorias.isEmpty) {
      return const Center(
        child: Text('Nenhuma categoria encontrada'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final categoria = categorias[index];
        return _buildCategoriaCard(context, categoria);
      },
    );
  }

  Widget _buildCategoriaCard(BuildContext context, Categoria categoria) {
    final colorScheme = Theme.of(context).colorScheme;
    final tipoColor = categoria.tipo == TipoCategoria.despesa ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      child: ExpansionTile(
        leading: Icon(Icons.category, color: tipoColor),
        title: Text(
          categoria.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          categoria.tipo.label,
          style: TextStyle(fontSize: 12, color: tipoColor),
        ),
        children: [
          if (categoria.hasSubcategorias && categoria.subcategorias != null)
            ...categoria.subcategorias!.map((sub) {
              return ListTile(
                leading: const SizedBox(width: 24),
                title: Text(sub.name),
                dense: true,
              );
            }),
        ],
      ),
    );
  }
}

