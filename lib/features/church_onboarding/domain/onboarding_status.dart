import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';

/// Etapas dos "Primeiros passos" do pastor (F1 do roadmap Home/culto/Dashboard,
/// 14/10/2026). Os códigos são os da RPC `onboarding_status` (008400); cada
/// etapa grava no lugar que já existe (A Igreja, Agenda, Ministérios, Membros).
enum OnboardingStep {
  identity(
    'identity',
    'Nome e logo da igreja',
    'Aparecem no topo do app e nas notificações.',
    AppIcons.church,
    '/church-info/manage',
    'Editar a igreja',
  ),
  location(
    'location',
    'Endereço e pino no mapa',
    'Liga a presença pelo celular e o "Chegou bem?" nos cultos.',
    AppIcons.location,
    '/church-info/manage',
    'Marcar o local',
  ),
  cultos(
    'cultos',
    'Horários de culto',
    'Crie o culto na Agenda com repetição semanal. A Home vira "modo culto" na hora.',
    AppIcons.event,
    '/events/new',
    'Criar culto',
  ),
  ministries(
    'ministries',
    'Ministérios',
    'Escolha os ministérios que a igreja já tem. Você entra como líder.',
    AppIcons.groups,
    null,
    'Escolher',
  ),
  pains(
    'pains',
    'O que você quer acompanhar de perto?',
    'Suas prioridades organizam a Dashboard.',
    AppIcons.favorite,
    null,
    'Escolher',
  ),
  leaders(
    'leaders',
    'Convidar a liderança',
    'Abra a ficha de cada líder em Membros e toque em "Enviar acesso".',
    AppIcons.personAdd,
    '/members',
    'Abrir Membros',
  );

  const OnboardingStep(
    this.code,
    this.title,
    this.subtitle,
    this.icon,
    this.route,
    this.ctaLabel,
  );

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Tela existente que resolve a etapa; `null` = a etapa abre uma folha
  /// própria (ministérios, dores).
  final String? route;
  final String ctaLabel;
}

/// Dores do pastor (F2, D13). O preset de widgets de cada uma mora na RPC
/// `onboarding_set_pains`; aqui só o rótulo.
class OnboardingPain {
  const OnboardingPain(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;
}

const kOnboardingPains = <OnboardingPain>[
  OnboardingPain('growth', 'Crescimento da igreja', AppIcons.trendingUp),
  OnboardingPain('visitors', 'Visitantes', AppIcons.personAdd),
  OnboardingPain('attendance', 'Frequência nos cultos', AppIcons.event),
  OnboardingPain('finances', 'Finanças', AppIcons.money),
  OnboardingPain('groups', 'Casas de Vida e grupos', AppIcons.group),
  OnboardingPain('ministries', 'Ministérios e escalas', AppIcons.groups),
  OnboardingPain('absent', 'Pessoas afastadas', Icons.person_off_outlined),
  OnboardingPain('care', 'Aniversários e cuidado pastoral', AppIcons.favorite),
  OnboardingPain('courses', 'Cursos e turmas', AppIcons.course),
  OnboardingPain('communication', 'Comunicação', Icons.campaign_outlined),
];

/// Resposta de `onboarding_status` / `onboarding_set_step` /
/// `onboarding_set_pains`.
class OnboardingStatus {
  const OnboardingStatus({
    required this.steps,
    required this.pains,
    required this.done,
    required this.dismissed,
  });

  final Map<OnboardingStep, bool> steps;
  final List<String> pains;
  final bool done;
  final bool dismissed;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final raw = (json['steps'] as Map?) ?? const {};
    return OnboardingStatus(
      steps: {
        for (final s in OnboardingStep.values) s: raw[s.code] == true,
      },
      pains: [for (final p in (json['pains'] as List?) ?? const []) '$p'],
      done: json['done'] == true,
      dismissed: json['dismissed'] == true,
    );
  }

  bool isDone(OnboardingStep step) => steps[step] ?? false;
  int get doneCount => steps.values.where((v) => v).length;
  int get total => OnboardingStep.values.length;
}
