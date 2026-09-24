// O catálogo de tipos de ministério, como o banco o conta.
//
// Substitui o enum `MinistryType` e o mapa `ministryTypeTabPreview`, que eram
// duas das quatro cópias da mesma lista (as outras duas eram o `switch` de
// rota e o `IN (...)` da RPC `create_ministry_with_leader`). Desde a Fase 2 a
// lista mora em `public.ministry_type` e o app lê — ver a migration
// `20260924000200_ministry_type_catalogo.sql`.
//
// O QUE O CATÁLOGO DECIDE: quais abas um tipo abre, em que ordem, com que
// rótulo, qual o atalho de rota dele e se ele aparece no seletor de criação.
//
// O QUE ELE NÃO DECIDE: o que cada aba mostra. `key` casa com um widget
// registrado no Dart (MinistryTabKeys); uma chave que o app não conhece é
// ignorada, porque uma aba sem widget nasceria vazia.

import 'package:flutter/foundation.dart';

/// As chaves de aba que este app sabe montar.
///
/// Cada uma tem um widget correspondente registrado em alguma das quatro
/// telas de workspace. Chave nova no banco só vira aba depois de alguém
/// registrar o widget dela — até lá, o app a ignora em silêncio (em debug,
/// com aviso).
abstract final class MinistryTabKeys {
  static const equipe = 'equipe';
  static const escala = 'escala';
  static const financeiro = 'financeiro';
  static const whatsapp = 'whatsapp';
  static const relatorios = 'relatorios';

  // Batismo
  static const alunos = 'alunos';
  static const checklist = 'checklist';
  static const presenca = 'presenca';

  // Raízes e Diaconato
  static const painel = 'painel';
}

/// Os códigos de tipo que o Dart precisa nomear porque tem tela própria para
/// eles. Não é a lista de tipos que existem — essa é o catálogo.
abstract final class MinistryTypeCodes {
  static const generic = 'generic';
  static const batismo = 'batismo';
  static const raizes = 'raizes';
  static const diaconato = 'diaconato';
}

/// Uma aba do catálogo: a chave que acha o widget e o rótulo que a pessoa lê.
@immutable
class MinistryTypeTab {
  final String key;
  final String label;

  const MinistryTypeTab(this.key, this.label);

  static MinistryTypeTab? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final label = json['label'];
    if (key is! String || key.isEmpty) return null;
    if (label is! String || label.isEmpty) return null;
    return MinistryTypeTab(key, label);
  }

  @override
  bool operator ==(Object other) =>
      other is MinistryTypeTab && other.key == key && other.label == label;

  @override
  int get hashCode => Object.hash(key, label);

  @override
  String toString() => 'MinistryTypeTab($key, $label)';
}

/// Um tipo de ministério, com tudo que o app precisa saber sobre ele.
@immutable
class MinistryTypeSpec {
  final String code;
  final String label;
  final String description;

  /// Abas na ordem em que aparecem na tela.
  final List<MinistryTypeTab> tabs;

  /// Sufixo do atalho especializado, com a barra (`/batismo`). `null` quer
  /// dizer que o tipo abre em `/ministries/:id` mesmo.
  final String? routeSuffix;

  final bool offeredOnCreate;
  final int sortOrder;

  const MinistryTypeSpec({
    required this.code,
    required this.label,
    this.description = '',
    this.tabs = const [],
    this.routeSuffix,
    this.offeredOnCreate = false,
    this.sortOrder = 100,
  });

  /// Linha do banco. Devolve `null` para linha sem `code` — é o único campo
  /// sem substituto razoável.
  static MinistryTypeSpec? tryFromJson(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is! String || code.isEmpty) return null;

    final rawTabs = json['tabs'];
    final tabs = <MinistryTypeTab>[];
    if (rawTabs is List) {
      for (final raw in rawTabs) {
        final tab = MinistryTypeTab.tryFromJson(raw);
        if (tab != null) {
          tabs.add(tab);
        } else if (kDebugMode) {
          debugPrint(
            'ministry_type[$code]: elemento de "tabs" ignorado (fora da '
            'forma {"key","label"}): $raw',
          );
        }
      }
    }

    final suffix = json['route_suffix'];

    return MinistryTypeSpec(
      code: code,
      label: json['label'] is String && (json['label'] as String).isNotEmpty
          ? json['label'] as String
          : code,
      description: json['description'] as String? ?? '',
      tabs: tabs,
      routeSuffix: suffix is String && suffix.isNotEmpty ? suffix : null,
      offeredOnCreate: json['offered_on_create'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
    );
  }

  /// Os rótulos das abas, na ordem — é o que a prévia do formulário mostra.
  List<String> get tabLabels => [for (final t in tabs) t.label];

  /// O caminho para abrir este ministério.
  String routeFor(String ministryId) =>
      '/ministries/$ministryId${routeSuffix ?? ''}';
}

/// O catálogo inteiro, já ordenado.
@immutable
class MinistryTypeCatalog {
  final List<MinistryTypeSpec> types;

  const MinistryTypeCatalog(this.types);

  factory MinistryTypeCatalog.fromRows(List<Map<String, dynamic>> rows) {
    final specs = <MinistryTypeSpec>[];
    for (final row in rows) {
      final spec = MinistryTypeSpec.tryFromJson(row);
      if (spec != null) specs.add(spec);
    }
    specs.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.code.compareTo(b.code);
    });
    return MinistryTypeCatalog(specs);
  }

  /// O tipo de código [code], ou `null` se o catálogo não o conhece.
  MinistryTypeSpec? specFor(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final t in types) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// Os tipos que o formulário oferece na criação, na ordem do catálogo.
  ///
  /// A RPC `create_ministry_with_leader` valida contra esta mesma coluna no
  /// servidor: tipo fora daqui volta `22023`.
  List<MinistryTypeSpec> get offeredOnCreate =>
      [for (final t in types) if (t.offeredOnCreate) t];

  /// Rótulo do tipo, para leitura humana. Tipo desconhecido devolve o próprio
  /// código — é feio de propósito, para o problema aparecer na tela em vez de
  /// virar um "Comum" mentiroso.
  String labelFor(String? code) => specFor(code)?.label ?? (code ?? '');

  String descriptionFor(String? code) => specFor(code)?.description ?? '';

  /// Os rótulos das abas do tipo, para a prévia. Tipo desconhecido cai nas
  /// abas do `generic`.
  List<String> tabLabelsFor(String? code) =>
      (specFor(code) ?? specFor(MinistryTypeCodes.generic))?.tabLabels ??
      const [];

  /// Para onde navegar ao abrir [ministryId] do tipo [code]. Tipo sem atalho
  /// (ou desconhecido) abre o workspace comum.
  String routeFor({required String ministryId, String? code}) =>
      specFor(code)?.routeFor(ministryId) ?? '/ministries/$ministryId';

  /// O catálogo embutido, usado enquanto o do banco não chegou — e se ele
  /// nunca chegar (falha de rede, RLS, tabela ausente num restore).
  ///
  /// É cópia do seed da migration `20260924000200`, e é a única cópia que
  /// sobrou de propósito: sem ela, uma falha de leitura deixaria todo
  /// ministério sem aba nenhuma. `ministry_type_catalog_test.dart` trava esta
  /// lista; divergir do banco vira teste vermelho, não tela vazia.
  static const fallback = MinistryTypeCatalog([
    MinistryTypeSpec(
      code: MinistryTypeCodes.generic,
      label: 'Comum',
      description: 'Equipe, escala, caixa, avisos e relatórios.',
      tabs: [
        MinistryTypeTab(MinistryTabKeys.equipe, 'Equipe'),
        MinistryTypeTab(MinistryTabKeys.escala, 'Escala'),
        MinistryTypeTab(MinistryTabKeys.financeiro, 'Financeiro'),
        MinistryTypeTab(MinistryTabKeys.whatsapp, 'WhatsApp'),
        MinistryTypeTab(MinistryTabKeys.relatorios, 'Relatórios'),
      ],
      offeredOnCreate: true,
      sortOrder: 10,
    ),
    MinistryTypeSpec(
      code: MinistryTypeCodes.batismo,
      label: 'Batismo',
      description: 'Turmas, alunos, checklist e presença.',
      tabs: [
        MinistryTypeTab(MinistryTabKeys.equipe, 'Equipe'),
        MinistryTypeTab(MinistryTabKeys.escala, 'Escala'),
        MinistryTypeTab(MinistryTabKeys.financeiro, 'Financeiro'),
        MinistryTypeTab(MinistryTabKeys.alunos, 'Alunos'),
        MinistryTypeTab(MinistryTabKeys.checklist, 'Checklist'),
        MinistryTypeTab(MinistryTabKeys.presenca, 'Presença'),
        MinistryTypeTab(MinistryTabKeys.whatsapp, 'WhatsApp'),
        MinistryTypeTab(MinistryTabKeys.relatorios, 'Relatórios'),
      ],
      routeSuffix: '/batismo',
      offeredOnCreate: true,
      sortOrder: 20,
    ),
    MinistryTypeSpec(
      code: MinistryTypeCodes.raizes,
      label: 'Raízes',
      description: 'Painel de visitas e acompanhamento.',
      tabs: [
        MinistryTypeTab(MinistryTabKeys.painel, 'Painel'),
        MinistryTypeTab(MinistryTabKeys.equipe, 'Equipe'),
        MinistryTypeTab(MinistryTabKeys.escala, 'Escala'),
        MinistryTypeTab(MinistryTabKeys.financeiro, 'Financeiro'),
        MinistryTypeTab(MinistryTabKeys.whatsapp, 'WhatsApp'),
        MinistryTypeTab(MinistryTabKeys.relatorios, 'Relatórios'),
      ],
      routeSuffix: '/raizes',
      offeredOnCreate: true,
      sortOrder: 30,
    ),
    MinistryTypeSpec(
      code: MinistryTypeCodes.diaconato,
      label: 'Diaconato',
      description: 'Painel de triagem e ceias.',
      tabs: [
        MinistryTypeTab(MinistryTabKeys.painel, 'Painel'),
        MinistryTypeTab(MinistryTabKeys.equipe, 'Equipe'),
        MinistryTypeTab(MinistryTabKeys.escala, 'Escala'),
        MinistryTypeTab(MinistryTabKeys.financeiro, 'Financeiro'),
        MinistryTypeTab(MinistryTabKeys.whatsapp, 'WhatsApp'),
        MinistryTypeTab(MinistryTabKeys.relatorios, 'Relatórios'),
      ],
      routeSuffix: '/diaconato',
      offeredOnCreate: true,
      sortOrder: 40,
    ),
  ]);
}
