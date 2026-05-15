import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Converte o nome do ícone armazenado em `ministry.icon` (Font Awesome) no
/// [IconData] correspondente. Quando `iconName` é `null` ou desconhecido,
/// retorna `fallback` (default: [FontAwesomeIcons.church]).
IconData ministryIconData(
  String? iconName, {
  IconData fallback = FontAwesomeIcons.church,
}) {
  if (iconName == null) return fallback;
  return _iconMap[iconName] ?? fallback;
}

/// Converte a cor hexadecimal armazenada em `ministry.color` (`#RRGGBB`)
/// para [Color]. Aceita valores com ou sem `#`. Se o parse falhar, retorna
/// `#2196F3` (azul) como fallback.
Color ministryColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF2196F3;
  return Color(value);
}

const Map<String, IconData> _iconMap = {
  // ADORAÇÃO & ENSINO
  'music': FontAwesomeIcons.music,
  'hands-praying': FontAwesomeIcons.handsPraying,
  'book-bible': FontAwesomeIcons.bookBible,
  'book-open': FontAwesomeIcons.bookOpen,
  'people-arrows': FontAwesomeIcons.peopleArrows,
  'masks-theater': FontAwesomeIcons.masksTheater,
  'person-running': FontAwesomeIcons.personRunning,

  // EVANGELISMO & MISSÕES
  'bullhorn': FontAwesomeIcons.bullhorn,
  'earth-americas': FontAwesomeIcons.earthAmericas,
  'house-heart': FontAwesomeIcons.house,
  'house-user': FontAwesomeIcons.houseUser,
  'people-group': FontAwesomeIcons.peopleGroup,

  // FAIXAS ETÁRIAS
  'child': FontAwesomeIcons.child,
  'child-reaching': FontAwesomeIcons.child,
  'person-cane': FontAwesomeIcons.personCane,

  // GRUPOS ESPECÍFICOS
  'user-graduate': FontAwesomeIcons.userGraduate,
  'users-between-lines': FontAwesomeIcons.users,
  'users-rays': FontAwesomeIcons.users,
  'users': FontAwesomeIcons.users,
  'heart': FontAwesomeIcons.heart,
  'person': FontAwesomeIcons.person,
  'person-dress': FontAwesomeIcons.personDress,

  // SERVIÇOS & APOIO
  'hand-holding-heart': FontAwesomeIcons.handHoldingHeart,
  'handshake': FontAwesomeIcons.handshake,
  'video': FontAwesomeIcons.video,
  'comments': FontAwesomeIcons.comments,
  'shield-halved': FontAwesomeIcons.shieldHalved,
  'car': FontAwesomeIcons.car,
  'broom': FontAwesomeIcons.broom,
  'utensils': FontAwesomeIcons.utensils,
};
