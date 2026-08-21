import 'package:flutter/material.dart';

/// Uma opção do filtro de categoria. `value == null` é "todas".
class PermissionCategoryOption {
  const PermissionCategoryOption(this.value, this.label);

  final String? value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is PermissionCategoryOption && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Rótulo e ícone das categorias de permissão (CHU-315).
///
/// Cada tela de permissão tinha — ou não tinha — o seu próprio mapa de
/// tradução: a de Cargo cobria parte das categorias, a de Usuário mostrava o
/// código cru do banco (`church_info`, `live_stream`, ...) e o Catálogo só
/// fazia Title Case do inglês. Este helper é a fonte única e cobre as 28
/// categorias que existem hoje no catálogo do tenant.
class PermissionCategoryDisplay {
  const PermissionCategoryDisplay._();

  static const Map<String, String> _labels = {
    'agents': 'Agentes IA',
    'banners': 'Banners',
    'bible': 'Bíblia',
    'church_info': 'Igreja',
    'courses': 'Cursos',
    'dashboard': 'Dashboard',
    'devotionals': 'Devocionais',
    'dispatch': 'Disparos',
    'events': 'Eventos',
    'financial': 'Financeiro',
    'groups': 'Grupos',
    'kids': 'Kids',
    'lgpd': 'LGPD',
    'live_stream': 'Culto ao vivo',
    'members': 'Membros',
    'ministries': 'Ministérios',
    'news': 'Notícias',
    'notifications': 'Notificações',
    'prayer_requests': 'Pedidos de Oração',
    'reading_plans': 'Planos de Leitura',
    'reports': 'Relatórios',
    'settings': 'Configurações',
    'study_groups': 'Grupos de Estudo',
    'support_materials': 'Materiais de Apoio',
    'tags': 'Tags',
    'testimonies': 'Testemunhos',
    'visitors': 'Visitantes',
    'worship': 'Cultos',
  };

  static const Map<String, IconData> _icons = {
    'agents': Icons.smart_toy,
    'banners': Icons.image,
    'bible': Icons.menu_book_rounded,
    'church_info': Icons.info,
    'courses': Icons.class_,
    'dashboard': Icons.dashboard,
    'devotionals': Icons.menu_book,
    'dispatch': Icons.send,
    'events': Icons.event,
    'financial': Icons.attach_money,
    'groups': Icons.group,
    'kids': Icons.child_care,
    'lgpd': Icons.privacy_tip,
    'live_stream': Icons.live_tv,
    'members': Icons.people,
    'ministries': Icons.church,
    'news': Icons.article,
    'notifications': Icons.notifications,
    'prayer_requests': Icons.volunteer_activism,
    'reading_plans': Icons.menu_book_outlined,
    'reports': Icons.assessment,
    'settings': Icons.settings,
    'study_groups': Icons.school,
    'support_materials': Icons.folder,
    'tags': Icons.label,
    'testimonies': Icons.record_voice_over,
    'visitors': Icons.person_add,
    'worship': Icons.church_outlined,
  };

  /// Categorias com tradução própria. Usado nos testes para travar a cobertura
  /// do catálogo real.
  static Iterable<String> get knownCategories => _labels.keys;

  /// Rótulo em português da categoria. Categorias novas (criadas no banco
  /// depois desta versão do app) caem no fallback, que ao menos nunca devolve
  /// `snake_case` cru para a UI.
  static String label(String category) {
    final key = category.trim().toLowerCase();
    final known = _labels[key];
    if (known != null) return known;
    return _prettify(key);
  }

  static IconData icon(String category) {
    return _icons[category.trim().toLowerCase()] ?? Icons.security;
  }

  /// Opções do filtro de categoria montadas a partir das permissões
  /// carregadas, já ordenadas pelo rótulo traduzido (CHU-318).
  static List<PermissionCategoryOption> optionsFrom(
    Iterable<String> categories, {
    String allLabel = 'Todas categorias',
  }) {
    final unique = categories.map((c) => c.trim().toLowerCase()).toSet().toList()
      ..sort((a, b) => label(a).compareTo(label(b)));
    return [
      PermissionCategoryOption(null, allLabel),
      ...unique.map((c) => PermissionCategoryOption(c, label(c))),
    ];
  }

  static String _prettify(String category) {
    final words = category
        .split(RegExp(r'[_\s.\-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1));
    if (words.isEmpty) return 'Outras';
    return words.join(' ');
  }
}
