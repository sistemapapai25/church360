import 'package:flutter/material.dart';

import '../../domain/models/member.dart';

/// Marcos da vida da pessoa que já estão no cadastro, na ordem em que a vida
/// acontece. Usado pelo cartão Minha Caminhada do perfil e pela tela
/// `/my-journey`, para as duas mostrarem a mesma linha do tempo.
///
/// Só entra o que está preenchido: campo vazio não vira item "não informado"
/// — o cadastro é magro e a linha do tempo viraria uma lista de buracos.
///
/// As datas saem do `Member` já parseado, sem conversão de fuso: o banco
/// guarda hora de parede de São Paulo rotulada como UTC, e converter faria a
/// linha do tempo divergir em um dia da data que a ficha mostra.
List<({DateTime when, String title, String subtitle, IconData icon})>
memberLifeEvents(Member m) => [
  for (final (date, title, subtitle, icon) in [
    (m.birthdate, 'Nascimento', 'Data de nascimento', Icons.cake_outlined),
    (
      m.firstVisitDate,
      'Primeira visita',
      'Primeira vez na igreja',
      Icons.waving_hand_outlined,
    ),
    (
      m.conversionDate,
      'Conversão',
      'Data de conversão',
      Icons.auto_awesome_outlined,
    ),
    (m.baptismDate, 'Batismo', 'Batismo nas águas', Icons.water_drop_outlined),
    (m.marriageDate, 'Casamento', 'Data de casamento', Icons.favorite_outline),
    (
      m.membershipDate,
      'Tornou-se membro',
      'Entrada para o rol de membros',
      Icons.badge,
    ),
  ])
    if (date != null)
      (when: date, title: title, subtitle: subtitle, icon: icon),
];
