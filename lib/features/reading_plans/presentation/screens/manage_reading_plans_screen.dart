import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/widgets/church_image.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/models/reading_plan.dart';
import '../providers/reading_plans_provider.dart';
import '../../../../core/layout/responsive_grid.dart';

class ManageReadingPlansScreen extends ConsumerWidget {
  const ManageReadingPlansScreen({super.key});

  /// C1: folha com os modelos prontos do catálogo da plataforma.
  static Future<void> openImportSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ImportTemplateSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allReadingPlansProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Gerenciar Planos de Leitura',
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.download),
            onPressed: () => openImportSheet(context),
            tooltip: 'Importar modelo',
          ),
          IconButton(
            icon: const Icon(AppIcons.add),
            onPressed: () => context.push('/reading-plans/admin/new'),
            tooltip: 'Novo plano',
          ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.book,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum plano cadastrado',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crie um plano para aparecer no app.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/reading-plans/admin/new'),
                      icon: const Icon(AppIcons.add),
                      label: const Text('Criar primeiro plano'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => openImportSheet(context),
                      icon: const Icon(AppIcons.download),
                      label: const Text('Importar modelo'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allReadingPlansProvider);
              ref.invalidate(activeReadingPlansProvider);
            },
            child: ResponsiveGridList(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              gap: 12,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final cs = Theme.of(context).colorScheme;
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 0,
                    ),
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child:
                            plan.imageUrl != null && plan.imageUrl!.isNotEmpty
                            ? ChurchImage(
                                imageUrl: plan.imageUrl!,
                                type: ChurchImageType.card,
                              )
                            : Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.menu_book,
                                  color: cs.primary.withValues(alpha: 0.6),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(
                            label: plan.categoryText,
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                          ),
                          _Chip(
                            label: plan.durationText,
                            backgroundColor: cs.surfaceContainerHighest,
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                          plan.isActive
                              ? const StatusBadge.active(
                                  label: 'Ativo',
                                  icon: AppIcons.visibility,
                                )
                              : const StatusBadge.dropped(
                                  label: 'Inativo',
                                  icon: AppIcons.visibilityOff,
                                ),
                        ],
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: Icon(
                            plan.isActive
                                ? AppIcons.visibility
                                : AppIcons.visibilityOff,
                            size: 20,
                          ),
                          tooltip: plan.isActive ? 'Desativar' : 'Ativar',
                          onPressed: () async {
                            final repo = ref.read(
                              readingPlansRepositoryProvider,
                            );
                            try {
                              await repo.updatePlan(plan.id, {
                                'status': plan.isActive ? 'inactive' : 'active',
                              });
                              ref.invalidate(allReadingPlansProvider);
                              ref.invalidate(activeReadingPlansProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      plan.isActive
                                          ? 'Plano desativado!'
                                          : 'Plano ativado!',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              AppErrorHandler.showSnackBar(
                                context,
                                e,
                                feature: 'reading_plans.admin.toggle_active',
                                fallbackMessage:
                                    'Nao foi possivel atualizar o plano. Tente novamente.',
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(AppIcons.edit, size: 20),
                          tooltip: 'Editar',
                          onPressed: () {
                            context.push(
                              '/reading-plans/admin/${plan.id}/edit',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(AppIcons.delete, size: 20),
                          tooltip: 'Excluir',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmar exclusão'),
                                content: Text(
                                  'Deseja realmente excluir o plano "${plan.title}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            final repo = ref.read(
                              readingPlansRepositoryProvider,
                            );
                            try {
                              await repo.deletePlan(plan.id);
                              ref.invalidate(allReadingPlansProvider);
                              ref.invalidate(activeReadingPlansProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Plano excluído!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              AppErrorHandler.showSnackBar(
                                context,
                                e,
                                feature: 'reading_plans.admin.delete_plan',
                                fallbackMessage:
                                    'Nao foi possivel excluir o plano. Tente novamente.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                AppErrorHandler.userMessage(
                  error,
                  feature: 'reading_plans.admin.load_plans',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allReadingPlansProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modelos prontos (C1): um por linha, "Importar" ou "Importado".
class _ImportTemplateSheet extends ConsumerStatefulWidget {
  const _ImportTemplateSheet();

  @override
  ConsumerState<_ImportTemplateSheet> createState() =>
      _ImportTemplateSheetState();
}

class _ImportTemplateSheetState extends ConsumerState<_ImportTemplateSheet> {
  String? _importing;

  Future<void> _import(ReadingPlanTemplate template) async {
    setState(() => _importing = template.code);
    final repo = ref.read(readingPlansRepositoryProvider);
    try {
      await repo.importTemplate(template.code);
      ref.invalidate(allReadingPlansProvider);
      ref.invalidate(activeReadingPlansProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plano "${template.title}" importado e ativo.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = null);
      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'reading_plans.admin.import_template',
        fallbackMessage: 'Nao foi possivel importar o modelo. Tente novamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(readingPlanTemplatesProvider);
    final imported = ref
            .watch(allReadingPlansProvider)
            .valueOrNull
            ?.map((p) => p.templateCode)
            .whereType<String>()
            .toSet() ??
        const <String>{};
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importar modelo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Planos prontos da plataforma. O plano importado é da igreja: '
              'dá para editar, desativar ou excluir.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            templatesAsync.when(
              data: (templates) {
                if (templates.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nenhum modelo disponível.'),
                  );
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      final done = imported.contains(t.code);
                      final busy = _importing == t.code;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(AppIcons.book, color: cs.primary),
                        title: Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            '${t.durationDays} dias',
                            t.categoryText,
                            if (t.description != null) t.description!,
                          ].join(' · '),
                        ),
                        trailing: done
                            ? const StatusBadge.active(
                                label: 'Importado',
                                icon: AppIcons.check,
                              )
                            : busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : FilledButton(
                                onPressed: _importing == null
                                    ? () => _import(t)
                                    : null,
                                child: const Text('Importar'),
                              ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  AppErrorHandler.userMessage(
                    error,
                    feature: 'reading_plans.admin.load_templates',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _Chip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}
