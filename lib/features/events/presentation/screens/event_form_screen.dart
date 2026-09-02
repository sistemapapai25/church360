import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../providers/events_provider.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../domain/models/event_audience.dart';
import '../../domain/models/event_reminder.dart';
import '../../domain/models/event_series.dart';
import '../widgets/audience_picker.dart';
import '../widgets/reminder_picker.dart';
import '../widgets/series_progress_barrier.dart';
import '../utils/series_pattern_label.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';

/// Tela de formulário de evento (criar/editar)
class EventFormScreen extends ConsumerStatefulWidget {
  final String? eventId; // null = criar, não-null = editar

  const EventFormScreen({super.key, this.eventId});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventTypeController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxCapacityController = TextEditingController();

  // State
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _requiresRegistration = false;
  bool _isMandatory = false;
  String _status = 'draft';
  String? _imageUrl;

  List<Map<String, String>> _eventTypeOptions = [];
  List<String> _locationOptions = [];
  String? _managingError;
  List<EventAudience> _responsibles = [];

  // VIS-01/VIS-03: dois controles independentes, cada um 'all' | 'restricted'.
  String _visibilityScope = 'all';
  String _registrationScope = 'all';
  List<EventAudience> _visibilityTargets = [];
  List<EventAudience> _registrationTargets = [];

  // Fase 4 — NOTIF-02 (D-02/D-03): vazio por padrão, nunca pré-preenchido.
  List<EventReminder> _reminders = [];

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isFixed = false;
  String _fixedPatternGroup = 'semanal'; // 'semanal' | 'variavel'
  String _variableType = 'quinzenal'; // 'quinzenal' | 'dias' | 'unico'
  final Set<int> _fixedWeekdays = {DateTime.sunday};
  int _intervalWeeks = 2;
  int? _variableMonthlyOrdinal;
  int? _diasBase;

  /// Fase 6 — REC-01: data de encerramento escolhida pelo líder.
  ///
  /// `null` significa **horizonte padrão**: 12 meses a partir de hoje, que era
  /// o único comportamento possível antes desta fase. Deixar em branco não
  /// muda nada para quem já usava o formulário.
  DateTime? _recurrenceEndDate;

  /// Fase 6 — REC-02 / IC-2: o lote a que esta ocorrência pertence.
  ///
  /// `null` significa "este evento não é de série" — e é o valor em modo de
  /// criação, sempre. Em modo de edição ele é restaurado de `event.batch_id`
  /// por `_loadEvent`, e é ele (não `_isFixed`) que decide se o cabeçalho de
  /// série e o toggle de escopo aparecem.
  String? _batchId;

  /// Definição de padrão da série, quando existe (`public.event_series`).
  ///
  /// `null` com `_batchId != null` é **série legada** (IC-7), não erro: a
  /// série foi criada antes desta fase e o padrão não ficou salvo. Hoje é o
  /// estado de 100% das séries de produção.
  EventSeries? _series;

  /// A leitura da definição da série falhou (rede/servidor). Diferente de
  /// série legada: aqui não se sabe se há padrão salvo, então a UI oferece
  /// "Tentar novamente" em vez de afirmar que o padrão não existe.
  bool _seriesLoadFailed = false;

  /// Fase 6 — S6/IC-6: progresso determinado da criação da série.
  ///
  /// `null` = nenhuma criação em voo. Enquanto for não-nulo, a barreira cobre
  /// a tela e o botão de salvar fica desabilitado (anti duplo toque).
  int? _seriesProgressTotal;
  int _seriesProgressDone = 0;

  /// Teto duro do período de repetição (A-03). A autoridade é a constraint
  /// `event_series_horizon_chk` do servidor; esta constante só existe para o
  /// líder descobrir o limite na tela, e não por erro do Postgres.
  static const int _maxRecurrenceMonths = 24;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.eventId != null;
    if (_isEditMode) {
      _loadEvent();
    }
    _loadEventTypes();
    _loadEventLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventTypeController.dispose();
    _locationController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  Future<void> _loadEventTypes() async {
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final catalog = await repo.getEventTypesCatalog();
      if (catalog.isNotEmpty) {
        setState(() => _eventTypeOptions = catalog);
        return;
      }
    } catch (_) {}
    final defaults = [
      {'code': 'culto_normal', 'label': 'Culto Normal / Ceia'},
      {'code': 'ensaio', 'label': 'Ensaio'},
      {
        'code': 'reuniao_ministerio',
        'label': 'Reunião do Ministério (interna)',
      },
      {'code': 'reuniao_externa', 'label': 'Reunião Externa / Célula'},
      {
        'code': 'evento_conjunto',
        'label': 'Evento Conjunto (vários ministérios)',
      },
      {'code': 'lideranca_geral', 'label': 'Reunião de Liderança Geral'},
      {'code': 'vigilia', 'label': 'Vigília ou Culto Especial'},
      {'code': 'mutirao', 'label': 'Limpeza / Mutirão / Manutenção'},
    ];
    setState(() => _eventTypeOptions = defaults);
  }

  Future<String?> _manageEventTypes() async {
    final newLabelController = TextEditingController();
    String? addedCode;
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Gerenciar Tipos de Evento'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_managingError != null && _managingError!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _managingError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newLabelController,
                            decoration: InputDecoration(
                              labelText: 'Nome exibido',
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final lbl = newLabelController.text.trim();
                            if (lbl.isEmpty) {
                              setStateDialog(
                                () => _managingError =
                                    'Informe um nome para o tipo.',
                              );
                              return;
                            }
                            final code = lbl.toLowerCase().replaceAll(' ', '_');
                            try {
                              final repo = ref.read(eventsRepositoryProvider);
                              await repo.upsertEventType(code, lbl);
                              await _loadEventTypes();
                              setStateDialog(() => _managingError = '');
                              addedCode = code;
                              newLabelController.clear();
                            } catch (e) {
                              final msg = e.toString();
                              if (msg.contains('code: 404')) {
                                final exists = _eventTypeOptions.any(
                                  (t) => t['code'] == code,
                                );
                                if (!exists) {
                                  _eventTypeOptions.add({
                                    'code': code,
                                    'label': lbl,
                                  });
                                }
                                setStateDialog(
                                  () => _managingError =
                                      'Catálogo não encontrado; incluído localmente (não persistido).',
                                );
                                addedCode = code;
                                newLabelController.clear();
                              } else {
                                setStateDialog(
                                  () => _managingError = 'Erro ao incluir: $e',
                                );
                              }
                            }
                          },
                          child: const Text('Incluir'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _eventTypeOptions.length,
                        itemBuilder: (context, index) {
                          final item = _eventTypeOptions[index];
                          final code = item['code']!;
                          final label = item['label'] ?? code;
                          return ListTile(
                            title: Text(label),
                            subtitle: Text(code),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final controller = TextEditingController(
                                      text: label,
                                    );
                                    final newLabel = await showDialog<String?>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Editar Tipo'),
                                          content: TextField(
                                            controller: controller,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, null),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                controller.text.trim(),
                                              ),
                                              child: const Text('Salvar'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (newLabel == null || newLabel.isEmpty) {
                                      return;
                                    }
                                    try {
                                      final repo = ref.read(
                                        eventsRepositoryProvider,
                                      );
                                      await repo.upsertEventType(
                                        code,
                                        newLabel,
                                      );
                                      await _loadEventTypes();
                                      setStateDialog(() => _managingError = '');
                                    } catch (e) {
                                      final msg = e.toString();
                                      if (msg.contains('code: 404')) {
                                        _eventTypeOptions = _eventTypeOptions
                                            .map(
                                              (t) => t['code'] == code
                                                  ? {
                                                      'code': code,
                                                      'label': newLabel,
                                                    }
                                                  : t,
                                            )
                                            .toList();
                                        setStateDialog(
                                          () => _managingError =
                                              'Catálogo não encontrado; alterado localmente (não persistido).',
                                        );
                                      } else {
                                        setStateDialog(
                                          () => _managingError =
                                              'Erro ao editar: $e',
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    try {
                                      final repo = ref.read(
                                        eventsRepositoryProvider,
                                      );
                                      final used = await repo
                                          .getEventsCountByType(code);
                                      if (used > 0) {
                                        setStateDialog(
                                          () => _managingError =
                                              'Tipo em uso por $used evento(s).',
                                        );
                                        return;
                                      }
                                      await repo.deleteEventType(code);
                                      await _loadEventTypes();
                                      setStateDialog(() => _managingError = '');
                                    } catch (e) {
                                      setStateDialog(
                                        () => _managingError =
                                            'Erro ao excluir: $e',
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, addedCode),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _loadEventLocations() async {
    try {
      final repo = ref.read(eventsRepositoryProvider);
      var catalog = await repo.getEventLocationsCatalog();
      if (catalog.isEmpty) {
        try {
          await repo.syncEventLocationsFromExistingEvents();
          catalog = await repo.getEventLocationsCatalog();
        } catch (_) {}
      }
      if (mounted) setState(() => _locationOptions = catalog);
    } catch (_) {
      if (mounted) setState(() => _locationOptions = []);
    }
  }

  Future<void> _manageEventLocations() async {
    final newNameController = TextEditingController();
    String? added;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Gerenciar Locais'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_managingError != null && _managingError!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _managingError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newNameController,
                            decoration: InputDecoration(
                              labelText: 'Nome do local',
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final name = newNameController.text.trim();
                            if (name.isEmpty) {
                              setStateDialog(
                                () => _managingError =
                                    'Informe o nome do local.',
                              );
                              return;
                            }
                            try {
                              final repo = ref.read(eventsRepositoryProvider);
                              await repo.upsertEventLocation(name);
                              await _loadEventLocations();
                              setStateDialog(() => _managingError = '');
                              added = name;
                              newNameController.clear();
                            } catch (e) {
                              setStateDialog(
                                () => _managingError = 'Erro ao incluir: $e',
                              );
                            }
                          },
                          child: const Text('Incluir'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _locationOptions.length,
                        itemBuilder: (context, index) {
                          final name = _locationOptions[index];
                          return ListTile(
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  final repo = ref.read(
                                    eventsRepositoryProvider,
                                  );
                                  final used = await repo
                                      .getEventsCountByLocation(name);
                                  if (used > 0) {
                                    setStateDialog(
                                      () => _managingError =
                                          'Local em uso por $used evento(s).',
                                    );
                                    return;
                                  }
                                  await repo.deleteEventLocation(name);
                                  await _loadEventLocations();
                                  setStateDialog(() => _managingError = '');
                                } catch (e) {
                                  setStateDialog(
                                    () => _managingError = 'Erro ao excluir: $e',
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (added != null && added!.isNotEmpty) {
      setState(() => _locationController.text = added!);
    }
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);

    try {
      final event = await ref
          .read(eventsRepositoryProvider)
          .getEventById(widget.eventId!);

      if (event != null) {
        _nameController.text = event.name;
        _descriptionController.text = event.description ?? '';
        _eventTypeController.text = event.eventType ?? '';
        _locationController.text = event.location ?? '';
        _maxCapacityController.text = event.maxCapacity?.toString() ?? '';

        _startDate = event.startDate;
        _startTime = TimeOfDay.fromDateTime(event.startDate);

        if (event.endDate != null) {
          _endDate = event.endDate;
          _endTime = TimeOfDay.fromDateTime(event.endDate!);
        }

        _requiresRegistration = event.requiresRegistration;
        _isMandatory = event.isMandatory;
        _status = event.status;
        _imageUrl = event.imageUrl;
        _visibilityScope = event.visibilityScope;
        _registrationScope = event.registrationScope;

        // Fase 6 — Pitfall #8: aqui restaura-se o LOTE, nunca `_isFixed`.
        //
        // `_isFixed` é a chave do ramo de GERAÇÃO de série em `_saveEvent`.
        // Restaurá-lo em modo de edição faria o botão Salvar gerar uma série
        // inteira nova (até 52 eventos) em vez de atualizar a ocorrência
        // aberta — que é exatamente o bug do Achado #10. O que o modo de
        // edição usa é `_batchId` + `_series` + o toggle de escopo; `_isFixed`
        // permanece `false` durante toda a edição, por construção.
        _batchId = event.batchId;

        try {
          final repo = ref.read(eventsRepositoryProvider);
          final responsibles = await repo.getEventResponsibles(
            widget.eventId!,
          );
          _responsibles = await _withAudienceNames(responsibles);
          _visibilityTargets = await _withAudienceNames(
            await repo.getEventAudience(widget.eventId!, 'visibility'),
          );
          _registrationTargets = await _withAudienceNames(
            await repo.getEventAudience(widget.eventId!, 'registration'),
          );
          _reminders = await repo.getEventReminders(widget.eventId!);
        } catch (_) {
          // Falha ao carregar responsáveis/audiência não impede editar o
          // resto do evento; as seções somem vazias e o usuário pode
          // reconstruir as listas.
        }

        // Mesmo espírito tolerante do `catch (_)` acima: falhar ao ler a
        // definição da série não pode impedir a edição do resto do evento.
        await _loadSeriesDefinition();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar evento: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Fase 6 — REC-02 / IC-2: lê a definição de padrão do lote e restaura os
  /// campos de padrão do formulário a partir dela.
  ///
  /// Três desfechos, todos legítimos:
  ///   • linha encontrada → `_series` preenchida e os campos de padrão
  ///     restaurados;
  ///   • `null` → **série legada** (IC-7), sem padrão salvo. Não é erro;
  ///   • exceção → `_seriesLoadFailed`, e o cabeçalho oferece
  ///     "Tentar novamente". A edição do resto do evento continua liberada.
  ///
  /// Reexecutável: é a mesma função que o botão "Tentar novamente" chama.
  Future<void> _loadSeriesDefinition() async {
    if (_batchId == null) return;
    try {
      final serie = await ref
          .read(eventsRepositoryProvider)
          .getEventSeries(_batchId!);
      _series = serie;
      _seriesLoadFailed = false;
      if (serie != null) {
        _applySeriesPatternToForm(serie);
      }
    } catch (_) {
      _seriesLoadFailed = true;
    }
  }

  /// Copia o padrão persistido para o estado do formulário.
  ///
  /// **`_isFixed` NÃO é tocado aqui de propósito** (Pitfall #8): estes campos
  /// alimentam o toggle de escopo da edição, nunca o ramo de geração.
  void _applySeriesPatternToForm(EventSeries serie) {
    _fixedPatternGroup = serie.patternGroup;
    if (serie.variableType != null) {
      _variableType = serie.variableType!;
    }
    _fixedWeekdays
      ..clear()
      ..addAll(serie.weekdays);
    _intervalWeeks = serie.intervalWeeks;
    _variableMonthlyOrdinal = serie.monthlyOrdinal;
    _recurrenceEndDate = serie.recurrenceEndDate;
  }

  /// Resolve o nome de exibição (pessoa, grupo, ministério ou cargo) para
  /// cada alvo de audiência carregado do servidor, que só traz os IDs.
  /// Serve tanto para Responsáveis quanto para Visibilidade/Elegibilidade.
  Future<List<EventAudience>> _withAudienceNames(
    List<EventAudience> audience,
  ) async {
    if (audience.isEmpty) return audience;

    final needsPeople = audience.any(
      (r) => r.targetKind == EventAudienceTargetKind.person,
    );
    final needsMinistries = audience.any(
      (r) => r.targetKind == EventAudienceTargetKind.ministry,
    );
    final needsGroups = audience.any(
      (r) => r.targetKind == EventAudienceTargetKind.group,
    );
    final needsRoles = audience.any(
      (r) => r.targetKind == EventAudienceTargetKind.role,
    );

    final peopleById = needsPeople
        ? {
            for (final person in await ref.read(memberDirectoryProvider.future))
              person.id: person.displayName,
          }
        : const <String, String>{};
    final ministriesById = needsMinistries
        ? {
            for (final ministry in await ref.read(allMinistriesProvider.future))
              ministry.id: ministry.name,
          }
        : const <String, String>{};
    final groupsById = needsGroups
        ? {
            for (final group in await ref.read(allGroupsProvider.future))
              group.id: group.name,
          }
        : const <String, String>{};
    final rolesById = needsRoles
        ? {
            for (final role in await ref.read(allRolesProvider.future))
              role.id: role.name,
          }
        : const <String, String>{};

    return audience.map((item) {
      final name = switch (item.targetKind) {
        EventAudienceTargetKind.person => peopleById[item.userId],
        EventAudienceTargetKind.ministry => ministriesById[item.ministryId],
        EventAudienceTargetKind.group => groupsById[item.groupId],
        // D-07: cargo desativado (ausente de allRolesProvider, que só traz
        // ativos) continua valendo como alvo — o chip precisa de um rótulo
        // legível em vez de sumir ou virar null.
        EventAudienceTargetKind.role =>
          rolesById[item.rbacRoleId] ?? 'Cargo desativado',
      };
      return EventAudience(
        id: item.id,
        eventId: item.eventId,
        role: item.role,
        userId: item.userId,
        groupId: item.groupId,
        ministryId: item.ministryId,
        rbacRoleId: item.rbacRoleId,
        displayName: name ?? item.displayName,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          _isEditMode ? 'Editar Evento' : 'Novo Evento',
          style: CommunityDesign.titleStyle(context),
        ),
      ),
      // Fase 6 — S6/IC-6: a barreira de progresso da criação de série fica
      // por cima do corpo, com contador real. Ela só existe enquanto
      // `_seriesProgressTotal != null`.
      body: Stack(
        children: [
          _buildFormBody(context),
          if (_seriesProgressTotal != null)
            SeriesProgressBarrier(
              done: _seriesProgressDone,
              total: _seriesProgressTotal!,
            ),
        ],
      ),
    );
  }

  /// Fase 6 — IC-2: badge `Série` + linha de contexto da ocorrência aberta.
  ///
  /// Ocupa o lugar que o switch "Evento fixo" ocupava em modo de edição. Em
  /// série legada (`_series == null`) a linha omite o padrão, porque ele não
  /// existe — inventar uma descrição seria pior do que não mostrar nenhuma.
  Widget _buildSeriesHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_seriesLoadFailed) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Não foi possível carregar os dados da série.',
              style: CommunityDesign.contentStyle(context),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _loadSeriesDefinition();
              if (mounted) setState(() {});
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    final data = DateFormat(
      'dd/MM/yyyy',
    ).format(_startDate ?? DateTime.now());
    final padrao = _series?.patternLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          // 11px/w700 vêm do helper e não são replicados aqui (Tipografia,
          // "Exceções herdadas" do `06-UI-SPEC.md`).
          child: CommunityDesign.badge(
            context,
            'Série',
            cs.primary,
            icon: Icons.repeat,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          padrao == null
              ? 'Ocorrência de $data'
              : 'Ocorrência de $data · $padrao',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFormBody(BuildContext context) {
    return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/home/banners'),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Gerenciar Banners'),
                    ),
                    const SizedBox(height: 16),
                    // Nome
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome do Evento *',
                        prefixIcon: const Icon(Icons.event),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nome é obrigatório';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        prefixIcon: const Icon(Icons.description),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Upload de Imagem
                    ImageUploadWidget(
                      initialImageUrl: _imageUrl,
                      onImageUrlChanged: (url) {
                        setState(() {
                          _imageUrl = url;
                        });
                      },
                      storageBucket: 'event-images',
                      label: 'Imagem do Evento',
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey(
                              'evt-type-${_eventTypeController.text}',
                            ),
                            initialValue: _eventTypeController.text.isEmpty
                                ? null
                                : _eventTypeController.text,
                            decoration: InputDecoration(
                              labelText: 'Tipo de Evento',
                              prefixIcon: const Icon(Icons.category),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: const OutlineInputBorder(),
                            ),
                            items: _eventTypeOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e['code'],
                                    child: Text(e['label'] ?? e['code']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(
                                () => _eventTypeController.text = value ?? '',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final created = await _manageEventTypes();
                            if (created != null && created.isNotEmpty) {
                              setState(
                                () => _eventTypeController.text = created,
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar tipo'),
                        ),
                      ],
                    ),
                    // 24 quando o que vem a seguir é o cabeçalho de série
                    // (IC-3 pede 24 das seções vizinhas); 16 no espaçamento
                    // padrão entre campos do formulário.
                    SizedBox(
                      height: (_isEditMode && _batchId != null) ? 24 : 16,
                    ),

                    // Fase 6 — Achado #10 / Pitfall #8 (A-08 do `06-UI-SPEC`).
                    // METADE VISUAL DA CORREÇÃO — a outra metade é a guarda
                    // `if (_isFixed && !_isEditMode)` em `_saveEvent`. As duas
                    // NUNCA podem ser removidas separadamente.
                    //
                    // CAUSA do bug que isto fecha: o switch "Evento fixo" era
                    // renderizado também em modo de edição; `_loadEvent` nunca
                    // restaurava `_isFixed`; e `_saveEvent` ramificava em
                    // `if (_isFixed)` ANTES de olhar `_isEditMode`, num ramo
                    // que só CRIA e nunca atualiza. Abrir uma ocorrência
                    // existente, ligar o switch e salvar gerava uma série
                    // inteira nova (até 52 eventos), sem tocar no evento que
                    // estava sendo editado, e ainda dizia "Gerados N eventos
                    // fixos". Transformar um evento existente em série não é
                    // caminho pedido por nenhum REC desta fase.
                    if (!_isEditMode)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Evento fixo'),
                        subtitle: const Text(
                          'Gera ocorrências automaticamente, sem data de início obrigatória',
                        ),
                        value: _isFixed,
                        onChanged: (v) {
                          setState(() => _isFixed = v);
                        },
                      ),
                    if (!_isEditMode && _isFixed) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _fixedPatternGroup,
                        decoration: InputDecoration(
                          labelText: 'Padrão',
                          prefixIcon: const Icon(Icons.repeat),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'semanal',
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem(
                            value: 'variavel',
                            child: Text('Variável'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _fixedPatternGroup = v ?? 'semanal';
                          if (_fixedPatternGroup == 'variavel' &&
                              _intervalWeeks < 2) {
                            _intervalWeeks = 2;
                          }
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (_fixedPatternGroup == 'semanal') ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _intervalWeeks,
                                decoration: const InputDecoration(
                                  labelText: 'Intervalo (semanas)',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('1 semana'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('2 semanas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('3 semanas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 4,
                                    child: Text('4 semanas'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _intervalWeeks = v ?? 2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Dias da semana',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in [
                              DateTime.sunday,
                              DateTime.monday,
                              DateTime.tuesday,
                              DateTime.wednesday,
                              DateTime.thursday,
                              DateTime.friday,
                              DateTime.saturday,
                            ])
                              ChoiceChip(
                                label: Text(_weekdayLabel(d)),
                                selected: _fixedWeekdays.contains(d),
                                onSelected: (sel) {
                                  setState(() {
                                    if (sel) {
                                      _fixedWeekdays.add(d);
                                    } else {
                                      _fixedWeekdays.remove(d);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                      if (_fixedPatternGroup == 'variavel') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _variableType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo variável',
                            prefixIcon: Icon(Icons.tune),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'quinzenal',
                              child: Text('Quinzenal (mesmo dia)'),
                            ),
                            DropdownMenuItem(
                              value: 'dias',
                              child: Text('Por dias corridos'),
                            ),
                            DropdownMenuItem(
                              value: 'unico',
                              child: Text('Único (próxima ocorrência)'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _variableType = v ?? 'quinzenal';
                            if (_variableType == 'quinzenal' &&
                                _intervalWeeks < 2) {
                              _intervalWeeks = 2;
                            }
                            if (_variableType == 'dias') {
                              _fixedWeekdays.clear();
                              _diasBase = null;
                            }
                          }),
                        ),
                        const SizedBox(height: 8),
                        if (_variableType == 'quinzenal') ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _intervalWeeks,
                                  decoration: const InputDecoration(
                                    labelText: 'Intervalo (semanas)',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text('2 semanas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('3 semanas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text('4 semanas'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _intervalWeeks = v ?? 2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dia da semana',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [
                                DateTime.sunday,
                                DateTime.monday,
                                DateTime.tuesday,
                                DateTime.wednesday,
                                DateTime.thursday,
                                DateTime.friday,
                                DateTime.saturday,
                              ])
                                ChoiceChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _fixedWeekdays.contains(d),
                                  onSelected: (sel) {
                                    setState(() {
                                      _fixedWeekdays.clear();
                                      if (sel) _fixedWeekdays.add(d);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        if (_variableType == 'dias') ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dias da semana',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [
                                DateTime.sunday,
                                DateTime.monday,
                                DateTime.tuesday,
                                DateTime.wednesday,
                                DateTime.thursday,
                                DateTime.friday,
                                DateTime.saturday,
                              ])
                                ChoiceChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _fixedWeekdays.contains(d),
                                  onSelected: (sel) {
                                    setState(() {
                                      _handleDiasChip(d, sel);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        if (_variableType == 'unico') ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dia da semana',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in [
                                DateTime.sunday,
                                DateTime.monday,
                                DateTime.tuesday,
                                DateTime.wednesday,
                                DateTime.thursday,
                                DateTime.friday,
                                DateTime.saturday,
                              ])
                                ChoiceChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _fixedWeekdays.contains(d),
                                  onSelected: (sel) {
                                    setState(() {
                                      _fixedWeekdays.clear();
                                      if (sel) _fixedWeekdays.add(d);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _variableMonthlyOrdinal,
                          decoration: const InputDecoration(
                            labelText: 'Semana do mês',
                            prefixIcon: Icon(Icons.calendar_view_month),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1º')),
                            DropdownMenuItem(value: 2, child: Text('2º')),
                            DropdownMenuItem(value: 3, child: Text('3º')),
                            DropdownMenuItem(value: 4, child: Text('4º')),
                          ],
                          onChanged: (v) =>
                              setState(() => _variableMonthlyOrdinal = v),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Fase 6 — REC-01 / IC-1: data de encerramento da série.
                      //
                      // NÃO é renderizado para `variavel/unico`: um evento
                      // único não recebe `batch_id` e portanto não pertence a
                      // série nenhuma — não há o que "repetir até", e nenhuma
                      // linha de `event_series` é gravada para ele.
                      if (!_isVariavelUnico) ...[
                        if (_recurrenceEndDate == null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _pickRecurrenceEndDate,
                              icon: const Icon(Icons.event_busy),
                              label: const Text(
                                'Escolher data de encerramento',
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.event_busy),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickRecurrenceEndDate,
                                  child: Text(
                                    'Repetir até '
                                    '${DateFormat('dd/MM/yyyy').format(_recurrenceEndDate!)}',
                                    style: CommunityDesign.contentStyle(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Limpar data de encerramento',
                                onPressed: () =>
                                    setState(() => _recurrenceEndDate = null),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sem preencher, o evento se repete pelos próximos 12 meses.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Fase 6 — A-09: esta prévia é LOCAL e informativa. Ela
                      // recalcula a cada toque num chip de dia, por isso não
                      // pode custar uma ida ao servidor — e por isso mesmo a
                      // autoridade do número NÃO é ela. A copy diz "Serão
                      // geradas" enquanto o SnackBar de sucesso informa o
                      // número realmente criado. As contagens de operações
                      // destrutivas (DLG-1..5, planos seguintes) vêm do
                      // servidor, nunca daqui.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _seriesPreviewText(),
                          style: CommunityDesign.metaStyle(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Fase 6 — IC-2: cabeçalho de série. Entra exatamente no
                    // lugar do switch "Evento fixo", que some em edição.
                    if (_isEditMode && _batchId != null) ...[
                      _buildSeriesHeader(context),
                      const SizedBox(height: 24),
                    ],

                    // Data de início
                    if (!_isFixed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Data de Início *'),
                        subtitle: Text(
                          _startDate != null
                              ? DateFormat('dd/MM/yyyy').format(_startDate!)
                              : 'Selecione a data',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _pickStartDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    if (!_isFixed) const SizedBox(height: 16),

                    // Horário de início
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Horário de Início *'),
                      subtitle: Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Selecione o horário',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _pickStartTime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data de término
                    if (!_isFixed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available),
                        title: const Text('Data de Término (opcional)'),
                        subtitle: Text(
                          _endDate != null
                              ? DateFormat('dd/MM/yyyy').format(_endDate!)
                              : 'Selecione a data',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_endDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () => setState(() {
                                  _endDate = null;
                                  _endTime = null;
                                }),
                              ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: _pickEndDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    if (!_isFixed) const SizedBox(height: 16),

                    // Horário de término
                    if (_endDate != null && !_isFixed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: const Text('Horário de Término'),
                        subtitle: Text(
                          _endTime != null
                              ? _endTime!.format(context)
                              : 'Selecione o horário',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _pickEndTime,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    if (_endDate != null && !_isFixed)
                      const SizedBox(height: 16),

                    // Local
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            key: ValueKey(
                              'evt-location-${_locationController.text}',
                            ),
                            initialValue: TextEditingValue(
                              text: _locationController.text,
                            ),
                            optionsBuilder: (TextEditingValue value) {
                              if (value.text.trim().isEmpty) {
                                return _locationOptions;
                              }
                              final query = value.text.toLowerCase();
                              return _locationOptions.where(
                                (option) =>
                                    option.toLowerCase().contains(query),
                              );
                            },
                            onSelected: (selection) {
                              _locationController.text = selection;
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onChanged: (value) =>
                                        _locationController.text = value,
                                    decoration: const InputDecoration(
                                      labelText: 'Local',
                                      prefixIcon: Icon(Icons.location_on),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Gerenciar locais',
                          onPressed: _manageEventLocations,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Capacidade máxima
                    TextFormField(
                      controller: _maxCapacityController,
                      decoration: const InputDecoration(
                        labelText: 'Capacidade Máxima',
                        prefixIcon: Icon(Icons.people),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                        hintText: 'Deixe vazio para ilimitado',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final number = int.tryParse(value);
                          if (number == null || number <= 0) {
                            return 'Capacidade deve ser um número positivo';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Responsáveis (REG-02)
                    Text(
                      'Responsáveis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quem pode gerenciar os inscritos deste evento. O líder de um '
                      'grupo ou ministério escolhido também passa a gerenciar.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_isFixed) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Os responsáveis valem para todas as ocorrências geradas.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_responsibles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.manage_accounts,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nenhum responsável definido',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sem responsável, só quem tem a permissão "Gerenciar '
                                    'inscrições" administra este evento.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final responsible in _responsibles)
                            InputChip(
                              avatar: Icon(
                                switch (responsible.targetKind) {
                                  EventAudienceTargetKind.person => Icons.person,
                                  EventAudienceTargetKind.group => Icons.group,
                                  EventAudienceTargetKind.ministry => Icons.church,
                                  EventAudienceTargetKind.role => Icons.badge,
                                },
                                size: 18,
                              ),
                              label: Text(responsible.displayName ?? responsible.targetId),
                              onDeleted: () {
                                setState(() {
                                  _responsibles = _responsibles
                                      .where((r) => r.targetId != responsible.targetId ||
                                          r.targetKind != responsible.targetKind)
                                      .toList();
                                });
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await showAudiencePicker(
                          context,
                          eventId: widget.eventId ?? '',
                          initialSelection: _responsibles,
                        );
                        if (result != null) {
                          setState(() => _responsibles = result);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar responsável'),
                    ),
                    const SizedBox(height: 24),

                    // Visibilidade (VIS-01)
                    Text(
                      'Visibilidade',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quem enxerga este evento na lista, na Agenda e por link direto.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_isFixed) ...[
                      const SizedBox(height: 4),
                      Text(
                        'A audiência vale para todas as ocorrências geradas.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'all',
                          label: Text('Toda a igreja'),
                          icon: Icon(Icons.public),
                        ),
                        ButtonSegment(
                          value: 'restricted',
                          label: Text('Somente alvos escolhidos'),
                          icon: Icon(Icons.lock_outline),
                        ),
                      ],
                      selected: {_visibilityScope},
                      onSelectionChanged: (newSelection) {
                        setState(() => _visibilityScope = newSelection.first);
                      },
                    ),
                    if (_visibilityScope == 'restricted') ...[
                      const SizedBox(height: 12),
                      if (_visibilityTargets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Selecione ao menos um alvo. Um evento restrito sem '
                                  'alvos fica invisível para todos, exceto '
                                  'responsáveis e quem tem permissão de gestão.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final target in _visibilityTargets)
                              InputChip(
                                avatar: Icon(
                                  switch (target.targetKind) {
                                    EventAudienceTargetKind.person =>
                                      Icons.person,
                                    EventAudienceTargetKind.group =>
                                      Icons.group,
                                    EventAudienceTargetKind.ministry =>
                                      Icons.church,
                                    EventAudienceTargetKind.role =>
                                      Icons.badge,
                                  },
                                  size: 18,
                                ),
                                label: Text(target.displayName ?? target.targetId),
                                onDeleted: () {
                                  setState(() {
                                    _visibilityTargets = _visibilityTargets
                                        .where((t) => t.targetId != target.targetId ||
                                            t.targetKind != target.targetKind)
                                        .toList();
                                  });
                                },
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await showAudiencePicker(
                            context,
                            eventId: widget.eventId ?? '',
                            initialSelection: _visibilityTargets,
                            role: 'visibility',
                            title: 'Quem pode ver este evento',
                            tabs: const [
                              AudienceTargetTab.groups,
                              AudienceTargetTab.ministries,
                              AudienceTargetTab.roles,
                            ],
                          );
                          if (result != null) {
                            setState(() => _visibilityTargets = result);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar alvo de visibilidade'),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Elegibilidade de Inscrição (VIS-03) — só faz sentido
                    // quando o evento tem inscrição habilitada.
                    if (_requiresRegistration) ...[
                      Text(
                        'Elegibilidade de Inscrição',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quem pode se inscrever neste evento. É independente da '
                        'visibilidade: alguém pode ver o evento e não poder se '
                        'inscrever.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O responsável pelo evento sempre pode se inscrever, mesmo '
                        'fora dos alvos.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isFixed) ...[
                        const SizedBox(height: 4),
                        Text(
                          'A audiência vale para todas as ocorrências geradas.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'all',
                            label: Text('Toda a igreja'),
                            icon: Icon(Icons.public),
                          ),
                          ButtonSegment(
                            value: 'restricted',
                            label: Text('Somente alvos escolhidos'),
                            icon: Icon(Icons.lock_outline),
                          ),
                        ],
                        selected: {_registrationScope},
                        onSelectionChanged: (newSelection) {
                          setState(
                            () => _registrationScope = newSelection.first,
                          );
                        },
                      ),
                      if (_registrationScope == 'restricted') ...[
                        const SizedBox(height: 12),
                        if (_registrationTargets.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Selecione ao menos um alvo, ou volte para "Toda a '
                                    'igreja" — sem alvo, ninguém consegue se inscrever.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final target in _registrationTargets)
                                InputChip(
                                  avatar: Icon(
                                    switch (target.targetKind) {
                                      EventAudienceTargetKind.person =>
                                        Icons.person,
                                      EventAudienceTargetKind.group =>
                                        Icons.group,
                                      EventAudienceTargetKind.ministry =>
                                        Icons.church,
                                      EventAudienceTargetKind.role =>
                                        Icons.badge,
                                    },
                                    size: 18,
                                  ),
                                  label:
                                      Text(target.displayName ?? target.targetId),
                                  onDeleted: () {
                                    setState(() {
                                      _registrationTargets =
                                          _registrationTargets
                                              .where((t) =>
                                                  t.targetId !=
                                                      target.targetId ||
                                                  t.targetKind !=
                                                      target.targetKind)
                                              .toList();
                                    });
                                  },
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await showAudiencePicker(
                              context,
                              eventId: widget.eventId ?? '',
                              initialSelection: _registrationTargets,
                              role: 'registration',
                              title: 'Quem pode se inscrever',
                              tabs: const [
                                AudienceTargetTab.groups,
                                AudienceTargetTab.ministries,
                                AudienceTargetTab.roles,
                              ],
                            );
                            if (result != null) {
                              setState(() => _registrationTargets = result);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar alvo de elegibilidade'),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],

                    // Lembretes (NOTIF-02, D-02/D-03)
                    Text(
                      'Lembretes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enviado a quem está inscrito, no tempo escolhido antes '
                      'do evento.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_isFixed) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Os lembretes valem para todas as ocorrências geradas.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_reminders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nenhum lembrete configurado',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Este evento não vai disparar lembrete algum. '
                                    'Adicione um ou mais abaixo se quiser avisar '
                                    'os inscritos antes da data.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final reminder in _reminders)
                            InputChip(
                              avatar: const Icon(
                                Icons.notifications_active_outlined,
                                size: 18,
                              ),
                              label: Text(reminder.label),
                              onDeleted: () {
                                setState(() {
                                  _reminders = _reminders
                                      .where(
                                        (r) => r.offsetMinutes !=
                                            reminder.offsetMinutes,
                                      )
                                      .toList();
                                });
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await showReminderPicker(
                          context,
                          existingOffsets: _reminders
                              .map((r) => r.offsetMinutes)
                              .toList(),
                        );
                        if (result != null) {
                          setState(() {
                            _reminders = [
                              ..._reminders,
                              EventReminder(
                                eventId: widget.eventId ?? '',
                                offsetMinutes: result,
                              ),
                            ];
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar lembrete'),
                    ),
                    const SizedBox(height: 24),

                    // Requer inscrição
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Requer Inscrição'),
                      subtitle: const Text(
                        'Membros precisam se inscrever para participar',
                      ),
                      value: _requiresRegistration,
                      onChanged: (value) {
                        setState(() => _requiresRegistration = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Obrigatório
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Evento obrigatório'),
                      subtitle: const Text(
                        'Presença marcada como obrigatória para o tipo adequado',
                      ),
                      value: _isMandatory,
                      onChanged: (value) {
                        setState(() => _isMandatory = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Rascunho'),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('Publicado'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelado'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Finalizado'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    // Botão salvar
                    DisabledByPermission(
                      permission: _isEditMode ? 'events.edit' : 'events.create',
                      disabledTooltip: _isEditMode
                          ? 'Você não tem permissão para editar eventos'
                          : 'Você não tem permissão para criar eventos',
                      child: FilledButton.icon(
                        // S6/IC-6: enquanto a criação da série está em voo, o
                        // botão fica desabilitado — anti duplo toque. Isto é
                        // UX; não há transação por trás (Achado #3).
                        onPressed: _seriesProgressTotal != null
                            ? null
                            : _saveEvent,
                        icon: const Icon(Icons.save),
                        label: Text(
                          _isEditMode ? 'Salvar Alterações' : 'Criar Evento',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final requiredPermission = _isEditMode ? 'events.edit' : 'events.create';
    final hasPermission = await ref.read(
      currentUserHasPermissionProvider(requiredPermission).future,
    );
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para esta ação'),
          ),
        );
      }
      return;
    }

    // Validação de horário
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horário de início é obrigatório')),
      );
      return;
    }

    // Validar data de início apenas para evento não fixo
    if (!_isFixed && _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data de início é obrigatória para evento não fixo'),
        ),
      );
      return;
    }

    // Validar data de término se informada
    if (_endDate != null && _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o horário de término')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combinar data e hora (para não fixo)
      DateTime startDateTime = DateTime(
        (_startDate ?? DateTime.now()).year,
        (_startDate ?? DateTime.now()).month,
        (_startDate ?? DateTime.now()).day,
        _startTime!.hour,
        _startTime!.minute,
      );

      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        // Validar que término é depois do início
        if (endDateTime.isBefore(startDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data de término deve ser após a data de início'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Validação de Visibilidade/Elegibilidade restritas sem alvo (Pitfall
      // 6): ver o aviso na UI sobre o efeito de um evento restrito sem alvo.
      if (_visibilityScope == 'restricted' && _visibilityTargets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Escolha ao menos um alvo de visibilidade ou volte para "Toda a igreja".',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      if (_registrationScope == 'restricted' &&
          _registrationTargets.isEmpty &&
          _requiresRegistration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Escolha ao menos um alvo de elegibilidade ou volte para "Toda a igreja".',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Preparar dados
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'event_type': _eventTypeController.text.trim().isEmpty
            ? null
            : _eventTypeController.text.trim(),
        'start_date': startDateTime.toIso8601String(),
        'end_date': endDateTime?.toIso8601String(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'max_capacity': _maxCapacityController.text.trim().isEmpty
            ? null
            : int.parse(_maxCapacityController.text.trim()),
        'requires_registration': _requiresRegistration,
        'is_mandatory': _isMandatory,
        'status': _status,
        'image_url': _imageUrl,
        // Pitfall 1 (03-RESEARCH.md): uma policy `AS RESTRICTIVE FOR SELECT`
        // em `public.event` também é avaliada no `INSERT ... RETURNING` e no
        // `UPDATE ... RETURNING`, e o Postgres LANÇA ERRO se a linha nova não
        // passar. `createEvent`/`updateEvent` usam `.select().single()`, e a
        // audiência só existe DEPOIS deste passo — gravar o evento já com o
        // escopo final quebraria o salvamento do próprio evento restrito
        // (ninguém está na audiência ainda, nem o autor). Por isso o evento
        // SEMPRE nasce/atualiza com 'all' aqui; o escopo final só é promovido
        // depois, quando a audiência já existe. Não "otimizar" isto mandando
        // o valor final direto.
        'visibility_scope': 'all',
        'registration_scope': 'all',
      };

      final locationText = _locationController.text.trim();
      if (locationText.isNotEmpty) {
        try {
          await ref
              .read(eventsRepositoryProvider)
              .upsertEventLocation(locationText);
        } catch (_) {}
      }

      // Fase 6 — Achado #10 / Pitfall #8 (METADE LÓGICA da correção; a outra
      // metade é a guarda `if (!_isEditMode)` do switch "Evento fixo" no
      // corpo do formulário). As duas nunca podem ser removidas
      // separadamente.
      //
      // CAUSA: este `if` ramificava só em `_isFixed`, antes de qualquer olhar
      // para `_isEditMode`, e o ramo abaixo apenas CRIA ocorrências — não
      // existe caminho de update dentro dele. Com o switch visível em edição,
      // ligá-lo e salvar gerava uma série nova inteira e deixava a ocorrência
      // editada intacta. Com `!_isEditMode` aqui, mesmo que `_isFixed` fique
      // verdadeiro por qualquer caminho futuro, o modo de edição nunca entra
      // no ramo de geração.
      if (_isFixed && !_isEditMode) {
        if (_fixedWeekdays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecione ao menos um dia da semana'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Fase 6 — REC-01: valida a data de encerramento antes de gerar
        // qualquer coisa. Espelha `event_series_horizon_chk`; a autoridade é
        // a constraint, isto aqui só evita que o líder descubra o teto depois
        // de o loop já ter criado dezenas de eventos.
        if (!_isVariavelUnico &&
            _recurrenceEndDate != null &&
            !_validateRecurrenceEndDate(_recurrenceEndDate!)) {
          setState(() => _isLoading = false);
          return;
        }

        final repo = ref.read(eventsRepositoryProvider);
        final batchId = const Uuid().v4();
        int count = 0;
        // Achado #9: `from` é a ÂNCORA do lote — é o valor que
        // `_matchesWeekInterval` usa para decidir a FASE do intervalo e é o
        // que vai ser persistido como `anchor_date`. Uma vez gravada, nunca
        // pode ser recalculada: refazer a âncora numa extensão futura joga as
        // ocorrências novas de uma série quinzenal nas semanas erradas,
        // intercaladas com as existentes.
        final from = DateTime.now();
        final until = _recurrenceUntil(from);

        if (_isVariavelUnico) {
          // `variavel/unico` não é série: um evento só, sem `batch_id` e sem
          // linha em `event_series`. Caminho inalterado por esta fase.
          final first = _firstMatchOnOrAfter(from, _fixedWeekdays) ?? from;
          DateTime target = first;
          if (_variableMonthlyOrdinal != null) {
            DateTime monthCursor = DateTime(from.year, from.month, 1);
            for (int m = 0; m < 24; m++) {
              final wd = _fixedWeekdays.isEmpty
                  ? DateTime.sunday
                  : _fixedWeekdays.first;
              final occ = _nthWeekdayOfMonth(
                monthCursor.year,
                monthCursor.month,
                wd,
                _variableMonthlyOrdinal!,
              );
              if (occ != null && !occ.isBefore(from)) {
                target = occ;
                break;
              }
              monthCursor = DateTime(
                monthCursor.year,
                monthCursor.month + 1,
                1,
              );
            }
          }
          final fixedStart = DateTime(
            target.year,
            target.month,
            target.day,
            _startTime!.hour,
            _startTime!.minute,
          );
          final fixedData = Map<String, dynamic>.from(data);
          fixedData['start_date'] = fixedStart.toIso8601String();
          fixedData['end_date'] = null;
          fixedData['status'] = 'published';
          final created = await repo.createEvent(fixedData);
          await _persistAudienceAndScopes(created.id);

          ref.invalidate(allEventsProvider);
          ref.invalidate(activeEventsProvider);
          ref.invalidate(upcomingEventsProvider);

          if (mounted) {
            Navigator.pop(context);
            // Não é série: reusa a copy já existente de evento avulso, em vez
            // de prometer "Série criada".
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Evento criado com sucesso!')),
            );
          }
          return;
        }

        final datas = _computeOccurrenceDates(from, until);
        setState(() {
          _seriesProgressTotal = datas.length;
          _seriesProgressDone = 0;
        });

        String? anchorEventId;
        DateTime? ultimaCriada;

        try {
          for (final ocorrencia in datas) {
            final fixedData = Map<String, dynamic>.from(data);
            fixedData['start_date'] = ocorrencia.toIso8601String();
            fixedData['end_date'] = null;
            fixedData['status'] = 'published';
            fixedData['batch_id'] = batchId;
            final created = await repo.createEvent(fixedData);
            await _persistAudienceAndScopes(created.id);
            anchorEventId ??= created.id;
            ultimaCriada = ocorrencia;
            count++;
            if (mounted) {
              setState(() => _seriesProgressDone = count);
            }
          }
        } catch (e) {
          // Falha no meio do loop: as ocorrências já criadas EXISTEM no
          // servidor (Achado #3 — não há transação). Informar o número e
          // nomear a saída é obrigatório; a saída nomeada ("Excluir
          // ocorrências futuras") é entregue pela Task 2 do Plano 06-04.
          ref.invalidate(allEventsProvider);
          ref.invalidate(activeEventsProvider);
          ref.invalidate(upcomingEventsProvider);
          if (mounted) {
            AppErrorHandler.log(e, feature: 'events');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'A série foi criada só em parte: $count de ${datas.length} '
                  'ocorrências. Abra a série e use "Excluir ocorrências '
                  'futuras" antes de tentar de novo.',
                ),
              ),
            );
          }
          return;
        }

        // Fase 6 — REC-01: grava a definição da série DEPOIS das ocorrências.
        //
        // Falhar aqui NÃO derruba a criação: os eventos já existem, e o pior
        // resultado possível é a série ficar sem padrão persistido — que é
        // exatamente o estado de "série legada" que IC-7 já contrata e que
        // hoje é o de 100% da produção. Desfazer dezenas de eventos já
        // criados por causa de uma linha de metadado seria muito pior. O
        // líder é avisado.
        if (anchorEventId != null) {
          try {
            await repo.upsertEventSeries(
              batchId: batchId,
              anchorEventId: anchorEventId,
              anchorDate: from,
              patternGroup: _fixedPatternGroup,
              variableType: _fixedPatternGroup == 'variavel'
                  ? _variableType
                  : null,
              weekdays: _fixedWeekdays.toList()..sort(),
              intervalWeeks: _intervalWeeks,
              monthlyOrdinal: _variableMonthlyOrdinal,
              recurrenceEndDate: _recurrenceEndDate,
              startTimeMinutes: _startTime!.hour * 60 + _startTime!.minute,
            );
          } catch (e) {
            if (mounted) {
              AppErrorHandler.showSnackBar(
                context,
                e,
                feature: 'events',
                fallbackMessage:
                    'A série foi criada, mas o padrão de repetição não ficou '
                    'salvo. As ocorrências existem; para mudar o padrão, '
                    'exclua as ocorrências futuras e crie a série de novo.',
              );
            }
          }
        }

        ref.invalidate(allEventsProvider);
        ref.invalidate(activeEventsProvider);
        ref.invalidate(upcomingEventsProvider);

        if (mounted) {
          Navigator.pop(context);
          final ate = ultimaCriada == null
              ? ''
              : ', até ${DateFormat('dd/MM/yyyy').format(ultimaCriada)}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count == 1
                    ? 'Série criada com 1 ocorrência$ate.'
                    : 'Série criada com $count ocorrências$ate.',
              ),
            ),
          );
        }
      } else {
        if (_isEditMode) {
          final updated = await ref
              .read(eventsRepositoryProvider)
              .updateEvent(widget.eventId!, data);
          await _persistAudienceAndScopes(updated.id);
          ref.invalidate(eventByIdProvider(widget.eventId!));
          ref.invalidate(eventResponsiblesProvider(widget.eventId!));
          ref.invalidate(
            eventAudienceProvider((
              eventId: widget.eventId!,
              role: 'visibility',
            )),
          );
          ref.invalidate(
            eventAudienceProvider((
              eventId: widget.eventId!,
              role: 'registration',
            )),
          );
        } else {
          final created = await ref.read(eventsRepositoryProvider).createEvent(data);
          await _persistAudienceAndScopes(created.id);
        }

        ref.invalidate(allEventsProvider);
        ref.invalidate(activeEventsProvider);
        ref.invalidate(upcomingEventsProvider);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode
                    ? 'Evento atualizado com sucesso!'
                    : 'Evento criado com sucesso!',
              ),
            ),
          );
        }
      }
    } catch (e) {
      // C6: erro cru na tela é proibido — nome de tabela, RPC e SQL não podem
      // vazar para o líder. `AppErrorHandler` traduz os códigos conhecidos
      // (23505, 42501, PGRST204...) e cai no fallback quando não reconhece.
      if (mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage:
              'Não foi possível salvar o evento. Verifique a conexão e tente '
              'novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _seriesProgressTotal = null;
          _seriesProgressDone = 0;
        });
      }
    }
  }

  /// Grava responsáveis, alvos de visibilidade e de elegibilidade para um
  /// evento já salvo com escopo `'all'`, e só então promove os escopos
  /// finais. Chamada depois de cada `createEvent`/`updateEvent` em
  /// `_saveEvent` — inclusive dentro do loop de evento fixo/recorrente, onde
  /// cada ocorrência gerada recebe a mesma audiência (Pitfall P1-6).
  ///
  /// Ordem obrigatória (Pitfall 1, 03-RESEARCH.md): o evento já foi gravado
  /// com `visibility_scope`/`registration_scope` = 'all' pelo mapa `data` em
  /// `_saveEvent`; a promoção para o escopo final só pode acontecer DEPOIS
  /// que a audiência existe, porque uma policy `AS RESTRICTIVE FOR SELECT`
  /// também é avaliada no `UPDATE ... RETURNING` — se o `UPDATE` de escopo
  /// rodasse antes da audiência, a própria promoção quebraria com erro para
  /// quem não está em nenhuma linha de `event_audience` ainda.
  Future<void> _persistAudienceAndScopes(String eventId) async {
    try {
      final repo = ref.read(eventsRepositoryProvider);

      await repo.setEventAudience(eventId, 'responsible', _responsibles);
      await repo.setEventAudience(
        eventId,
        'visibility',
        _visibilityScope == 'restricted' ? _visibilityTargets : const [],
      );
      await repo.setEventAudience(
        eventId,
        'registration',
        _registrationScope == 'restricted'
            ? _registrationTargets
            : const [],
      );
      // NOTIF-02 (D-02/D-03): grava a lista de lembretes tal como está no
      // estado local — vazia é estado válido e só deleta, sem inserir nada.
      await repo.setEventReminders(eventId, _reminders);

      // Só promove o escopo se algum dos dois deixou de ser 'all' — a
      // enorme maioria dos eventos hoje é 'all'/'all' e não precisa deste
      // PATCH extra. Fica DENTRO do try: se qualquer gravação de audiência
      // acima falhou, este bloco nunca é alcançado e o evento permanece
      // 'all' (fail-safe do Pitfall 6 — evento restrito sem alvo fica
      // invisível).
      if (_visibilityScope != 'all' || _registrationScope != 'all') {
        await repo.updateEvent(eventId, {
          'visibility_scope': _visibilityScope,
          'registration_scope': _registrationScope,
        });
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage:
              'Não foi possível salvar a audiência/lembretes do evento. O '
              'evento foi salvo como visível para toda a igreja; reabra e '
              'tente novamente.',
        );
      }
    }
  }

  /// Fase 6 — REC-01: `variavel/unico` NÃO é série.
  ///
  /// O sub-ramo de evento único não seta `batch_id` no evento criado, então
  /// ele não pertence a lote nenhum. `Repetir até` não aparece para ele e
  /// nenhuma linha de `event_series` é gravada.
  bool get _isVariavelUnico =>
      _fixedPatternGroup == 'variavel' && _variableType == 'unico';

  /// Teto duro do período de repetição (A-03): hoje + 24 meses.
  DateTime _maxRecurrenceEndDate() {
    final hoje = DateTime.now();
    return DateTime(
      hoje.year,
      hoje.month + _maxRecurrenceMonths,
      hoje.day,
    );
  }

  /// Fim do horizonte de geração.
  ///
  /// Fase 6 — REC-01: os 12 meses deixaram de ser o TETO e viraram o
  /// FALLBACK. Com `Repetir até` preenchido, o horizonte é a data escolhida;
  /// em branco, continua sendo exatamente o mesmo `from.year + 1` de antes
  /// desta fase — série criada sem data de encerramento gera o mesmo conjunto
  /// de ocorrências que geraria ontem. O teto duro de 24 meses é a constraint
  /// `event_series_horizon_chk` do servidor; a validação da tela é UX.
  DateTime _recurrenceUntil(DateTime from) {
    if (_recurrenceEndDate != null) {
      return DateTime(
        _recurrenceEndDate!.year,
        _recurrenceEndDate!.month,
        _recurrenceEndDate!.day,
        23,
        59,
      );
    }
    return DateTime(from.year + 1, from.month, from.day, 23, 59);
  }

  /// Validação local espelhando os CHECKs `event_series_end_after_anchor_chk`
  /// e `event_series_horizon_chk`, no mesmo espírito do `reminder_picker`:
  /// o líder descobre o limite na tela, não por erro do Postgres. A
  /// autoridade continua sendo a constraint.
  bool _validateRecurrenceEndDate(DateTime date) {
    final hoje = DateTime.now();
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final dia = DateTime(date.year, date.month, date.day);

    if (dia.isBefore(amanha)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de encerramento precisa ser depois de hoje.'),
        ),
      );
      return false;
    }

    final teto = _maxRecurrenceEndDate();
    if (dia.isAfter(teto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O período máximo de repetição é de 24 meses. Escolha uma data '
            'até ${DateFormat('dd/MM/yyyy').format(teto)}.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _pickRecurrenceEndDate() async {
    final hoje = DateTime.now();
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final teto = _maxRecurrenceEndDate();

    final escolhida = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? amanha,
      firstDate: amanha,
      lastDate: teto,
      locale: const Locale('pt', 'BR'),
    );

    if (escolhida == null || !mounted) return;
    if (!_validateRecurrenceEndDate(escolhida)) return;

    setState(
      () => _recurrenceEndDate = DateTime(
        escolhida.year,
        escolhida.month,
        escolhida.day,
      ),
    );
  }

  /// Fase 6 — REC-01 / IC-1: texto da prévia local do bloco de repetição.
  String _seriesPreviewText() {
    if (_fixedWeekdays.isEmpty) {
      return 'Escolha os dias da semana para ver quantas ocorrências serão geradas.';
    }

    final padrao = describeSeriesPattern(
      patternGroup: _fixedPatternGroup,
      variableType: _fixedPatternGroup == 'variavel' ? _variableType : null,
      weekdays: _fixedWeekdays.toList(),
      intervalWeeks: _intervalWeeks,
      monthlyOrdinal: _variableMonthlyOrdinal,
    );

    // `variavel/unico` gera uma ocorrência só e não é série: não há período a
    // resumir, só o padrão.
    if (_isVariavelUnico) return '$padrao.';

    final from = DateTime.now();
    final datas = _computeOccurrenceDates(from, _recurrenceUntil(from));
    if (datas.isEmpty) return '$padrao.';

    final formato = DateFormat('dd/MM/yyyy');
    final inicio = formato.format(datas.first);
    final fim = formato.format(datas.last);

    // Plural pela contagem real — `ocorrência(s)` com parêntese é proibido
    // pelo contrato de copy.
    if (datas.length == 1) {
      return '$padrao. Será gerada 1 ocorrência, de $inicio até $fim.';
    }
    return '$padrao. Serão geradas ${datas.length} ocorrências, '
        'de $inicio até $fim.';
  }

  /// Fase 6 — REC-01: sequência de datas de ocorrência de uma série.
  ///
  /// Extraída do ramo `_isFixed` de `_saveEvent` **sem nenhuma alteração de
  /// regra de data**: os três ramos (`semanal`, `variavel/quinzenal`,
  /// `variavel/dias`) e os helpers `_matchesWeekInterval`,
  /// `_firstMatchOnOrAfter`, `_isOrdinalOfMonth` e `_nthWeekdayOfMonth` são os
  /// mesmos de antes desta fase. Existe para que a prévia da tela e o loop de
  /// criação contem exatamente as mesmas ocorrências — duas implementações
  /// divergiriam e a prévia passaria a mentir.
  ///
  /// `variavel/unico` fica de fora de propósito: não é série (ver
  /// [_isVariavelUnico]) e continua no caminho próprio de `_saveEvent`.
  List<DateTime> _computeOccurrenceDates(DateTime from, DateTime until) {
    final datas = <DateTime>[];
    if (_fixedWeekdays.isEmpty) return datas;

    final hora = _startTime ?? const TimeOfDay(hour: 0, minute: 0);

    if (_fixedPatternGroup == 'semanal') {
      DateTime cursor = DateTime(from.year, from.month, from.day);
      while (!cursor.isAfter(until)) {
        if (_fixedWeekdays.contains(cursor.weekday)) {
          if (_matchesWeekInterval(from, cursor, _intervalWeeks)) {
            datas.add(
              DateTime(
                cursor.year,
                cursor.month,
                cursor.day,
                hora.hour,
                hora.minute,
              ),
            );
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    } else if (_fixedPatternGroup == 'variavel') {
      if (_variableType == 'quinzenal') {
        final first = _firstMatchOnOrAfter(from, _fixedWeekdays) ?? from;
        DateTime cursor = DateTime(
          first.year,
          first.month,
          first.day,
          hora.hour,
          hora.minute,
        );
        while (!cursor.isAfter(until)) {
          datas.add(cursor);
          cursor = cursor.add(Duration(days: 7 * _intervalWeeks));
        }
      } else if (_variableType == 'dias') {
        final base = _firstMatchOnOrAfter(from, _fixedWeekdays) ?? from;
        DateTime cursor = DateTime(base.year, base.month, base.day);
        while (!cursor.isAfter(until)) {
          final weekdayOk = _fixedWeekdays.contains(cursor.weekday);
          final ordinalOk = _variableMonthlyOrdinal == null
              ? true
              : _isOrdinalOfMonth(cursor, _variableMonthlyOrdinal!);
          if (weekdayOk && ordinalOk) {
            datas.add(
              DateTime(
                cursor.year,
                cursor.month,
                cursor.day,
                hora.hour,
                hora.minute,
              ),
            );
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      }
    }

    return datas;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
      default:
        return 'Dom';
    }
  }

  bool _matchesWeekInterval(DateTime from, DateTime date, int interval) {
    final days = date.difference(from).inDays;
    final weeks = days ~/ 7;
    return weeks % interval == 0;
  }

  DateTime? _firstMatchOnOrAfter(DateTime start, Set<int> weekdays) {
    DateTime cursor = start;
    for (int i = 0; i < 7; i++) {
      if (weekdays.contains(cursor.weekday)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  bool _isOrdinalOfMonth(DateTime date, int ordinal) {
    final nth = _nthWeekdayOfMonth(
      date.year,
      date.month,
      date.weekday,
      ordinal,
    );
    return nth != null && nth.day == date.day;
  }

  DateTime? _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    DateTime date = DateTime(year, month, 1);
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    date = date.add(Duration(days: (n - 1) * 7));
    return date.month == month ? date : null;
  }

  void _handleDiasChip(int d, bool sel) {
    int next(int x) => x == 7 ? 1 : x + 1;
    if (sel) {
      if (_diasBase == null) {
        _diasBase = d;
        _fixedWeekdays
          ..clear()
          ..add(d);
        return;
      }
      int last = _diasBase!;
      while (_fixedWeekdays.contains(last)) {
        final n = next(last);
        if (_fixedWeekdays.contains(n)) {
          last = n;
        } else {
          break;
        }
      }
      final expected = next(last);
      if (d == expected) {
        _fixedWeekdays.add(d);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selecione ${_weekdayLabel(expected)}')),
        );
      }
    } else {
      if (_diasBase == null) return;
      int last = _diasBase!;
      while (_fixedWeekdays.contains(last)) {
        final n = next(last);
        if (_fixedWeekdays.contains(n)) {
          last = n;
        } else {
          break;
        }
      }
      if (d == _diasBase) {
        if (d == last) {
          _fixedWeekdays.remove(d);
          if (_fixedWeekdays.isEmpty) _diasBase = null;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Remova primeiro ${_weekdayLabel(last)}')),
          );
        }
      } else if (d == last) {
        _fixedWeekdays.remove(d);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remova primeiro ${_weekdayLabel(last)}')),
        );
      }
    }
  }

  // removido: última semana do mês não é necessária
}
