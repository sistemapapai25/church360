# Especificação e Inspiração: Módulo Kids

> **Nota:** Este documento contém informações baseadas no funcionamento do sistema "My Kids" para servir de inspiração e referência para a implementação do módulo "Inscrição Kids" no Church360.

## 1. Visão Sistêmica (Inspiração MyKids)

O sistema é focado em check-in/check-out rápido, segurança e comunicação para o ministério infantil.

### Perfis Principais
1.  **Pais / Responsáveis** (App do Usuário Final)
2.  **Equipe do Ministério Infantil** (App/Admin Web)
3.  **Professores / Voluntários**
4.  **Coordenação / Liderança**

### Fluxo Macro
1.  Cadastro da família
2.  Cadastro da criança
3.  Check-in (QR Code + etiqueta)
4.  Acompanhamento em sala
5.  Comunicação / alertas
6.  Check-out seguro
7.  Relatórios e histórico

---

## 2. Funcionalidades Centrais

### 2.1 Cadastro (Autocadastro das famílias)
*   **Processo:** Pais baixam o app, criam conta e cadastram crianças e responsáveis.
*   **Dados:** Informações sensíveis (alergias, restrições, necessidades especiais) e autorização de imagem.
*   **Ponto-chave:** A igreja não digita dados (reduz carga operacional). O cadastro é uma base viva.

### 2.2 Check-in (Entrada da criança)
*   **Processo:** Pai gera QR Code no app -> Voluntário lê -> Sistema registra presença, associa à turma e imprime etiqueta.
*   **QR Code:** É um token temporário, ligado ao evento, invalidado após o check-out.

### 2.3 Acompanhamento durante o culto
*   **Para o professor:** Lista de crianças, alertas visuais (alergias, etc.) e botão de contato rápido (notificação/WhatsApp).
*   **Privacidade:** Professor vê apenas o necessário.

### 2.4 Comunicação em tempo real
*   **Funcionalidades:** Chamado de emergência, avisos gerais, relatório pós-aula (tema, versículo, atividades).
*   **Objetivo:** Engajamento com os pais durante a semana.

### 2.5 Check-out (Saída segura)
*   **Regra:** Criança só sai com autorizado.
*   **Validação:** QR Code de saída, conferência visual + sistema, logs de retirada.

### 2.6 Relatórios e Gestão
*   **Métricas:** Frequência, visitantes recorrentes, necessidades especiais, retenção, ocorrências.

---

## 3. QR Code e Segurança (Modelo Conceitual)

### 3.1 O que o QR Code É
*   Um **token temporário**, curto e seguro (UUID ou JWT assinado).
*   Válido apenas para um momento/evento específico.
*   Associado a um contexto no backend (Criança + Responsável + Evento).

### 3.2 O que o QR Code NÃO É
*   Não contém dados pessoais (Nome, CPF).
*   Não é um ID fixo da criança.
*   Não contém dados sensíveis.

### 3.3 Estrutura Lógica do Token (Backend)
Quando gerado, o token cria um registro temporário no banco:
```json
{
  "token": "9f4c2a1e-7b0f-4c4d-9d6e-8b21a9c8f3a2",
  "child_id": "uuid-da-crianca",
  "responsible_id": "uuid-do-responsavel",
  "event_id": "uuid-do-culto",
  "type": "checkin", // ou "checkout"
  "expires_at": "2025-12-19T10:30:00",
  "used": false
}
```

### 3.4 Fluxo de Validação
1.  **Leitura:** App lê o token e envia para o backend.
2.  **Verificação:** Backend valida existência, expiração e se já foi usado.
3.  **Contexto:** Recupera dados da criança, turma e responsáveis.
4.  **Confirmação:** Marca como usado e registra o check-in/out.

---

## 4. Proposta Técnica para o Church360

Com base na análise da estrutura atual do banco de dados (Tabelas `user_account`, `worship_service`, etc.), propõe-se a seguinte modelagem:

### 4.1 Novas Tabelas (Schema Sugerido)

#### `kids_child` (Perfil da Criança)
Estende `user_account` ou tabela separada vinculada a responsáveis.
*   `id` (UUID)
*   `guardian_id` (FK `user_account`) - Responsável principal
*   `name`, `birthdate`, `gender`
*   `allergies` (Array/Text), `medical_notes` (Text)
*   `photo_url`

#### `kids_guardian` (Responsáveis Autorizados)
Quem pode buscar a criança além do pai/mãe.
*   `child_id` (FK)
*   `user_id` (FK `user_account` - opcional)
*   `name`, `relationship` (Tio, Avó, etc)
*   `is_authorized_checkout` (Bool)

#### `kids_checkin_token` (Tokens Temporários)
A tabela "coração" do sistema de QR Code.
*   `token` (UUID/String - PK)
*   `child_id` (FK)
*   `generated_by` (FK `user_account`)
*   `event_id` (FK `worship_service` ou `event`)
*   `type` ('checkin', 'checkout')
*   `expires_at` (Timestamp)
*   `used_at` (Timestamp - Nullable)

#### `kids_attendance` (Histórico de Presença)
*   `id` (UUID)
*   `child_id` (FK)
*   `event_id` (FK)
*   `class_id` (FK `kids_class` - Turma)
*   `checkin_time`, `checkout_time`
*   `checked_in_by` (FK `user_account` - Voluntário)
*   `checked_out_by` (FK `user_account` - Voluntário)
*   `picked_up_by` (FK `kids_guardian` - Quem levou)

### 4.2 Integração com Tabelas Existentes
*   **Usuários:** Aproveitar `user_account` para os pais e voluntários.
*   **Eventos:** Vincular `kids_attendance` com `worship_service` (Cultos) ou `church_event`.
*   **Permissões:** Criar roles específicas (ex: `kids_volunteer`, `kids_admin`) no sistema de RBAC existente.

---

## 5. Escopo Funcional (Versão Base)

### 5.1 Módulo de Usuários
*   **Tipos:** Pai/Mãe/Responsável, Professor, Voluntário, Coordenador, Administrador.
*   **Funcionalidades:** Login, RBAC, Auditoria.

### 5.2 Módulo de Crianças
*   **Campos:** Nome, Data nascimento, Foto, Alergias, Restrições alimentares, Obs. médicas, Autorização imagem.
*   **Relacionamentos:** Responsáveis, Turmas, Histórico de presenças.

### 5.3 Módulo de Check-in / Check-out
*   **Check-in:** QR Code dinâmico, Associação a evento, Impressão etiqueta (opcional), Validação dados.
*   **Check-out:** Validação responsável, Token saída, Auditoria.

### 5.4 Módulo de Turmas e Salas
*   Definição por idade, Capacidade máxima, Professores responsáveis, Lista dinâmica.

### 5.5 Módulo de Comunicação
*   Push notifications, Integração WhatsApp, Mensagens automáticas, Relatórios de aula.

### 5.6 Módulo de Relatórios
*   Frequência, Visitantes, Necessidades especiais, Histórico, Exportação.

### 5.7 Módulo de Segurança e LGPD
*   Consentimento imagem, Logs acesso, Controle por cargo, Criptografia dados sensíveis.

---

## 6. Oportunidades de Diferenciação (Estratégico)

*   Integração direta com AppSheet / Supabase / Firebase
*   Módulo de discipulado infantil
*   Pontuação por frequência
*   Integração com agenda da igreja
*   Modo offline para check-in
*   White-label para múltiplas igrejas
*   IA para identificar ausência prolongada
*   Relatórios pastorais (não só administrativos)
