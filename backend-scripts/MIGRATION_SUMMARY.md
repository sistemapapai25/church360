# 🎉 Migração Concluída: Unificação de Tabelas de Usuário

## 📅 Data: 2025-10-24

---

## 🎯 Objetivo

Unificar as tabelas `user_account`, `member` e `visitor` em uma única tabela `user_account` para simplificar o gerenciamento de usuários, membros e visitantes.

---

## ✅ O QUE FOI FEITO

### **1. Estrutura do Banco de Dados**

#### **ANTES:**
```
┌─────────────────┐
│  user_account   │ (8 campos - apenas autenticação)
└─────────────────┘
         │
         ├─────────────────┐
         │                 │
┌─────────────┐    ┌──────────────┐
│   member    │    │   visitor    │
│ (30 campos) │    │  (42 campos) │
└─────────────┘    └──────────────┘
```

#### **DEPOIS:**
```
┌──────────────────────────────────────┐
│         user_account                 │
│  (ÚNICA TABELA - 60+ campos)         │
│                                      │
│  ✅ Dados de autenticação            │
│  ✅ Dados pessoais completos         │
│  ✅ Endereço                          │
│  ✅ Status e tipo de membro          │
│  ✅ Datas espirituais                │
│  ✅ Jornada do visitante             │
│  ✅ Acompanhamento e discipulado     │
└──────────────────────────────────────┘
```

---

### **2. Campos Adicionados em `user_account`**

#### **Dados Pessoais (de member):**
- `first_name`, `last_name`, `nickname`
- `phone`, `cpf`, `birthdate`
- `gender` (member_gender), `marital_status`, `marriage_date`
- `profession`

#### **Endereço (de member):**
- `address`, `address_complement`, `neighborhood`
- `city`, `state`, `zip_code`

#### **Status e Tipo (de member):**
- `status` (member_status: visitor, new_convert, member_active, etc.)
- `member_type` (titular, congregado, cooperador, crianca)
- `photo_url`

#### **Relacionamentos (de member):**
- `household_id` → household(id)
- `campus_id` → campus(id)
- `created_by` → user_account(id)

#### **Datas Espirituais (de member):**
- `conversion_date`, `baptism_date`, `membership_date`

#### **Jornada do Visitante (de visitor):**
- `first_visit_date`, `last_visit_date`, `total_visits`
- `how_found` (how_found_church), `visitor_source`

#### **Acompanhamento Espiritual (de visitor):**
- `prayer_request`, `interests`
- `is_salvation`, `salvation_date`, `testimony`

#### **Discipulado e Batismo (de visitor):**
- `wants_baptism`, `baptism_event_id`, `baptism_course_id`
- `wants_discipleship`, `discipleship_course_id`

#### **Mentoria e Acompanhamento (de visitor):**
- `assigned_mentor_id` → user_account(id)
- `follow_up_status`, `last_contact_date`
- `wants_contact`, `wants_to_return`

---

### **3. Foreign Keys Atualizadas**

**15 tabelas tiveram `member_id` renomeado para `user_id`:**

1. `bible_bookmark.member_id` → `bible_bookmark.user_id`
2. `church_schedule.responsible_id` → `church_schedule.user_id`
3. `contribution.member_id` → `contribution.user_id`
4. `course_enrollment.member_id` → `course_enrollment.user_id`
5. `donation.member_id` → `donation.user_id`
6. `event_registration.member_id` → `event_registration.user_id`
7. `group.leader_id` → `group.leader_user_id`
8. `group.host_id` → `group.host_user_id`
9. `group_attendance.member_id` → `group_attendance.user_id`
10. `group_member.member_id` → `group_member.user_id`
11. `member_step.member_id` → `member_step.user_id`
12. `member_tag.member_id` → `member_tag.user_id`
13. `ministry_member.member_id` → `ministry_member.user_id`
14. `ministry_schedule.member_id` → `ministry_schedule.user_id`
15. `reading_plan_progress.member_id` → `reading_plan_progress.user_id`
16. `worship_attendance.member_id` → `worship_attendance.user_id`

---

### **4. Tabelas Renomeadas**

- `visitor_followup` → `user_followup`
- `visitor_visit` → `user_visit`

---

### **5. Tabelas Removidas**

- ❌ `member` (migrada para `user_account`)
- ❌ `visitor` (migrada para `user_account`)

---

### **6. Índices Criados**

Para melhorar a performance:
- `idx_user_account_email`
- `idx_user_account_status`
- `idx_user_account_campus_id`
- `idx_user_account_household_id`
- `idx_user_account_created_by`
- `idx_user_account_assigned_mentor_id`

---

### **7. Políticas RLS Atualizadas**

#### **user_account:**

**SELECT:**
- ✅ Todos os usuários autenticados podem ver todos os usuários

**INSERT:**
- ✅ Usuários podem criar sua própria conta (signup)
- ✅ Admins (access_level >= 5) podem criar contas para outros

**UPDATE:**
- ✅ Usuários podem editar seu próprio perfil
- ❌ Usuários NÃO podem alterar campos sensíveis:
  - `status`, `member_type`
  - `membership_date`, `baptism_date`, `conversion_date`
  - `email`
- ✅ Admins podem editar qualquer perfil e alterar campos sensíveis

**DELETE:**
- ✅ Apenas admins podem deletar usuários

#### **user_followup e user_visit:**

**SELECT:**
- ✅ Usuário vê seus próprios registros
- ✅ Líderes (access_level >= 2) veem todos

**ALL (INSERT, UPDATE, DELETE):**
- ✅ Líderes podem gerenciar todos os registros

---

## 🔄 JORNADA DO USUÁRIO

### **1. Criar Conta (App Mobile)**
```
Usuário baixa app → Preenche formulário → 
Cria registro em user_account (status: visitor) → 
Pode fazer login
```

### **2. Novo Visitante (Dashboard - Admin)**
```
Admin clica "Novo Visitante" → Preenche ficha completa → 
Define senha temporária → 
Cria registro em user_account (status: visitor) → 
Visitante pode fazer login no app
```

### **3. Evolução do Visitante**
```
visitor → new_convert → member_active
```

Apenas admins podem alterar o `status` para promover o visitante.

---

## 📋 PRÓXIMOS PASSOS

### **1. Atualizar Código Flutter** ⏳

Substituir todas as referências de `Member` por `UserAccount`:

- ✅ Atualizar model `Member` → `UserAccount`
- ✅ Atualizar `MembersRepository` → `UserAccountRepository`
- ✅ Atualizar providers (`membersProvider` → `userAccountProvider`)
- ✅ Atualizar telas (MembersListScreen, ProfileScreen, etc.)
- ✅ Atualizar formulários (MemberFormScreen → UserAccountFormScreen)

### **2. Testar Funcionalidades** ⏳

- ✅ Signup (criar conta como visitor)
- ✅ Login
- ✅ Ver perfil
- ✅ Editar perfil
- ✅ Admin criar novo visitante
- ✅ Admin promover visitante → membro

---

## 🎯 BENEFÍCIOS DA MIGRAÇÃO

1. ✅ **Simplicidade**: Uma única tabela para todos os usuários
2. ✅ **Sem duplicação**: Dados centralizados
3. ✅ **Fácil evolução**: visitor → member sem migração de dados
4. ✅ **Histórico completo**: Mantém toda a jornada do usuário
5. ✅ **Performance**: Menos JOINs, queries mais rápidas
6. ✅ **Manutenção**: Código mais simples e fácil de entender

---

## 📝 SCRIPTS EXECUTADOS

1. ✅ **Script 20**: Backup e preparação
2. ✅ **Script 21**: Migração principal (estrutura + FKs + remoção)
3. ✅ **Script 22**: Atualização de políticas RLS

---

## 🙏 Que Deus abençoe este projeto!

**Church 360 Gabriel** - Sistema de Gestão Eclesiástica

