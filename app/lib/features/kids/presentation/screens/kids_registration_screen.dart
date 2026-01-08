import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';
import '../providers/kids_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../domain/models/kids_guardian.dart';
import '../../../../core/design/community_design.dart';

/// Tela de Inscrição Kids (Área dos Pais)
/// Aqui os pais podem:
/// 1. Gerar QR Code para Check-in
/// 2. Gerenciar Guardiões autorizados
class KidsRegistrationScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;

  const KidsRegistrationScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<KidsRegistrationScreen> createState() =>
      _KidsRegistrationScreenState();
}

class _KidsRegistrationScreenState extends ConsumerState<KidsRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.child_care_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.childName,
                  style: CommunityDesign.titleStyle(context),
                ),
                Text(
                  'Gerenciamento',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        toolbarHeight: 64,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Check-in (QR)', icon: Icon(Icons.qr_code)),
            Tab(text: 'Guardiões', icon: Icon(Icons.security)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CheckInTab(childId: widget.childId),
          _GuardiansTab(childId: widget.childId),
        ],
      ),
    );
  }
}

/// Tab 1: Geração de QR Code
class _CheckInTab extends ConsumerWidget {
  final String childId;

  const _CheckInTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(child: Text('Erro: Usuário não logado'));
    }

    final tokenAsync = ref.watch(
      kidsCheckInTokenProvider((
        childId: childId,
        generatedBy: currentUser.id,
        eventId:
            null, // Opcional: pode vincular ao próximo culto automaticamente
      )),
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Apresente este QR Code na entrada',
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          tokenAsync.when(
            data: (token) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
                    child: QrImageView(
                      data: token.token,
                      version: QrVersions.auto,
                      size: 250.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Válido até ${DateFormat('HH:mm').format(token.expiresAt)}',
                    style: CommunityDesign.contentStyle(context).copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(kidsCheckInTokenProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Gerar Novo Código'),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erro ao gerar código: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(kidsCheckInTokenProvider);
                  },
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 2: Gestão de Guardiões
class _GuardiansTab extends ConsumerWidget {
  final String childId;

  const _GuardiansTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardiansAsync = ref.watch(kidsGuardiansProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _AddGuardianDialog(childId: childId),
          );
        },
        label: const Text('Adicionar Guardião'),
        icon: const Icon(Icons.add),
      ),
      body: guardiansAsync.when(
        data: (guardians) {
          if (guardians.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nenhum guardião extra autorizado'),
                  Text(
                    'Adicione pessoas que podem buscar seu filho',
                    style: CommunityDesign.contentStyle(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: guardians.length,
            itemBuilder: (context, index) {
              final guardian = guardians[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: CommunityDesign.overlayDecoration(
                  Theme.of(context).colorScheme,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: guardian.guardianPhoto != null
                        ? NetworkImage(guardian.guardianPhoto!)
                        : null,
                    child: guardian.guardianPhoto == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(guardian.guardianName ?? 'Nome não disponível'),
                  subtitle: Text(guardian.relationship),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // Confirmar e deletar
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remover autorização?'),
                          content: const Text(
                            'Essa pessoa não poderá mais buscar a criança.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                'Remover',
                                style: CommunityDesign.contentStyle(
                                  context,
                                ).copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref
                            .read(kidsRepositoryProvider)
                            .removeGuardian(guardian.id);
                        ref.invalidate(kidsGuardiansProvider(childId));
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}

class _AddGuardianDialog extends ConsumerStatefulWidget {
  final String childId;

  const _AddGuardianDialog({required this.childId});

  @override
  ConsumerState<_AddGuardianDialog> createState() => _AddGuardianDialogState();
}

class _AddGuardianDialogState extends ConsumerState<_AddGuardianDialog> {
  Member? _selectedMember;
  String _relationship = 'Tio(a)';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Guardião'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedMember == null) ...[
              Consumer(
                builder: (context, ref, child) {
                  final membersAsync = ref.watch(allMembersProvider);

                  return membersAsync.when(
                    data: (members) {
                      // Filtrar para não mostrar a própria criança se ela estiver na lista (improvável mas seguro)
                      final filteredList = members
                          .where((m) => m.id != widget.childId)
                          .toList();

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Autocomplete<Member>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  final text = textEditingValue.text.trim();
                                  if (text.length < 3) {
                                    return const Iterable<Member>.empty();
                                  }
                                  final q = text.toLowerCase();
                                  return filteredList.where(
                                    (m) =>
                                        m.displayName.toLowerCase().contains(
                                          q,
                                        ) ||
                                        (m.nickname?.toLowerCase().contains(
                                              q,
                                            ) ??
                                            false) ||
                                        m.email.toLowerCase().contains(q),
                                  );
                                },
                            displayStringForOption: (m) => m.displayName,
                            onSelected: (Member selection) {
                              setState(() {
                                _selectedMember = selection;
                              });
                            },
                            fieldViewBuilder:
                                (
                                  BuildContext context,
                                  TextEditingController fieldController,
                                  FocusNode fieldFocusNode,
                                  VoidCallback onFieldSubmitted,
                                ) {
                                  return TextFormField(
                                    controller: fieldController,
                                    focusNode: fieldFocusNode,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(),
                                      labelText: 'Buscar guardião',
                                      prefixIcon: Icon(Icons.search),
                                      helperText:
                                          'Digite 3 letras ou mais para buscar',
                                    ),
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final Member option = options
                                                .elementAt(index);
                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundImage:
                                                    option.photoUrl != null
                                                    ? NetworkImage(
                                                        option.photoUrl!,
                                                      )
                                                    : null,
                                                child: option.photoUrl == null
                                                    ? Text(option.initials)
                                                    : null,
                                              ),
                                              title: Text(option.displayName),
                                              subtitle: Text(option.email),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Erro ao carregar membros: $e'),
                  );
                },
              ),
            ] else ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: _selectedMember!.photoUrl != null
                      ? NetworkImage(_selectedMember!.photoUrl!)
                      : null,
                  child: _selectedMember!.photoUrl == null
                      ? Text(_selectedMember!.initials)
                      : null,
                ),
                title: Text(_selectedMember!.displayName),
                subtitle: Text(_selectedMember!.email),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedMember = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_relationship),
                initialValue: _relationship,
                decoration: const InputDecoration(
                  labelText: 'Parentesco',
                  filled: true,
                  fillColor: Colors.white,
                ),
                items:
                    [
                          'Pai',
                          'Mãe',
                          'Avô',
                          'Avó',
                          'Tio(a)',
                          'Irmão(ã)',
                          'Guardião(ã)',
                          'Outro (Sem vínculo)',
                          'Outro',
                        ]
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _relationship = value);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedMember == null || _isLoading
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  setState(() => _isLoading = true);
                  try {
                    final guardian = KidsAuthorizedGuardian(
                      id: const Uuid().v4(),
                      childId: widget.childId,
                      guardianId: _selectedMember!.id,
                      relationship: _relationship,
                      createdAt: DateTime.now(),
                    );

                    final repo = ref.read(kidsRepositoryProvider);

                    await repo.addGuardian(guardian);

                    // Sincronizar com vínculos familiares se possível
                    try {
                      final familyRepo = ref.read(
                        familyRelationshipsRepositoryProvider,
                      );
                      String? familyType;
                      final gGender = _selectedMember!.gender?.toLowerCase();
                      final isFemale =
                          gGender == 'female' ||
                          gGender == 'f' ||
                          gGender == 'feminino';

                      switch (_relationship) {
                        case 'Pai':
                          familyType = 'pai';
                          break;
                        case 'Mãe':
                          familyType = 'mae';
                          break;
                        case 'Avô':
                          familyType = 'avo';
                          break;
                        case 'Avó':
                          familyType = 'ava';
                          break;
                        case 'Tio(a)':
                          familyType = isFemale ? 'tia' : 'tio';
                          break;
                        case 'Irmão(ã)':
                          familyType = isFemale ? 'irma' : 'irmao';
                          break;
                        case 'Guardião(ã)':
                          familyType = isFemale ? 'tutora' : 'tutor';
                          break;
                        default:
                          familyType = null;
                      }

                      if (familyType != null) {
                        await familyRepo.addRelationship(
                          widget.childId, // Membro (Criança)
                          _selectedMember!.id, // Parente (Guardião)
                          familyType,
                        );
                      }
                    } catch (e) {
                      // Silenciosamente ignorar erro de vínculo familiar se guardião foi criado com sucesso
                      debugPrint(
                        'Erro ao criar vínculo familiar automático: $e',
                      );
                    }

                    if (mounted) {
                      navigator.pop();
                      ref.invalidate(kidsGuardiansProvider(widget.childId));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Guardião adicionado!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      String message = 'Erro: $e';
                      if (e.toString().contains('23505') ||
                          e.toString().contains('duplicate key')) {
                        message =
                            'Este guardião já está vinculado a esta criança.';
                      } else if (e.toString().contains('42501')) {
                        message =
                            'Sem permissão para adicionar guardiões. Contate o administrador.';
                      }
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }
}
