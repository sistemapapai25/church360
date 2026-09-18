import 'package:flutter/material.dart';

/// Um item configurável da seção "VISÃO GERAL" da aba Mais (F6).
///
/// O catálogo é do cliente, não do banco. `public.user_more_menu_item` guarda
/// só a escolha da pessoa (`item_key`, `is_visible`, `sort_order`) — quem
/// decide se ela **pode** ver o item continua sendo o Dart, onde os gates já
/// vivem: `ConditionalDashboardAccess` para "Liderança", vínculo de ministério
/// para "Meus Ministérios", `hasMultipleUnitsProvider` para "Trocar de igreja".
///
/// Espelhar isso em SQL duplicaria a dívida que o CHU-309 declara no próprio
/// cabeçalho ("precisa ficar em sincronia manual com
/// dashboard_widget_permissions.dart"), e seria pior aqui: estes gates são
/// composição de widget, não um mapa de código de permissão. Não cabem num
/// `CASE`.
@immutable
class MoreMenuItem {
  const MoreMenuItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.color,
    this.route,
  });

  /// Chave estável gravada em `user_more_menu_item.item_key`. Nunca renomear
  /// uma chave já publicada: a preferência salva de quem já configurou a tela
  /// passaria a ser ignorada (regra 1 do provider) e o item voltaria para o
  /// fim da lista, visível, sem aviso.
  final String key;

  final IconData icon;
  final String label;
  final Color color;

  /// Rota de destino, ou `null` quando o item não é um card de rota fixa.
  /// Hoje só `my_ministries` cai nesse caso: é uma seção que se expande em um
  /// card por ministério, cada um indo para `/ministries/:id`.
  final String? route;
}

/// Registro canônico dos itens configuráveis, **na ordem de hoje** — que é
/// também a ordem padrão de quem nunca abriu a tela de configuração.
///
/// Fora daqui, e portanto nunca escondíveis: o seletor de tema, "Ver tour de
/// novo", "Configurar esta tela" e "Sair do aplicativo". Se a entrada da
/// configuração pudesse ser escondida, a pessoa se trancaria fora dela sem
/// caminho de volta; se "Sair" pudesse, ficaria sem logout.
const List<MoreMenuItem> kMoreMenuRegistry = <MoreMenuItem>[
  MoreMenuItem(
    key: 'profile',
    icon: Icons.person,
    label: 'Ver meu perfil',
    route: '/profile',
    color: Colors.blue,
  ),
  MoreMenuItem(
    key: 'live_stream',
    icon: Icons.live_tv_outlined,
    label: 'Culto ao vivo',
    route: '/live-stream',
    color: Colors.deepOrange,
  ),
  MoreMenuItem(
    key: 'leadership',
    icon: Icons.dashboard_outlined,
    label: 'Liderança',
    route: '/dashboard',
    color: Colors.redAccent,
  ),
  MoreMenuItem(
    key: 'my_ministries',
    icon: Icons.groups_outlined,
    label: 'Meus Ministérios',
    color: Colors.indigo,
  ),
  MoreMenuItem(
    key: 'kids_registration',
    icon: Icons.child_care_outlined,
    label: 'Inscrição Kids',
    route: '/kids-registration',
    color: Colors.pink,
  ),
  MoreMenuItem(
    key: 'church_info',
    icon: Icons.church_outlined,
    label: 'A Igreja',
    route: '/church-info',
    color: Colors.purple,
  ),
  MoreMenuItem(
    key: 'switch_church',
    icon: Icons.swap_horiz_outlined,
    label: 'Trocar de igreja',
    route: '/select-church',
    color: Colors.teal,
  ),
];

/// A preferência salva de um item, como está no banco.
@immutable
class MoreMenuPreference {
  const MoreMenuPreference({required this.isVisible, required this.sortOrder});

  final bool isVisible;
  final int sortOrder;
}
