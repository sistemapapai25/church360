import '../../domain/models/ministry.dart';

/// Quais abas cada tipo de ministério abre — para mostrar **antes** de criar.
///
/// Serve à prévia do formulário: quem escolhe o tipo vê o que vai ganhar, em
/// vez de descobrir depois de salvar. É a Fase 5 do plano do ministério padrão.
///
/// **Não é a fonte de verdade das abas.** A fonte são as quatro telas que
/// montam o `MinistryWorkspaceShell`:
///
/// - `generic_ministry_home_screen.dart`  → as cinco de base;
/// - `batismo_home_screen.dart`           → sem Avisos, mais as do Batismo;
/// - `raizes_home_screen.dart`            → Painel + as cinco;
/// - `diaconato_home_screen.dart`         → Painel + as cinco.
///
/// A duplicação é consciente e tem prazo: a **Fase 2** troca o `switch` em
/// enum Dart por catálogo no banco, e aí as duas listas viram uma consulta só.
/// Até lá, `ministry_type_preview_test.dart` trava esta lista para que a
/// divergência apareça como teste vermelho, não como prévia mentirosa.
const Map<MinistryType, List<String>> ministryTypeTabPreview = {
  MinistryType.generic: [
    'Equipe',
    'Escala',
    'Financeiro',
    'Avisos',
    'Relatórios',
  ],
  MinistryType.batismo: [
    'Equipe',
    'Escala',
    'Financeiro',
    'Alunos',
    'Checklist',
    'Presença',
    'WhatsApp',
    'Relatórios',
  ],
  MinistryType.raizes: [
    'Painel',
    'Equipe',
    'Escala',
    'Financeiro',
    'Avisos',
    'Relatórios',
  ],
  MinistryType.diaconato: [
    'Painel',
    'Equipe',
    'Escala',
    'Financeiro',
    'Avisos',
    'Relatórios',
  ],
};

/// Os tipos que o formulário oferece na criação.
///
/// São quatro, e não os sete do enum [MinistryType]: `kids`, `louvor` e
/// `midia` existem no enum mas caem no mesmo `return null` do `generic` em
/// `specializedRoutePath` — não abrem tela nenhuma própria. Oferecê-los
/// prometeria uma especialização que não existe, e o banco confirma que
/// ninguém os usa (24 `generic`, 1 de cada um dos outros três, em 24/09).
///
/// A RPC `create_ministry_with_leader` valida exatamente esta mesma lista no
/// servidor — mudar aqui sem mudar lá devolve `22023`.
const List<MinistryType> ministryTypesOfferedOnCreate = [
  MinistryType.generic,
  MinistryType.batismo,
  MinistryType.raizes,
  MinistryType.diaconato,
];

/// Nome do tipo como a pessoa lê na tela.
String ministryTypeLabel(MinistryType type) {
  switch (type) {
    case MinistryType.generic:
      return 'Comum';
    case MinistryType.batismo:
      return 'Batismo';
    case MinistryType.raizes:
      return 'Raízes';
    case MinistryType.diaconato:
      return 'Diaconato';
    case MinistryType.kids:
      return 'Kids';
    case MinistryType.louvor:
      return 'Louvor';
    case MinistryType.midia:
      return 'Mídia';
  }
}

/// Uma linha explicando o que aquele tipo é, abaixo do nome no seletor.
String ministryTypeDescription(MinistryType type) {
  switch (type) {
    case MinistryType.batismo:
      return 'Turmas, alunos, checklist e presença.';
    case MinistryType.raizes:
      return 'Painel de visitas e acompanhamento.';
    case MinistryType.diaconato:
      return 'Painel de triagem e ceias.';
    case MinistryType.generic:
    case MinistryType.kids:
    case MinistryType.louvor:
    case MinistryType.midia:
      return 'Equipe, escala, caixa, avisos e relatórios.';
  }
}

/// As abas que [type] abre, para a prévia. Tipo sem entrada no mapa cai nas
/// cinco de base — é o que o `MinistryWorkspaceShell` faz de fato com
/// `kids`, `louvor` e `midia`.
List<String> ministryTabsFor(MinistryType type) =>
    ministryTypeTabPreview[type] ??
    ministryTypeTabPreview[MinistryType.generic]!;
