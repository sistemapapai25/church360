import 'package:intl/intl.dart';

/// Item do feed do evento (`public.event_update`): aviso manual ou mudança
/// gravada pelo gatilho do banco. Valores de data em [EventChange] seguem o
/// contrato parede-como-UTC do app: formatar os campos direto, sem toLocal.
class EventUpdate {
  final String id;
  final String eventId;
  final bool isNotice;
  final String? title;
  final String? body;
  final List<EventChange> changes;
  final String? createdBy;
  final DateTime createdAt;

  const EventUpdate({
    required this.id,
    required this.eventId,
    required this.isNotice,
    this.title,
    this.body,
    this.changes = const [],
    this.createdBy,
    required this.createdAt,
  });

  factory EventUpdate.fromJson(Map<String, dynamic> json) {
    return EventUpdate(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      isNotice: json['kind'] == 'notice',
      title: json['title'] as String?,
      body: json['body'] as String?,
      changes: [
        for (final c in (json['changes'] as List?) ?? const [])
          EventChange.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
      createdBy: json['created_by'] as String?,
      // created_at é instante real (now() do banco), não hora de parede.
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  /// Título do cartão de mudança: o campo, se for um só; senão genérico.
  String get changeTitle {
    if (changes.length == 1) return changes.first.title;
    return 'Evento atualizado';
  }
}

/// Um campo alterado: `{field, old_value, new_value}` com valores crus.
class EventChange {
  final String field;
  final Object? oldValue;
  final Object? newValue;

  const EventChange({required this.field, this.oldValue, this.newValue});

  factory EventChange.fromJson(Map<String, dynamic> json) => EventChange(
    field: json['field'] as String,
    oldValue: json['old_value'],
    newValue: json['new_value'],
  );

  bool get _isDate => field == 'start_date' || field == 'end_date';

  DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  String get title {
    switch (field) {
      case 'name':
        return 'Nome alterado';
      case 'start_date':
        final a = _date(oldValue), b = _date(newValue);
        final mesmoDia =
            a != null &&
            b != null &&
            a.year == b.year &&
            a.month == b.month &&
            a.day == b.day;
        return mesmoDia ? 'Horário alterado' : 'Data alterada';
      case 'end_date':
        return 'Término alterado';
      case 'location':
        return 'Local alterado';
      case 'status':
        return newValue == 'cancelled' ? 'Evento cancelado' : 'Status alterado';
      default:
        return 'Evento atualizado';
    }
  }

  /// Rótulo curto do campo, para as linhas do cartão com várias mudanças.
  String get fieldLabel => switch (field) {
    'name' => 'Nome',
    'start_date' => 'Início',
    'end_date' => 'Término',
    'location' => 'Local',
    'status' => 'Status',
    _ => field,
  };

  String _fmt(Object? v) {
    if (v == null || (v is String && v.trim().isEmpty)) {
      return switch (field) {
        'end_date' => 'sem término',
        'location' => 'sem local',
        _ => '—',
      };
    }
    if (_isDate) {
      final d = _date(v);
      if (d == null) return v.toString();
      final a = _date(oldValue), b = _date(newValue);
      final mesmoDia =
          a != null &&
          b != null &&
          a.year == b.year &&
          a.month == b.month &&
          a.day == b.day;
      return DateFormat(
        mesmoDia ? 'HH:mm' : "dd/MM 'às' HH:mm",
        'pt_BR',
      ).format(d);
    }
    if (field == 'status') {
      return switch (v) {
        'draft' => 'Rascunho',
        'published' => 'Publicado',
        'cancelled' => 'Cancelado',
        'completed' => 'Finalizado',
        _ => v.toString(),
      };
    }
    return v.toString();
  }

  /// "de 19:00 para 19:30" — também é o que o leitor de tela lê.
  String get fromTo => 'de ${_fmt(oldValue)} para ${_fmt(newValue)}';
}

/// "agora", "há 5 min", "há 3 h", "ontem", "há 4 dias", depois a data.
String eventUpdateTimeAgo(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(at);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  final hoje = DateTime(n.year, n.month, n.day);
  final dia = DateTime(at.year, at.month, at.day);
  final dias = hoje.difference(dia).inDays;
  if (dias == 0) return 'há ${diff.inHours} h';
  if (dias == 1) return 'ontem';
  if (dias < 7) return 'há $dias dias';
  return DateFormat('dd/MM', 'pt_BR').format(at);
}

/// Cabeçalho de dia da tela "Ver todas": HOJE, ONTEM ou a data.
String eventUpdateDayHeader(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final dias = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (dias == 0) return 'HOJE';
  if (dias == 1) return 'ONTEM';
  return DateFormat("d 'de' MMMM", 'pt_BR').format(at).toUpperCase();
}
