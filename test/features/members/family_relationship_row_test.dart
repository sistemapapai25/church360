import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/members/data/family_relationships_repository.dart';

/// Linhas órfãs são reais: `membro_id`/`parente_id` são nullable no banco e a
/// FK para `user_account` é SET NULL, então excluir uma ficha deixa para trás
/// o vínculo com um dos lados vazio. Antes disto, um `as String` nessa linha
/// derrubava a lista inteira de vínculos do membro.
void main() {
  Map<String, dynamic> row({
    Object? id = 'r1',
    Object? membroId = 'm1',
    Object? parenteId = 'p1',
    Object? tipo = 'pai',
  }) => {
        'id': id,
        'membro_id': membroId,
        'parente_id': parenteId,
        'tipo_relacionamento': tipo,
      };

  group('familyRelationshipFromRow', () {
    test('linha completa vira vínculo', () {
      final rel = familyRelationshipFromRow(row());
      expect(rel, isNotNull);
      expect(rel!.id, 'r1');
      expect(rel.membroId, 'm1');
      expect(rel.parenteId, 'p1');
      expect(rel.tipo, 'pai');
    });

    test('membro_id nulo (ficha do outro lado excluída) é descartado', () {
      expect(familyRelationshipFromRow(row(membroId: null)), isNull);
    });

    test('parente_id nulo é descartado', () {
      expect(familyRelationshipFromRow(row(parenteId: null)), isNull);
    });

    test('id ou tipo ausentes são descartados', () {
      expect(familyRelationshipFromRow(row(id: null)), isNull);
      expect(familyRelationshipFromRow(row(tipo: null)), isNull);
    });

    test('valor de tipo inesperado não passa por String', () {
      expect(familyRelationshipFromRow(row(membroId: 42)), isNull);
    });

    test('linha que não é mapa não derruba a leitura', () {
      expect(familyRelationshipFromRow('nada disso'), isNull);
    });
  });
}
