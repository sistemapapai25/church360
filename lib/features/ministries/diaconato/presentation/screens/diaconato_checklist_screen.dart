import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/design/app_icons.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../worship/domain/models/worship_service.dart';
import '../../../../../core/widgets/presence_deck.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../../worship/presentation/providers/worship_provider.dart';
import '../../../../worship/presentation/screens/geo_checkin_review_screen.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/worship_attendance.dart';
import '../providers/diaconato_attendance_providers.dart';

/// Tela do checklist de presença do Diaconato (Lote MD.2).
///
/// Lista membros + visitantes cadastrados em duas seções, switch presente
/// para cada um, stepper para visitantes não cadastrados, total ao vivo,
/// salvar em `worship_attendance_count` + `worship_attendance_person`.
///
/// Chega com quem já marcou presença pelo celular (localização, 005200) ou
/// pelo check-in de Cultos; o diácono confere e marca quem faltar. Salvar
/// leva direto aos Ausentes do mesmo culto: é um fluxo só.
class DiaconatoChecklistScreen extends ConsumerWidget {
  final String ministryId;
  final String worshipServiceId;

  const DiaconatoChecklistScreen({
    super.key,
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'diaconato.manage_attendance',
      submoduleLabel: 'Checklist do Diaconato',
      builder: (context) => _DiaconatoChecklistContent(
        ministryId: ministryId,
        worshipServiceId: worshipServiceId,
      ),
    );
  }
}

class _DiaconatoChecklistContent extends ConsumerStatefulWidget {
  final String ministryId;
  final String worshipServiceId;

  const _DiaconatoChecklistContent({
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  ConsumerState<_DiaconatoChecklistContent> createState() =>
      _DiaconatoChecklistContentState();
}

class _DiaconatoChecklistContentState
    extends ConsumerState<_DiaconatoChecklistContent> {
  late Future<_ChecklistData> _loadFuture;

  WorshipAttendanceCount? _count;
  WorshipService? _service;
  List<DiaconatoEligiblePerson> _eligible = const [];

  final Set<String> _presentMemberIds = <String>{};
  final Set<String> _presentVisitorIds = <String>{};

  /// Marcados sozinhos porque a pessoa fez check-in (celular ou Cultos).
  final Set<String> _fromCheckin = <String>{};
  /// Check-ins do culto (celular ou Cultos), por pessoa.
  Map<String, WorshipAttendance> _checkins = const {};

  /// Modo cartas (16/10): abre assim num culto ainda sem checklist salvo.
  bool _cards = false;
  List<PresenceCardData> _deck = const [];

  /// Como cada pessoa estava antes da carta dela, para o Desfazer.
  final Map<String, bool> _beforeCard = {};
  int _unregisteredVisitors = 0;
  int _children = 0;
  bool _saving = false;
  bool _dirty = false;

  final _unregisteredController = TextEditingController(text: '0');
  final _childrenController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _unregisteredController.dispose();
    _childrenController.dispose();
    super.dispose();
  }

  Future<_ChecklistData> _load() async {
    final repo = ref.read(diaconatoAttendanceRepositoryProvider);
    final worshipRepo = ref.read(worshipRepositoryProvider);

    final results = await Future.wait([
      repo.getOrCreateAttendanceCount(
        worshipServiceId: widget.worshipServiceId,
        ministryId: widget.ministryId,
      ),
      worshipRepo.getWorshipServiceById(widget.worshipServiceId),
      repo.getEligiblePeople(),
      worshipRepo.getWorshipAttendance(widget.worshipServiceId),
    ]);

    final count = results[0] as WorshipAttendanceCount;
    _checkins = {
      for (final a in results[3] as List<WorshipAttendance>) a.memberId: a,
    };
    final checkedIn = _checkins.keys.toSet();
    final personRows = await repo.getPersonRows(count.id);

    final data = _ChecklistData(
      count: count,
      service: results[1] as WorshipService?,
      eligible: results[2] as List<DiaconatoEligiblePerson>,
      personRows: personRows,
    );

    // Hidrata o estado local na primeira carga.
    _count = data.count;
    _service = data.service;
    _eligible = data.eligible;
    _unregisteredVisitors = data.count.totalUnregisteredVisitors;
    _unregisteredController.text = _unregisteredVisitors.toString();
    _children = data.count.totalChildren;
    _childrenController.text = _children.toString();

    for (final row in data.personRows) {
      if (!row.present) continue;
      if (row.personType == DiaconatoPersonType.member) {
        _presentMemberIds.add(row.userId);
      } else {
        _presentVisitorIds.add(row.userId);
      }
    }
    // Check-in de quem o diácono ainda não decidiu (sem linha nesta
    // contagem). Quem ele já marcou ausente continua ausente.
    final decided = {for (final r in data.personRows) r.userId};
    _fromCheckin.clear();
    for (final p in data.eligible) {
      if (!checkedIn.contains(p.userId) || decided.contains(p.userId)) {
        continue;
      }
      _fromCheckin.add(p.userId);
      if (p.personType == DiaconatoPersonType.member) {
        _presentMemberIds.add(p.userId);
      } else {
        _presentVisitorIds.add(p.userId);
      }
    }
    // Marcados pelo check-in ainda não estão gravados: pede o Salvar.
    _dirty = _fromCheckin.isNotEmpty;
    if (data.personRows.isEmpty && data.eligible.isNotEmpty) _startCards();

    return data;
  }

  bool _isPresent(String userId) =>
      _presentMemberIds.contains(userId) || _presentVisitorIds.contains(userId);

  void _setPresent(DiaconatoEligiblePerson p, bool present) =>
      p.personType == DiaconatoPersonType.member
      ? _toggleMember(p.userId, present)
      : _toggleVisitor(p.userId, present);

  /// Uma carta por pessoa; quem fez check-in vem primeiro (quase sempre é
  /// "presente", então o diácono passa rápido por eles).
  void _startCards() {
    final ordered = [
      ..._eligible.where((p) => _checkins.containsKey(p.userId)),
      ..._eligible.where((p) => !_checkins.containsKey(p.userId)),
    ];
    _deck = [
      for (final p in ordered)
        PresenceCardData(
          id: p.userId,
          name: p.displayName,
          photoUrl: p.photoUrl,
          subtitle: p.personType == DiaconatoPersonType.member
              ? 'Membro'
              : 'Visitante',
          hint: switch (_checkins[p.userId]) {
            null => null,
            final a when a.isGeo => geoCheckinHint(a),
            _ => 'Check-in em Cultos',
          },
          hintIcon: _checkins.containsKey(p.userId) ? Icons.gps_fixed : null,
        ),
    ];
    _beforeCard.clear();
    _cards = true;
  }

  DiaconatoEligiblePerson _personById(String id) =>
      _eligible.firstWhere((p) => p.userId == id);

  void _decideCard(PresenceCardData c, bool present) {
    _beforeCard[c.id] = _isPresent(c.id);
    _setPresent(_personById(c.id), present);
  }

  void _undoCard(PresenceCardData c) =>
      _setPresent(_personById(c.id), _beforeCard.remove(c.id)!);

  /// A presença pelo GPS ainda não validada segue a decisão do checklist:
  /// presente valida, ausente recusa (RPC 007100, exige worship.attendance).
  /// Devolve quantas não deram certo.
  Future<int> _syncGeoCheckins() async {
    final pending = pendingGeoCheckins(_checkins.values.toList());
    if (pending.isEmpty) return 0;
    final canValidate = await ref.read(
      currentUserHasPermissionProvider('worship.attendance').future,
    );
    if (!canValidate) return 0;
    final worshipRepo = ref.read(worshipRepositoryProvider);
    var failed = 0;
    for (final a in pending) {
      try {
        await worshipRepo.validateCheckin(
          widget.worshipServiceId,
          a.memberId,
          ok: _isPresent(a.memberId),
        );
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(worshipAttendanceProvider(widget.worshipServiceId));
    _checkins = {
      for (final a in await worshipRepo.getWorshipAttendance(
        widget.worshipServiceId,
      ))
        a.memberId: a,
    };
    return failed;
  }

  void _toggleMember(String userId, bool present) {
    setState(() {
      if (present) {
        _presentMemberIds.add(userId);
      } else {
        _presentMemberIds.remove(userId);
      }
      _dirty = true;
    });
  }

  void _toggleVisitor(String userId, bool present) {
    setState(() {
      if (present) {
        _presentVisitorIds.add(userId);
      } else {
        _presentVisitorIds.remove(userId);
      }
      _dirty = true;
    });
  }

  int get _totalMarked =>
      _presentMemberIds.length +
      _presentVisitorIds.length +
      _unregisteredVisitors;

  /// Muda um contador. [fromButton] reescreve o campo; vindo do teclado, o
  /// campo já mostra o que a pessoa digitou.
  void _setUnregistered(int value, bool fromButton) {
    final next = value.clamp(0, 9999);
    if (fromButton) _unregisteredController.text = next.toString();
    if (next == _unregisteredVisitors) return;
    setState(() {
      _unregisteredVisitors = next;
      _dirty = true;
    });
  }

  void _setChildren(int value, bool fromButton) {
    final next = value.clamp(0, 9999);
    if (fromButton) _childrenController.text = next.toString();
    if (next == _children) return;
    setState(() {
      _children = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final count = _count;
    if (count == null) return;
    // O banco recusa crianças acima do total (CHECK); avisar antes.
    if (_children > _totalMarked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Há mais crianças do que pessoas no total do culto.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final presentByUser = <String, DiaconatoPersonType>{};
      for (final id in _presentMemberIds) {
        presentByUser[id] = DiaconatoPersonType.member;
      }
      for (final id in _presentVisitorIds) {
        presentByUser[id] = DiaconatoPersonType.visitor;
      }

      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      final updated = await repo.saveChecklist(
        attendanceCountId: count.id,
        presentByUser: presentByUser,
        totalUnregisteredVisitors: _unregisteredVisitors,
        totalChildren: _children,
      );

      // O painel do Diaconato le `diaconatoDashboardStatsProvider`, que e um
      // `FutureProvider` com cache proprio: sem invalidar, voltar daqui mostra
      // os KPIs de antes do checklist e so o "puxar para atualizar" corrige.
      // O `setState` abaixo conserta esta tela; este invalidate conserta a de
      // tras.
      ref.invalidate(diaconatoDashboardStatsProvider(widget.ministryId));
      final geoFailed = await _syncGeoCheckins();

      if (!mounted) return;
      setState(() {
        _count = updated;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Checklist salvo. Total: ${updated.totalPeople} pessoa'
            '${updated.totalPeople == 1 ? '' : 's'}.'
            '${geoFailed == 0 ? '' : ' $geoFailed check-in(s) pelo GPS não foram conferidos: confira em Cultos.'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Mesmo fluxo: quem ficou desmarcado aparece em seguida para decidir
      // ligação, visita, ceia ou encaminhamento. `push` para o voltar
      // retornar ao checklist.
      context.push(
        '/ministries/${widget.ministryId}/diaconato/absentees/${widget.worshipServiceId}',
      );
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
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Checklist de presença'),
        actions: [
          if (_cards)
            TextButton.icon(
              onPressed: () => setState(() => _cards = false),
              icon: const Icon(Icons.list_rounded),
              label: const Text('Lista'),
            ),
        ],
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => (context.canPop() ? context.pop() : context.go('/home')),
        ),
      ),
      body: FutureBuilder<_ChecklistData>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _loadFuture = _load();
                });
              },
            );
          }
          return _cards ? _buildCards(context) : _buildForm(context);
        },
      ),
    );
  }

  /// Uma pessoa por carta. No fim, "Continuar" leva à lista (contadores de
  /// visitantes sem cadastro e crianças, e o Salvar e ver ausentes).
  Widget _buildCards(BuildContext context) {
    final present = _deck.where((c) => _isPresent(c.id)).length;
    final absent = _deck.length - present;
    return SafeArea(
      child: PresenceDeck(
        people: _deck,
        onDecide: _decideCard,
        onUndo: _undoCard,
        done: Text(
          '$present presente${present == 1 ? '' : 's'} · '
          '$absent ausente${absent == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        doneAction: FilledButton.icon(
          onPressed: () => setState(() => _cards = false),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continuar'),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final members = _eligible
        .where((p) => p.personType == DiaconatoPersonType.member)
        .toList();
    final visitors = _eligible
        .where((p) => p.personType == DiaconatoPersonType.visitor)
        .toList();

    final totalMarked = _totalMarked;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeaderCard(
                service: _service,
                presentMembers: _presentMemberIds.length,
                presentVisitors: _presentVisitorIds.length,
                unregistered: _unregisteredVisitors,
              ),
              if (_eligible.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(_startCards),
                    icon: const Icon(Icons.style_rounded),
                    label: const Text('Conferir em cartas'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Membros',
                badge: '${_presentMemberIds.length}/${members.length}',
                icon: AppIcons.groups,
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                _EmptyHint(text: 'Nenhum membro ativo cadastrado.')
              else
                ...members.map(
                  (p) => _PersonTile(
                    person: p,
                    present: _presentMemberIds.contains(p.userId),
                    fromCheckin: _fromCheckin.contains(p.userId),
                    onChanged: (v) => _toggleMember(p.userId, v),
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Visitantes cadastrados',
                badge: '${_presentVisitorIds.length}/${visitors.length}',
                icon: AppIcons.visitor,
              ),
              const SizedBox(height: 8),
              if (visitors.isEmpty)
                _EmptyHint(
                  text:
                      'Nenhum visitante ou novo convertido cadastrado.',
                )
              else
                ...visitors.map(
                  (p) => _PersonTile(
                    person: p,
                    present: _presentVisitorIds.contains(p.userId),
                    fromCheckin: _fromCheckin.contains(p.userId),
                    onChanged: (v) => _toggleVisitor(p.userId, v),
                  ),
                ),
              const SizedBox(height: 24),
              _CounterCard(
                title: 'Visitantes não cadastrados',
                hint: 'Pessoas presentes que ainda não têm cadastro na igreja.',
                icon: AppIcons.addCircle,
                color: Colors.orange,
                controller: _unregisteredController,
                count: _unregisteredVisitors,
                onSet: _setUnregistered,
              ),
              const SizedBox(height: 16),
              _CounterCard(
                key: const ValueKey('checklist-children'),
                title: 'Crianças',
                hint:
                    'Quantas das pessoas acima são crianças. Conte à mão: '
                    'visitante sem cadastro não tem data de nascimento.',
                icon: AppIcons.groups,
                color: Colors.purple,
                controller: _childrenController,
                count: _children,
                max: totalMarked,
                onSet: _setChildren,
              ),
            ],
          ),
        ),
        _StickyFooter(
          total: totalMarked,
          children: _children,
          dirty: _dirty,
          saving: _saving,
          onSave: _save,
        ),
      ],
    );
  }
}

// =====================================================
// Componentes internos
// =====================================================

class _ChecklistData {
  final WorshipAttendanceCount count;
  final WorshipService? service;
  final List<DiaconatoEligiblePerson> eligible;
  final List<WorshipAttendancePerson> personRows;

  const _ChecklistData({
    required this.count,
    required this.service,
    required this.eligible,
    required this.personRows,
  });
}

class _HeaderCard extends StatelessWidget {
  final WorshipService? service;
  final int presentMembers;
  final int presentVisitors;
  final int unregistered;

  const _HeaderCard({
    required this.service,
    required this.presentMembers,
    required this.presentVisitors,
    required this.unregistered,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = service;

    final dateLabel = s == null
        ? '—'
        : _capitalize(
            DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR').format(s.serviceDate),
          );

    final subtitle = s == null
        ? 'Carregando culto...'
        : [
            s.serviceType.label,
            if ((s.serviceTime ?? '').trim().isNotEmpty) s.serviceTime!.trim(),
            if ((s.theme ?? '').trim().isNotEmpty) s.theme!.trim(),
          ].join(' · ');

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.eventFilled, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: CommunityDesign.metaStyle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Membros',
                  value: presentMembers,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Visitantes',
                  value: presentVisitors,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Não cad.',
                  value: unregistered,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String badge;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.badge,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.primary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final DiaconatoEligiblePerson person;
  final bool present;
  final bool fromCheckin;
  final ValueChanged<bool> onChanged;

  const _PersonTile({
    required this.person,
    required this.present,
    this.fromCheckin = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        accentColor: present ? Colors.green : null,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(!present),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    backgroundImage: (person.photoUrl ?? '').trim().isNotEmpty
                        ? NetworkImage(person.photoUrl!)
                        : null,
                    child: (person.photoUrl ?? '').trim().isEmpty
                        ? Text(
                            person.initial,
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
                          person.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (fromCheckin)
                          Text(
                            'Check-in pelo celular',
                            style: CommunityDesign.metaStyle(
                              context,
                            ).copyWith(fontSize: 11, color: Colors.green),
                          ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: present,
                    onChanged: onChanged,
                    activeThumbColor: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contador com − e +: visitantes não cadastrados e crianças.
class _CounterCard extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final TextEditingController controller;
  final int count;

  /// Teto do +. Sem teto, só o limite do campo (4 dígitos).
  final int? max;
  final void Function(int value, bool fromButton) onSet;

  const _CounterCard({
    super.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.color,
    required this.controller,
    required this.count,
    this.max,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: count > 0 ? () => onSet(count - 1, true) : null,
                icon: const Icon(AppIcons.remove),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  onChanged: (t) => onSet(int.tryParse(t.trim()) ?? 0, false),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: max == null || count < max!
                    ? () => onSet(count + 1, true)
                    : null,
                icon: const Icon(AppIcons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final int total;
  final int children;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  const _StickyFooter({
    required this.total,
    required this.children,
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total no culto', style: CommunityDesign.metaStyle(context)),
              Text(
                '$total ${total == 1 ? 'pessoa' : 'pessoas'}',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (children > 0)
                Text(
                  adultsAndChildrenLabel(total, children),
                  style: CommunityDesign.metaStyle(context),
                ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(dirty ? AppIcons.save : AppIcons.check),
            label: Text(
              saving
                  ? 'Salvando...'
                  : dirty
                  ? 'Salvar e ver ausentes'
                  : 'Ver ausentes',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, style: CommunityDesign.metaStyle(context)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(AppIcons.error, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar checklist',
            style: CommunityDesign.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: CommunityDesign.metaStyle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
