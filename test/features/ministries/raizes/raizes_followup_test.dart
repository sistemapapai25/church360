import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/ministries/raizes/domain/models/raizes_followup.dart';

void main() {
  test('as 11 etapas batem com o CHECK da 004900 e null é visitante novo', () {
    expect(RaizesStage.values.map((s) => s.value), [
      'visitante_novo',
      'contactado',
      'retornou',
      'em_acompanhamento',
      'aceitou_jesus',
      'reconciliacao',
      'encaminhado_casa_vida',
      'em_discipulado',
      'em_aulas_batismo',
      'novo_membro',
      'integrado_departamento',
    ]);
    expect(RaizesStage.fromValue(null), RaizesStage.visitanteNovo);
  });

  test('linha do tempo lê contato e mudança de etapa', () {
    final c = RaizesTimelineEntry.fromContact({
      'followup_date': '2026-10-12',
      'followup_type': 'ligacao',
      'description': 'Atendeu',
      'by': {'first_name': 'Ana', 'last_name': 'Lima'},
    });
    expect(c.title, 'Contato: Ligação');
    expect(c.byName, 'Ana Lima');
    expect(c.isContact, isTrue);

    final s = RaizesTimelineEntry.fromStage({
      'changed_at': '2026-10-12T15:00:00Z',
      'from_stage': null,
      'to_stage': 'contactado',
      'note': null,
      'by': null,
    });
    expect(s.title, 'Etapa: Visitante novo → Contactado');
    expect(s.byName, isNull);
  });

  test('decisão: valores do CHECK da 004800 e etapa sugerida', () {
    expect(RaizesDecision.values.map((d) => d.value), [
      'accepted_jesus',
      'reconciliation',
      'pastoral_support',
    ]);
    expect(RaizesDecision.fromValue(null), isNull);
    expect(
      RaizesDecision.acceptedJesus.suggestedStage,
      RaizesStage.aceitouJesus,
    );
    expect(RaizesDecision.pastoralSupport.suggestedStage, isNull);
  });

  test('Casa de Vida: mesmo bairro primeiro e detalhes legíveis', () {
    final houses = [
      RaizesLifeHouse.fromJson({'id': 'a', 'name': 'Alfa', 'meeting_address': 'Rua 1, Vila Nova'}),
      RaizesLifeHouse.fromJson({
        'id': 'b',
        'name': 'Beta',
        'meeting_address': 'Rua 2, Centro',
        'meeting_day_of_week': 3,
        'meeting_time': '20:00:00',
        'leader_name': 'Ana',
      }),
    ];
    expect(sortLifeHouses(houses, 'centro').map((h) => h.id), ['b', 'a']);
    expect(sortLifeHouses(houses, null).map((h) => h.id), ['a', 'b']);
    expect(houses[1].details, 'Quarta 20:00 · Rua 2, Centro · Líder: Ana');
  });

  test('RaizesReport lê o JSON da raizes_report (005500)', () {
    final r = RaizesReport.fromJson({
      'since': '2026-05-01',
      'funnel': {'visitante_novo': 8, 'contactado': 2, 'xyz': 1},
      'contact_24h': {'total': 4, 'on_time': 3, 'late': 0, 'none': 1},
      'visits': [
        {'name': 'Ana', 'total': 3, 'completed': 2, 'open': 1},
      ],
      'decisions': [
        {'month': '2026-10', 'type': 'reconciliation', 'count': 1},
        {'month': '2026-10', 'type': 'accepted_jesus', 'count': 2},
        {'month': '2026-10', 'type': 'outro', 'count': 9},
      ],
    });
    // Etapa desconhecida cai em Visitante novo, como no resto do app.
    expect(r.funnel[RaizesStage.visitanteNovo], 9);
    expect(r.funnel[RaizesStage.contactado], 2);
    expect(r.contactOnTime, 3);
    expect(r.contactNone, 1);
    expect(r.visits.single.open, 1);
    expect(r.decisionsByMonth['2026-10'], {
      RaizesDecision.reconciliation: 1,
      RaizesDecision.acceptedJesus: 2,
    });
  });
}
