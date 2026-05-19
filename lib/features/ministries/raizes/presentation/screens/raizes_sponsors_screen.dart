import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/raizes_sponsor_profile.dart';
import '../providers/raizes_dashboard_provider.dart';
import '../providers/raizes_sponsors_provider.dart';

/// CRUD de perfis de padrinho/madrinha do Raízes (Lote MR4C.3).
///
/// Lista os padrinhos cadastrados (ativos primeiro). FAB abre bottom sheet
/// de criação; tap em card abre o mesmo bottom sheet em modo edição.
class RaizesSponsorsScreen extends ConsumerWidget {
  final String ministryId;

  const RaizesSponsorsScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'raizes.manage_recommendations',
      submoduleLabel: 'Padrinhos',
      builder: (context) => _SponsorsContent(ministryId: ministryId),
    );
  }
}

class _SponsorsContent extends ConsumerStatefulWidget {
  final String ministryId;
  const _SponsorsContent({required this.ministryId});

  @override
  ConsumerState<_SponsorsContent> createState() => _SponsorsContentState();
}

class _SponsorsContentState extends ConsumerState<_SponsorsContent> {
  Future<void> _openForm({RaizesSponsorProfile? editing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SponsorFormSheet(
        ministryId: widget.ministryId,
        editing: editing,
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(raizesSponsorsProvider(widget.ministryId));
      ref.invalidate(
        raizesEligibleSponsorCandidatesProvider(widget.ministryId),
      );
    }
  }

  Future<void> _toggleActive(RaizesSponsorProfile sponsor) async {
    try {
      final repo = ref.read(raizesRepositoryProvider);
      await repo.updateSponsorProfile(
        id: sponsor.id,
        isActive: !sponsor.isActive,
      );
      if (!mounted) return;
      ref.invalidate(raizesSponsorsProvider(widget.ministryId));
    } catch (e) {
      _showError('Erro ao alterar status: $e');
    }
  }

  Future<void> _delete(RaizesSponsorProfile sponsor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover padrinho?'),
        content: Text(
          'Tem certeza que quer remover ${sponsor.displayName}? Isso apaga '
          'também as indicações geradas a partir deste perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final repo = ref.read(raizesRepositoryProvider);
      await repo.deleteSponsorProfile(sponsor.id);
      if (!mounted) return;
      ref.invalidate(raizesSponsorsProvider(widget.ministryId));
      ref.invalidate(
        raizesEligibleSponsorCandidatesProvider(widget.ministryId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Padrinho removido.')),
      );
    } catch (e) {
      _showError('Erro ao remover: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sponsorsAsync = ref.watch(raizesSponsorsProvider(widget.ministryId));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Padrinhos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo padrinho'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(raizesSponsorsProvider(widget.ministryId));
          await ref.read(raizesSponsorsProvider(widget.ministryId).future);
        },
        child: sponsorsAsync.when(
          data: (sponsors) {
            if (sponsors.isEmpty) {
              return _EmptyState(onAdd: () => _openForm());
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: sponsors.length,
              itemBuilder: (context, i) => _SponsorCard(
                sponsor: sponsors[i],
                onEdit: () => _openForm(editing: sponsors[i]),
                onToggleActive: () => _toggleActive(sponsors[i]),
                onDelete: () => _delete(sponsors[i]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(raizesSponsorsProvider(widget.ministryId)),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// Card de listagem
// =====================================================

class _SponsorCard extends StatelessWidget {
  final RaizesSponsorProfile sponsor;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SponsorCard({
    required this.sponsor,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photo = (sponsor.userPhotoUrl ?? '').trim();
    final criteriaChips = _buildCriteriaSummary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        color: sponsor.isActive
            ? null
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(CommunityDesign.radius),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primary.withValues(alpha: 0.1),
                      backgroundImage:
                          photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? Text(
                              sponsor.initial,
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sponsor.displayName,
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (!sponsor.isActive)
                            Text(
                              'Inativo',
                              style: CommunityDesign.metaStyle(context)
                                  .copyWith(color: cs.error),
                            ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: sponsor.isActive,
                      onChanged: (_) => onToggleActive(),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Ações',
                      onSelected: (v) {
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Remover'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (criteriaChips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: criteriaChips,
                  ),
                ],
                if ((sponsor.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sponsor.notes!.trim(),
                    style: CommunityDesign.metaStyle(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCriteriaSummary(BuildContext context) {
    final chips = <Widget>[];

    if (sponsor.minAge != null || sponsor.maxAge != null) {
      final min = sponsor.minAge?.toString() ?? '0';
      final max = sponsor.maxAge?.toString() ?? '∞';
      chips.add(_CriteriaChip(label: 'Idade $min–$max', color: Colors.blue));
    }

    for (final g in sponsor.genders) {
      chips.add(_CriteriaChip(
        label: SponsorCriteriaOptions.genders[g] ?? g,
        color: Colors.pink,
      ));
    }

    for (final m in sponsor.maritalStatuses) {
      chips.add(_CriteriaChip(
        label: SponsorCriteriaOptions.maritalStatuses[m] ?? m,
        color: Colors.purple,
      ));
    }

    for (final l in sponsor.lifeStages) {
      chips.add(_CriteriaChip(
        label: SponsorCriteriaOptions.lifeStages[l] ?? l,
        color: Colors.teal,
      ));
    }

    for (final i in sponsor.interests) {
      chips.add(_CriteriaChip(label: i, color: Colors.amber.shade800));
    }

    return chips;
  }
}

class _CriteriaChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CriteriaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =====================================================
// Bottom sheet de criação / edição
// =====================================================

class _SponsorFormSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final RaizesSponsorProfile? editing;

  const _SponsorFormSheet({
    required this.ministryId,
    this.editing,
  });

  @override
  ConsumerState<_SponsorFormSheet> createState() => _SponsorFormSheetState();
}

class _SponsorFormSheetState extends ConsumerState<_SponsorFormSheet> {
  String? _selectedUserId;
  String? _selectedUserLabel;
  final _minAgeCtrl = TextEditingController();
  final _maxAgeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final Set<String> _genders = {};
  final Set<String> _maritalStatuses = {};
  final Set<String> _lifeStages = {};
  final List<String> _interests = [];
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _selectedUserId = e.userId;
      _selectedUserLabel = e.displayName;
      _minAgeCtrl.text = e.minAge?.toString() ?? '';
      _maxAgeCtrl.text = e.maxAge?.toString() ?? '';
      _notesCtrl.text = e.notes ?? '';
      _genders.addAll(e.genders);
      _maritalStatuses.addAll(e.maritalStatuses);
      _lifeStages.addAll(e.lifeStages);
      _interests.addAll(e.interests);
      _isActive = e.isActive;
    }
  }

  @override
  void dispose() {
    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    _notesCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  void _addInterest() {
    final raw = _interestCtrl.text.trim();
    if (raw.isEmpty) return;
    if (_interests.map((e) => e.toLowerCase()).contains(raw.toLowerCase())) {
      _interestCtrl.clear();
      return;
    }
    setState(() {
      _interests.add(raw);
      _interestCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um membro do ministério.')),
      );
      return;
    }
    final minAge = int.tryParse(_minAgeCtrl.text.trim());
    final maxAge = int.tryParse(_maxAgeCtrl.text.trim());
    if (minAge != null && maxAge != null && minAge > maxAge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Idade mínima maior que a máxima.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(raizesRepositoryProvider);
      if (_isEdit) {
        // Edição: use patchSponsorProfile com payload explícito para permitir
        // null em min_age/max_age e notes vazio.
        final payload = <String, dynamic>{
          'min_age': minAge,
          'max_age': maxAge,
          'marital_statuses': _maritalStatuses.toList(),
          'genders': _genders.toList(),
          'life_stages': _lifeStages.toList(),
          'interests': _interests,
          'is_active': _isActive,
          'notes': _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        };
        await repo.patchSponsorProfile(
          id: widget.editing!.id,
          payload: payload,
        );
      } else {
        await repo.createSponsorProfile(
          ministryId: widget.ministryId,
          userId: _selectedUserId!,
          minAge: minAge,
          maxAge: maxAge,
          maritalStatuses: _maritalStatuses.toList(),
          genders: _genders.toList(),
          lifeStages: _lifeStages.toList(),
          interests: _interests,
          isActive: _isActive,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEdit ? 'Editar padrinho' : 'Novo padrinho',
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              if (_isEdit)
                _ReadOnlyField(
                  label: 'Membro',
                  value: _selectedUserLabel ?? '—',
                )
              else
                _CandidatePicker(
                  ministryId: widget.ministryId,
                  selectedUserId: _selectedUserId,
                  onSelected: (id, label) {
                    setState(() {
                      _selectedUserId = id;
                      _selectedUserLabel = label;
                    });
                  },
                ),
              const SizedBox(height: 16),
              Text(
                'Idade preferida (opcional)',
                style: CommunityDesign.metaStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minAgeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mínima',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxAgeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Máxima',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MultiChipField(
                label: 'Gênero',
                options: SponsorCriteriaOptions.genders,
                selected: _genders,
                onChanged: (s) => setState(() {
                  _genders
                    ..clear()
                    ..addAll(s);
                }),
              ),
              const SizedBox(height: 12),
              _MultiChipField(
                label: 'Estado civil',
                options: SponsorCriteriaOptions.maritalStatuses,
                selected: _maritalStatuses,
                onChanged: (s) => setState(() {
                  _maritalStatuses
                    ..clear()
                    ..addAll(s);
                }),
              ),
              const SizedBox(height: 12),
              _MultiChipField(
                label: 'Etapa de vida',
                options: SponsorCriteriaOptions.lifeStages,
                selected: _lifeStages,
                onChanged: (s) => setState(() {
                  _lifeStages
                    ..clear()
                    ..addAll(s);
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Interesses',
                style: CommunityDesign.metaStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _interestCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: filhos, música, finanças...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addInterest(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _addInterest,
                    icon: const Icon(Icons.add),
                    tooltip: 'Adicionar interesse',
                  ),
                ],
              ),
              if (_interests.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _interests
                      .map(
                        (i) => InputChip(
                          label: Text(i),
                          onDeleted: () =>
                              setState(() => _interests.remove(i)),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Ativo'),
                subtitle: Text(
                  'Apenas perfis ativos participam da geração de sugestões.',
                  style: CommunityDesign.metaStyle(context),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(_saving ? 'Salvando...' : 'Salvar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
      ),
      child: Text(value),
    );
  }
}

class _CandidatePicker extends ConsumerWidget {
  final String ministryId;
  final String? selectedUserId;
  final void Function(String userId, String label) onSelected;

  const _CandidatePicker({
    required this.ministryId,
    required this.selectedUserId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync =
        ref.watch(raizesEligibleSponsorCandidatesProvider(ministryId));

    return candidatesAsync.when(
      data: (candidates) {
        if (candidates.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Todos os membros deste ministério já têm perfil de padrinho. '
              'Adicione mais membros ao ministério antes de criar novos perfis.',
              style: CommunityDesign.metaStyle(context),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedUserId,
          decoration: const InputDecoration(
            labelText: 'Membro do ministério',
            border: OutlineInputBorder(),
          ),
          items: candidates
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c['id'],
                  child: Text(c['name'] ?? '—'),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final c = candidates.firstWhere((x) => x['id'] == id);
            onSelected(id, c['name'] ?? '—');
          },
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Erro: $e'),
    );
  }
}

class _MultiChipField extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _MultiChipField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CommunityDesign.metaStyle(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.entries.map((e) {
            final isSel = selected.contains(e.key);
            return FilterChip(
              label: Text(e.value),
              selected: isSel,
              onSelected: (v) {
                final next = Set<String>.from(selected);
                if (v) {
                  next.add(e.key);
                } else {
                  next.remove(e.key);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        Center(
          child: Icon(
            Icons.diversity_3_outlined,
            size: 56,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Nenhum padrinho cadastrado',
          textAlign: TextAlign.center,
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cadastre membros do ministério como padrinhos/madrinhas com '
          'critérios de match para o algoritmo de indicações.',
          textAlign: TextAlign.center,
          style: CommunityDesign.metaStyle(context),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('Cadastrar primeiro padrinho'),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const Center(
          child: Icon(Icons.error_outline, size: 56, color: Colors.red),
        ),
        const SizedBox(height: 16),
        Text(
          'Erro ao carregar padrinhos',
          textAlign: TextAlign.center,
          style: CommunityDesign.titleStyle(context),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: CommunityDesign.metaStyle(context),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }
}
