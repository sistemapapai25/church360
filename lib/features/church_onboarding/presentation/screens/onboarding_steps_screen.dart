import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/providers/dashboard_widget_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../ministries/shared/domain/ministry_type_catalog.dart';
import '../../../ministries/shared/presentation/providers/ministry_type_catalog_providers.dart';
import '../../domain/onboarding_status.dart';
import '../providers/onboarding_provider.dart';
import '../../../../core/layout/readable_width.dart';

/// `/primeiros-passos` (F1): assistente por cima das telas que já existem.
/// Cada etapa abre a tela de sempre (ou uma folha curta) e o servidor detecta
/// sozinho quando ficou pronta; "Pular" marca à mão.
class OnboardingStepsScreen extends ConsumerWidget {
  const OnboardingStepsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(onboardingStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Primeiros passos')),
      body: ReadableWidth(child: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              AppErrorHandler.userMessage(e, feature: 'onboarding.status'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (status) => RefreshIndicator(
          onRefresh: () async => ref.refresh(onboardingStatusProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Progress(status: status),
              const SizedBox(height: 16),
              for (final step in OnboardingStep.values)
                _StepTile(step: step, done: status.isDone(step)),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  key: const ValueKey('toggle-dismissed'),
                  onPressed: () => _setStep(
                    context,
                    ref,
                    'dismissed',
                    !status.dismissed,
                  ),
                  child: Text(
                    status.dismissed
                        ? 'Voltar a mostrar na Dashboard'
                        : 'Esconder da Dashboard',
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

Future<void> _setStep(
  BuildContext context,
  WidgetRef ref,
  String step,
  bool done,
) async {
  try {
    await ref.read(onboardingRepositoryProvider).setStep(step, done);
    ref.invalidate(onboardingStatusProvider);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppErrorHandler.userMessage(e, feature: 'onboarding.set_step'),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.status});

  final OnboardingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.done
                  ? 'Tudo pronto! A igreja está configurada.'
                  : 'Deixe a igreja pronta para a sua equipe',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${status.doneCount} de ${status.total} etapas concluídas',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.doneCount / status.total,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends ConsumerWidget {
  const _StepTile({required this.step, required this.done});

  final OnboardingStep step;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('step-${step.code}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: done
                      ? Colors.green.withValues(alpha: 0.15)
                      : scheme.primaryContainer,
                  child: Icon(
                    done ? AppIcons.checkCircle : step.icon,
                    color: done ? Colors.green : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        step.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!done)
                  TextButton(
                    key: ValueKey('skip-${step.code}'),
                    onPressed: () => _setStep(context, ref, step.code, true),
                    child: const Text('Pular'),
                  ),
                FilledButton.tonal(
                  key: ValueKey('do-${step.code}'),
                  onPressed: () => _open(context, ref),
                  child: Text(done ? 'Rever' : step.ctaLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    switch (step) {
      case OnboardingStep.ministries:
        await _pickMinistries(context, ref);
      case OnboardingStep.pains:
        await _pickPains(context, ref);
      default:
        await context.push(step.route!);
    }
    // Voltou da tela de sempre: o servidor detecta o que mudou.
    ref.invalidate(onboardingStatusProvider);
  }
}

/// Folha dos ministérios: os tipos do catálogo oferecidos na criação, menos o
/// "Comum" (precisa de nome próprio: vai por /ministries/new). Cada marcado
/// vira um ministério pela RPC `create_ministry_with_leader`, com quem está
/// logado como líder.
Future<void> _pickMinistries(BuildContext context, WidgetRef ref) async {
  final catalog = await ref.read(ministryTypeCatalogProvider.future);
  final existing = await ref.read(allMinistriesProvider.future);
  if (!context.mounted) return;
  final taken = {for (final m in existing) m.ministryTypeCode};
  final options = [
    for (final t in catalog.offeredOnCreate)
      if (t.code != MinistryTypeCodes.generic && !taken.contains(t.code)) t,
  ];
  final picked = <String>{};

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quais ministérios a igreja já tem?',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (options.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Todos os ministérios do catálogo já existem.'),
                ),
              for (final t in options)
                CheckboxListTile(
                  key: ValueKey('ministry-${t.code}'),
                  value: picked.contains(t.code),
                  title: Text(t.label),
                  subtitle: t.description.isEmpty ? null : Text(t.description),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() {
                    v == true ? picked.add(t.code) : picked.remove(t.code);
                  }),
                ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  context.push('/ministries/new');
                },
                icon: const Icon(AppIcons.add),
                label: const Text('Criar outro ministério'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('create-ministries'),
                onPressed:
                    picked.isEmpty ? null : () => Navigator.pop(ctx, true),
                child: Text(
                  picked.isEmpty
                      ? 'Criar ministérios'
                      : 'Criar ${picked.length} ministério(s)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final repo = ref.read(ministriesRepositoryProvider);
  var created = 0;
  String? failure;
  for (final t in options.where((t) => picked.contains(t.code))) {
    try {
      await repo.createMinistryWithLeader(name: t.label, ministryType: t.code);
      created++;
    } catch (e) {
      failure = AppErrorHandler.userMessage(e, feature: 'ministries.create');
      break;
    }
  }
  ref.invalidate(allMinistriesProvider);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure ?? '$created ministério(s) criado(s). Você é o líder.',
      ),
    ),
  );
}

/// Folha das dores (F2): multi-escolha; salvar aplica o preset da Dashboard
/// no servidor e recarrega os cards.
Future<void> _pickPains(BuildContext context, WidgetRef ref) async {
  final status = await ref.read(onboardingStatusProvider.future);
  if (!context.mounted) return;
  final picked = {...status.pains};

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que você quer acompanhar mais de perto?',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Os cards dessas áreas vão para o topo da Dashboard. '
                'Nada é desligado; dá para mudar depois em Configurar Dashboard.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in kOnboardingPains)
                    FilterChip(
                      key: ValueKey('pain-${p.code}'),
                      avatar: Icon(p.icon, size: 18),
                      label: Text(p.label),
                      selected: picked.contains(p.code),
                      onSelected: (v) => setState(() {
                        v ? picked.add(p.code) : picked.remove(p.code);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('save-pains'),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    // Mantém a ordem da lista (a ordem das dores é a ordem dos cards).
    await ref.read(onboardingRepositoryProvider).setPains([
      for (final p in kOnboardingPains)
        if (picked.contains(p.code)) p.code,
    ]);
    ref.read(refreshDashboardWidgetsProvider)();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dashboard organizada pelas suas prioridades.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppErrorHandler.userMessage(e, feature: 'onboarding.set_pains'),
        ),
      ),
    );
  }
}
