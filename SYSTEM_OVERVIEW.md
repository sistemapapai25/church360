# Church360 — Visão Geral do Sistema

Este documento descreve a arquitetura, os principais fluxos e componentes do Church360 para que outro agente possa entender e operar o sistema de ponta a ponta.

## Stack e Organização
- Framework: Flutter (Web), gerenciamento de estado com Riverpod.
- Backend: Supabase (REST/Postgrest) para dados e autenticação.
- Estrutura: `app/lib/features/<domínio>` para módulos funcionais; `core` para navegação e utilitários.
- Navegação: `app/lib/core/navigation/app_router.dart` carrega telas, incluindo o gerador de escala.

## Navegação
- Importação da tela do gerador: `app/lib/core/navigation/app_router.dart:53`.
- Telas relevantes de escala:
  - Gerador: `app/lib/features/schedule/presentation/screens/auto_schedule_generator_screen.dart`.
  - Pré‑visualização/edição: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart`.
  - Regras: `app/lib/features/schedule/presentation/screens/schedule_rules_preferences_screen.dart`.

## Providers e Repositórios
- Schedules: `app/lib/features/schedule/presentation/providers/schedule_provider.dart`.
  - `scheduleRepositoryProvider` fornece acesso a eventos e escalas.
  - `eventsOfMonthProvider`, `eventsOfDateProvider` para consultas de eventos.
- Ministries (membros, funções, escalas por ministério): `ministriesRepositoryProvider` (usado em várias telas e serviços).
- Events: `eventsRepositoryProvider` (usado em regras para catálogo de tipos).
- Role Contexts: `roleContextsRepositoryProvider` expõe `contexts` com metadados de regras e categorias por ministério.

## Modelos Principais
- `Event`: domínio de eventos com `eventType`, `startDate` etc.
- `Ministry`: domínio do ministério com líder, membros e metadados.

## Fluxos de Escala

### 1) Geração de Escala (Persistente)
- Tela: `auto_schedule_generator_screen.dart` dispara geração para o período selecionado.
- Seletor de período otimizado via `showDateRangePicker`: `app/lib/features/schedule/presentation/screens/auto_schedule_generator_screen.dart:62-83`.
- Botão `GERAR ESCALA` chama `AutoSchedulerService.generateForEvent` por evento:
  - Código: `app/lib/features/schedule/presentation/screens/auto_schedule_generator_screen.dart:85-117`.
  - Para eventos normais, usa `byFunction: true` e `overwriteExisting: true`.

- Serviço: `app/lib/features/schedule/domain/auto_scheduler_service.dart`.
  - Método: `generateForEvent(...)` (persistente).
  - Carrega regras e metadados dos contexts: categorias, exclusividades, líderes e suplentes, prioridades, combinações proibidas/preferidas.
  - Normalização de nomes de função (`norm`) para mapear `function_id` de catálogo.
  - Seleção por função com regras:
    - Construção de candidatos: atribuídos + líder + suplentes.
    - Validações: bloqueios, `max_per_month`, `min_days_between`, `max_consecutive`, exclusividades por categoria, combinações proibidas.
    - Reserva de combinações preferidas para outras funções.
    - Fallback explícito de suplentes se faltar gente:
      - Persistente: `app/lib/features/schedule/domain/auto_scheduler_service.dart:566-603`.
  - Remoção de bloqueio global por evento na geração por função (depende apenas das regras de categoria): `app/lib/features/schedule/domain/auto_scheduler_service.dart:533` (não adiciona global ao persistir função).

### 2) Geração de Proposta (Prévia, sem persistir)
- Tela: `scale_preview_screen.dart`.
  - Constrói lista de funções e candidatos a partir de contexts e vínculos.
  - União de fontes de candidatos para cada função: líderes/subs, `assigned_functions`, vínculos `member_function`.
    - `_allowedForEventFunction`: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:533-536`.
  - Preenchimento inicial por proposta: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:283-321`.
  - Auto‑completar desativado e foco no ajuste manual e salvar: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:503-507`.

- Serviço: `app/lib/features/schedule/domain/auto_scheduler_service.dart`.
  - Método: `generateProposalForEvent(...)` (não persiste, retorna `proposals`).
  - Valida e reserva preferências com normalização de nomes: `app/lib/features/schedule/domain/auto_scheduler_service.dart:1080-1099`.
  - Fallbacks de suplentes na prévia: `app/lib/features/schedule/domain/auto_scheduler_service.dart:1104-1139` e `1142-1175`.

### 3) Salvar a Prévia
- Após ajustes manuais, o botão “Salvar Escala” persiste localmente:
  - Deduplicação e mapeamento de `function_id` por catálogo para evitar a constraint de unicidade (`uq_ministry_schedule_event_ministry_user_function_null`).
  - Código: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:439-487`.
  - Invalida caches dos providers para refletir imediatamente a escala salva.

## Regras de Escala
- Editáveis na tela de preferências: `app/lib/features/schedule/presentation/screens/schedule_rules_preferences_screen.dart`.
- Metadados dos contexts incluem:
  - `function_category_by_function` → mapeia função para categoria (`instrument`, `voice_role`, `other`).
  - `category_restrictions` → exclusividade e “alone” por categoria.
  - `assigned_functions` → associação de membros às funções.
  - `leaders_by_function` → líder e lista de suplentes por função.
  - `schedule_rules` → `general_rules` (ex.: `max_per_month`, `min_days_between`, `max_consecutive`, `allow_multi_ministries_per_event`), `prohibited_combinations` e `preferred_combinations`.
- Normalização de nomes para consistência de funções: `norm` em:
  - Persistente: `app/lib/features/schedule/domain/auto_scheduler_service.dart:112-139`.
  - Prévia: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:67-93`.

## Políticas de Seleção
- Preferências: ao alocar um membro em uma função, reserva o parceiro preferido para a função correspondente.
- Proibições: evita que pares proibidos entrem em funções simultâneas quando `a_func`/`b_func` se aplicam à função atual (comparação normalizada).
- Exclusividades de categoria:
  - `exclusiveWithinCats`: impede o mesmo usuário de acumular funções da mesma categoria.
  - `exclusiveAloneCats`: impede acumular com outras categorias.
  - Regras específicas por `instrument`, `voice_role`, `other` são aplicadas.

## Considerações de Persistência
- Deduplicação ao salvar evita violar a constraint de unicidade quando `function_id` não é usado.
- Sempre que possível, `function_id` é incluído com base no catálogo de funções.
- Invalidação de providers (`eventSchedulesProvider`, `ministrySchedulesProvider`) após salvar para atualizar a UI.

## Fluxo Operacional (Resumo)
1. Selecionar período na tela do gerador (intervalo) e listar eventos.
2. Gerar a escala para cada evento:
   - Evento normal → por função; eventos de reunião/mutirão/liderança → regras específicas.
3. Pré‑visualizar/editar a escala:
   - Ajustar manualmente por função; candidatos incluem líderes, suplentes e vínculos.
4. Salvar a prévia:
   - Persistência deduplicada com `function_id` quando disponível.
5. Regras e preferências podem ser ajustadas na tela dedicada; refletem nos contexts do ministério.

## Observações de Segurança e Permissões
- Providers de permissões (`permissions_providers.dart`) garantem acesso às telas e ações conforme perfil.
- Logs em runtime exibem usuário atual e permissões (visíveis durante `flutter run`).

## Pontos de Entrada para Extensão
- Novas regras: expandir `schedule_rules` nos contexts; serviço já lê e aplica.
- Novas categorias: atualizar `function_category_by_function` e `category_order` nos contexts.
- Candidatos adicionais: incluir vínculos em `member_function` para aparecerem na prévia.

---
Este overview cobre os principais pontos de arquitetura, regras e fluxos de geração/edição/salvar de escalas, com referências diretas a arquivos e linhas para navegação rápida.
