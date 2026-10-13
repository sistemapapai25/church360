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
}
