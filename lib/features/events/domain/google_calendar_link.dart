import 'models/event.dart';

/// Link "Adicionar ao Google Agenda" já preenchido com o evento.
///
/// As datas do app guardam a hora de parede de São Paulo rotulada como UTC
/// (ver `event_instants`): por isso usamos os campos do DateTime como estão,
/// sem `Z`, e dizemos ao Google o fuso com `ctz`. Sem fim, assume 1 hora.
Uri googleCalendarLink(Event event) {
  String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}T'
      '${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}00';
  final end = event.endDate ?? event.startDate.add(const Duration(hours: 1));
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': event.name,
    'dates': '${fmt(event.startDate)}/${fmt(end)}',
    'ctz': 'America/Sao_Paulo',
    if ((event.description ?? '').trim().isNotEmpty)
      'details': event.description!.trim(),
    if ((event.location ?? '').trim().isNotEmpty)
      'location': event.location!.trim(),
  });
}
