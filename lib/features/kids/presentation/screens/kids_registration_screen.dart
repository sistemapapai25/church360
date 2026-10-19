import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';
import '../providers/kids_providers.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member_directory_entry.dart';
import '../../domain/models/kids_guardian.dart';
import '../../domain/models/kids_child_profile.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/widgets/pearl_fab.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/layout/readable_width.dart';
import '../../../../core/widgets/church_qr_card.dart';
import '../../domain/kids_badges_pdf.dart' show kidsPickupCode;

/// Tela de Inscrição Kids (Área dos Pais)
/// Aqui os pais podem:
/// 1. Gerar QR Code para Check-in
/// 2. Gerenciar Guardiões autorizados
class KidsRegistrationScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;

  /// Aba aberta ao entrar (0 = QR; 3 = Aulas, vindo do push da aula).
  final int initialTab;

  const KidsRegistrationScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.initialTab = 0,
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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
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
            Tab(text: 'Responsáveis', icon: Icon(Icons.security)),
            Tab(text: 'Ficha', icon: Icon(Icons.medical_information)),
            Tab(text: 'Aulas', icon: Icon(Icons.menu_book)),
          ],
        ),
      ),
      body: ReadableWidth(child: TabBarView(
        controller: _tabController,
        children: [
          _CheckInTab(childId: widget.childId),
          _GuardiansTab(childId: widget.childId),
          _ProfileTab(childId: widget.childId),
          _LessonsTab(childId: widget.childId),
        ],
      )),
    );
  }
}

/// Tab 1: Geração de QR Code
class _CheckInTab extends ConsumerWidget {
  final String childId;

  const _CheckInTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Criança na sala: mostra o código de retirada (KOUT) no lugar do KIN.
    final koutAsync = ref.watch(kidsCheckoutCodeProvider(childId));
    if (koutAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final kout = koutAsync.valueOrNull;
    if (kout != null) {
      final room = kout['room_name'] as String?;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Apresente este QR Code na retirada',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ChurchQrCard(
              data: 'C360:KOUT:${kout['token']}',
              title: 'Retirada Kids',
              subtitle: [
                'Etiqueta ${kidsPickupCode(kout['attendance_id'] as String)}',
                if (room != null) 'Sala $room',
              ].join(' · '),
              size: 240,
              brightnessHint: true,
              onRefresh: () =>
                  ref.invalidate(kidsCheckoutCodeProvider(childId)),
            ),
          ],
        ),
      );
    }

    final tokenAsync = ref.watch(kidsCheckInTokenProvider(childId));

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
                  ChurchQrCard(
                    data: 'C360:KIN:${token.token}',
                    title: 'Check-in Kids',
                    size: 240,
                    expiresAt: token.expiresAt,
                    brightnessHint: true,
                    onRefresh: () {
                      ref.invalidate(kidsCheckoutCodeProvider(childId));
                      ref.invalidate(kidsCheckInTokenProvider(childId));
                    },
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  AppErrorHandler.userMessage(
                    err,
                    feature: 'kids.generate_qr',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(kidsCheckInTokenProvider(childId));
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
    final canManage = ref
        .watch(currentUserHasPermissionProvider('kids.manage'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: PermissionGate(
        permission: 'kids.manage',
        child: PearlFab(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => _AddGuardianDialog(childId: childId),
            );
          },
          label: 'Adicionar responsável',
          icon: Icons.add,
        ),
      ),
      body: ReadableWidth(child: guardiansAsync.when(
        data: (guardians) {
          if (guardians.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nenhum responsável extra autorizado'),
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
                  trailing: canManage
                      ? IconButton(
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
                        final hasPermission = await ref.read(
                          currentUserHasPermissionProvider('kids.manage').future,
                        );
                        if (!hasPermission) return;
                        await ref
                            .read(kidsRepositoryProvider)
                            .removeGuardian(guardian.id);
                        ref.invalidate(kidsGuardiansProvider(childId));
                      }
                    },
                  )
                      : null,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      )),
    );
  }
}

/// Tab 3: Ficha da criança (cartilha §6 e §5.3). Vista pela equipe do
/// Infantil, pelos pais e pelos responsáveis; a autorização de imagem só o
/// pai/mãe/tutor muda (a RPC confere de novo).
class _ProfileTab extends ConsumerStatefulWidget {
  final String childId;

  const _ProfileTab({required this.childId});

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  final _allergies = TextEditingController();
  final _intolerances = TextEditingController();
  final _medications = TextEditingController();
  final _specialNeeds = TextEditingController();
  final _behavior = TextEditingController();
  final _notes = TextEditingController();
  bool _imageConsent = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _allergies,
      _intolerances,
      _medications,
      _specialNeeds,
      _behavior,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(KidsChildProfile? p) {
    if (_loaded) return;
    _loaded = true;
    _allergies.text = p?.allergies ?? '';
    _intolerances.text = p?.intolerances ?? '';
    _medications.text = p?.medications ?? '';
    _specialNeeds.text = p?.specialNeeds ?? '';
    _behavior.text = p?.behaviorProfile ?? '';
    _notes.text = p?.notes ?? '';
    _imageConsent = p?.imageConsent ?? false;
  }

  Future<void> _save(bool isParent) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(kidsRepositoryProvider).saveChildProfile(
            childId: widget.childId,
            allergies: _allergies.text,
            intolerances: _intolerances.text,
            medications: _medications.text,
            specialNeeds: _specialNeeds.text,
            behaviorProfile: _behavior.text,
            notes: _notes.text,
            imageConsent: isParent ? _imageConsent : null,
          );
      ref.invalidate(kidsChildProfileProvider(widget.childId));
      ref.invalidate(kidsChildProfilesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Ficha salva!')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppErrorHandler.userMessage(e, feature: 'kids.save_profile'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(kidsChildProfileProvider(widget.childId));
    final isParent = ref
        .watch(kidsIsParentProvider(widget.childId))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          AppErrorHandler.userMessage(e, feature: 'kids.load_profile'),
          textAlign: TextAlign.center,
        ),
      ),
      data: (profile) {
        _fill(profile);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Saúde', style: CommunityDesign.titleStyle(context)),
            const SizedBox(height: 12),
            _field(_allergies, 'Alergias', 'Ex.: amendoim, picada de abelha'),
            _field(_intolerances, 'Intolerâncias alimentares', 'Ex.: lactose, glúten'),
            _field(_medications, 'Medicamentos de uso contínuo', 'Nome e horário'),
            _field(
              _specialNeeds,
              'Diagnósticos e necessidades especiais',
              'Ex.: TEA, TDAH, asma',
            ),
            const SizedBox(height: 8),
            Text('Comportamento', style: CommunityDesign.titleStyle(context)),
            const SizedBox(height: 12),
            _field(_behavior, 'Perfil comportamental', 'Ex.: tímido, se adapta devagar'),
            _field(_notes, 'Observações', 'O que a equipe precisa saber'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _imageConsent,
              onChanged: isParent
                  ? (v) => setState(() => _imageConsent = v)
                  : null,
              title: const Text('Autorizo fotos e vídeos nos canais oficiais da igreja'),
              subtitle: Text([
                isParent
                    ? 'LGPD art. 14: só o pai, a mãe ou o responsável autoriza.'
                    : 'Só o pai, a mãe ou o responsável pode mudar.',
                if (profile?.imageConsentAt != null)
                  'Atualizado em ${DateFormat('dd/MM/yyyy').format(profile!.imageConsentAt!.toLocal())}.',
              ].join(' ')),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(isParent),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Salvar ficha'),
            ),
          ],
        );
      },
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
  MemberDirectoryEntry? _selectedMember;
  String _relationship = 'Tio(a)';
  bool _canCheckOut = true;
  bool _isTemporary = false;
  DateTime? _validUntil;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar responsável'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedMember == null) ...[
              Consumer(
                builder: (context, ref, child) {
                  final membersAsync = ref.watch(memberDirectoryProvider);

                  return membersAsync.when(
                    data: (members) {
                      // Filtrar para não mostrar a própria criança se ela estiver na lista (improvável mas seguro)
                      final filteredList = members
                          .where((m) => m.id != widget.childId)
                          .toList();

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Autocomplete<MemberDirectoryEntry>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  final text = textEditingValue.text.trim();
                                  if (text.length < 3) {
                                    return const Iterable<MemberDirectoryEntry>.empty();
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
                                            false),
                                  );
                                },
                            displayStringForOption: (m) => m.displayName,
                            onSelected: (MemberDirectoryEntry selection) {
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
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      labelText: 'Buscar responsável',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: fieldController.text.trim().isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                setState(() {
                                                  fieldController.clear();
                                                });
                                              },
                                            )
                                          : null,
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
                                            final MemberDirectoryEntry option =
                                                options.elementAt(index);
                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundImage:
                                                    option.avatarUrl != null
                                                    ? NetworkImage(
                                                        option.avatarUrl!,
                                                      )
                                                    : null,
                                                child: option.avatarUrl == null
                                                    ? Text(option.initials)
                                                    : null,
                                              ),
                                              title: Text(option.displayName),
                                              subtitle: option.nickname != null
                                                  ? Text(option.nickname!)
                                                  : null,
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
                    error: (e, s) => Text(
                      AppErrorHandler.userMessage(
                        e,
                        feature: 'kids.load_members',
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: _selectedMember!.avatarUrl != null
                      ? NetworkImage(_selectedMember!.avatarUrl!)
                      : null,
                  child: _selectedMember!.avatarUrl == null
                      ? Text(_selectedMember!.initials)
                      : null,
                ),
                title: Text(_selectedMember!.displayName),
                subtitle: _selectedMember!.nickname != null
                    ? Text(_selectedMember!.nickname!)
                    : null,
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
                ),
                items:
                    [
                          'Pai',
                          'Mãe',
                          'Avô',
                          'Avó',
                          'Tio(a)',
                          'Irmão(ã)',
                          'Responsável',
                          'Outro (Sem vínculo)',
                          'Outro',
                        ]
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _relationship = value);
                },
              ),
              // Cartilha §7.3: só retira quem está autorizado. O temporário
              // vale até a data escolhida (ex.: a tia que busca neste domingo).
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pode retirar a criança'),
                value: _canCheckOut,
                onChanged: (v) => setState(() => _canCheckOut = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Autorização temporária'),
                subtitle: _isTemporary
                    ? Text(
                        _validUntil == null
                            ? 'Escolha até quando vale'
                            : 'Vale até ${DateFormat('dd/MM/yyyy').format(_validUntil!)}',
                      )
                    : null,
                value: _isTemporary,
                onChanged: (v) async {
                  if (!v) {
                    setState(() {
                      _isTemporary = false;
                      _validUntil = null;
                    });
                    return;
                  }
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 365)),
                    helpText: 'Vale até',
                  );
                  if (picked == null) return;
                  setState(() {
                    _isTemporary = true;
                    _validUntil = picked;
                  });
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
                  final hasPermission = await ref.read(
                    currentUserHasPermissionProvider('kids.manage').future,
                  );
                  if (!hasPermission) return;
                  setState(() => _isLoading = true);
                  try {
                    final guardian = KidsAuthorizedGuardian(
                      id: const Uuid().v4(),
                      childId: widget.childId,
                      guardianId: _selectedMember!.id,
                      relationship: _relationship,
                      canCheckOut: _canCheckOut,
                      isTemporary: _isTemporary,
                      validUntil: _isTemporary ? _validUntil : null,
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
                        case 'Responsável':
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
                      // O vínculo acima também aparece em "Vínculos
                      // Familiares", cuja lista depende de Realtime e por
                      // isso não se atualiza sozinha.
                      ref.invalidate(
                        familyRelationshipsStreamProvider(widget.childId),
                      );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Responsável adicionado!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      final raw = e.toString().toLowerCase();
                      String? overrideMessage;
                      if (raw.contains('23505') ||
                          raw.contains('duplicate key')) {
                        overrideMessage =
                            'Este responsavel ja esta vinculado a esta crianca.';
                      } else if (raw.contains('42501') ||
                          raw.contains('insufficient')) {
                        overrideMessage =
                            'Sem permissao para adicionar responsaveis. Contate o administrador.';
                      }

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            overrideMessage ??
                                AppErrorHandler.userMessage(
                                  e,
                                  feature: 'kids.add_guardian',
                                ),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
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

/// Aba Aulas (K7): o que foi ministrado nos cultos em que a criança esteve,
/// com o versículo e a tarefa para casa (cartilha §3).
class _LessonsTab extends ConsumerWidget {
  final String childId;

  const _LessonsTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(kidsChildLessonsProvider(childId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              AppErrorHandler.userMessage(e, feature: 'kids.lessons'),
            ),
          ),
          data: (lessons) => lessons.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Quando a criança participar de um culto com check-in, '
                      'a aula do dia aparece aqui.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final l in lessons)
                      Card(
                        child: ListTile(
                          title: Text(l['theme'] as String? ?? ''),
                          subtitle: Text(_lessonDetails(l)),
                        ),
                      ),
                  ],
                ),
        );
  }

  // start_date é hora de parede rotulada UTC: mostrar sem converter.
  static String _lessonDetails(Map<String, dynamic> l) {
    final date = DateTime.tryParse('${l['date']}');
    return [
      [
        if (date != null) DateFormat('dd/MM').format(date.toUtc()),
        '${l['event_name'] ?? ''}',
      ].join(' · '),
      if (l['verse'] != null) 'Versículo: ${l['verse']}',
      if (l['activity'] != null) 'Tarefa para casa: ${l['activity']}',
    ].join('\n');
  }
}
