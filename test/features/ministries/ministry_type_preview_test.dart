import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/shared/domain/ministry_type_preview.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trava a prévia de abas do formulário contra as telas que montam o shell de
/// verdade. Enquanto a Fase 2 não trocar o `switch` por catálogo no banco, as
/// duas listas vivem em lugares diferentes — este teste é o que faz a
/// divergência aparecer aqui, e não como prévia mentirosa na tela de quem vai
/// criar um ministério.
void main() {
  group('prévia de abas por tipo', () {
    test('comum abre as cinco de base (generic_ministry_home_screen)', () {
      expect(ministryTabsFor(MinistryType.generic), [
        'Equipe',
        'Escala',
        'Financeiro',
        'Avisos',
        'Relatórios',
      ]);
    });

    test('batismo tem as do módulo e NÃO tem Avisos', () {
      final tabs = ministryTabsFor(MinistryType.batismo);
      expect(tabs, [
        'Equipe',
        'Escala',
        'Financeiro',
        'Alunos',
        'Checklist',
        'Presença',
        'WhatsApp',
        'Relatórios',
      ]);
      // batismo_home_screen.dart não monta a aba Avisos — a prévia não pode
      // prometer o que a tela não abre.
      expect(tabs, isNot(contains('Avisos')));
    });

    test('raízes e diaconato são as cinco de base mais o Painel', () {
      const esperado = [
        'Painel',
        'Equipe',
        'Escala',
        'Financeiro',
        'Avisos',
        'Relatórios',
      ];
      expect(ministryTabsFor(MinistryType.raizes), esperado);
      expect(ministryTabsFor(MinistryType.diaconato), esperado);
    });

    test('tipo sem tela própria cai nas cinco de base', () {
      // kids, louvor e midia caem no mesmo `return null` do generic em
      // specializedRoutePath — o shell trata os três como comuns.
      for (final tipo in [
        MinistryType.kids,
        MinistryType.louvor,
        MinistryType.midia,
      ]) {
        expect(
          ministryTabsFor(tipo),
          ministryTabsFor(MinistryType.generic),
          reason: '$tipo não tem tela própria',
        );
      }
    });
  });

  group('tipos oferecidos na criação', () {
    test('são os quatro que a RPC aceita, na mesma ordem', () {
      // create_ministry_with_leader valida esta mesma lista no servidor e
      // devolve 22023 para qualquer outro valor. Mudar aqui sem mudar lá
      // quebra a criação em runtime, não em compilação.
      expect(ministryTypesOfferedOnCreate.map((t) => t.value).toList(), [
        'generic',
        'batismo',
        'raizes',
        'diaconato',
      ]);
    });

    test('todo tipo oferecido tem rótulo, descrição e prévia', () {
      for (final tipo in ministryTypesOfferedOnCreate) {
        expect(ministryTypeLabel(tipo), isNotEmpty);
        expect(ministryTypeDescription(tipo), isNotEmpty);
        expect(ministryTypeTabPreview[tipo], isNotNull);
      }
    });
  });
}
