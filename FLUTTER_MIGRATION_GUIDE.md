# 📱 Guia de Migração - Flutter App

## 🎯 Objetivo

Atualizar o código Flutter para usar a tabela unificada `user_account` em vez de `member` e `visitor`.

---

## ✅ MUDANÇAS JÁ REALIZADAS

### **1. Model `Member` Atualizado** ✅

**Arquivo**: `app/lib/features/members/domain/models/member.dart`

#### **Novos Campos Adicionados:**
- ✅ Campos de autenticação: `email` (required), `fullName`, `avatarUrl`, `isActive`
- ✅ Campos de visitante: `firstVisitDate`, `totalVisits`, `howFound`, etc.
- ✅ Campos de acompanhamento: `assignedMentorId`, `followUpStatus`, `lastContactDate`
- ✅ Campos de discipulado: `wantsBaptism`, `wantsDiscipleship`, etc.

#### **Novos Getters:**
```dart
String get displayName        // Nome para exibição (nunca nulo)
String get initials           // Iniciais para avatar
String get computedFullName   // Nome completo computado
bool get isMemberActive       // Verifica se status == 'member_active'
```

#### **Mudanças Importantes:**
- ⚠️ `firstName` e `lastName` agora são **nullable** (`String?`)
- ⚠️ `email` agora é **required** e **não-nulo** (`String`)
- ⚠️ `fullName` é um campo separado (pode ser diferente de firstName + lastName)

---

### **2. Repository Atualizado** ✅

**Arquivo**: `app/lib/features/members/data/members_repository.dart`

- ✅ Todas as queries agora usam `user_account` em vez de `member`
- ✅ Métodos mantidos sem alteração de assinatura

---

## 🔧 MUDANÇAS NECESSÁRIAS NO CÓDIGO

### **1. Substituir `member.fullName` por `member.displayName`**

**Arquivos afetados:**
- `app/lib/features/church_schedule/presentation/screens/church_schedule_form_screen.dart` (linha 245)
- `app/lib/features/events/presentation/screens/event_detail_screen.dart` (linha 708)
- `app/lib/features/groups/presentation/screens/group_detail_screen.dart` (linha 619)
- `app/lib/features/members/presentation/screens/member_detail_screen.dart` (linha 176)
- `app/lib/features/members/presentation/screens/member_profile_screen.dart` (linha 183)
- `app/lib/features/members/presentation/screens/members_list_screen.dart` (linhas 133, 288, 520)
- `app/lib/features/qr_scanner/presentation/screens/qr_scanner_screen.dart` (linhas 338, 551)
- `app/lib/features/visitors/presentation/screens/visitor_form_screen.dart` (linha 540)
- `app/lib/features/visitors/presentation/screens/visitors_list_screen.dart` (linhas 99, 238, 443)
- `app/lib/features/financial/presentation/screens/contribution_form_screen.dart` (linha 198)
- `app/lib/features/groups/presentation/screens/group_form_screen.dart` (linhas 283, 316)

**Mudança:**
```dart
// ANTES
Text(member.fullName)

// DEPOIS
Text(member.displayName)
```

---

### **2. Substituir `member.firstName[0]` por `member.initials`**

**Arquivos afetados:**
- `app/lib/features/members/presentation/screens/member_detail_screen.dart` (linha 164)
- `app/lib/features/members/presentation/screens/member_profile_screen.dart` (linha 167)
- `app/lib/features/members/presentation/screens/members_list_screen.dart` (linhas 272, 508)
- `app/lib/features/permissions/presentation/screens/assign_role_screen.dart` (linha 585)
- `app/lib/features/qr_scanner/presentation/screens/qr_scanner_screen.dart` (linhas 326, 536)
- `app/lib/features/visitors/presentation/screens/visitors_list_screen.dart` (linhas 222, 431)
- `app/lib/features/worship/presentation/screens/worship_attendance_screen.dart` (linha 301)

**Mudança:**
```dart
// ANTES
Text(member.firstName[0].toUpperCase())

// DEPOIS
Text(member.initials)
```

---

### **3. Atualizar Formulários para Lidar com Campos Nullable**

**Arquivos afetados:**
- `app/lib/features/members/presentation/screens/member_form_screen.dart`
- `app/lib/features/members/presentation/screens/edit_profile_screen.dart`

**Mudanças:**

#### **Inicialização dos Controllers:**
```dart
// ANTES
_firstNameController.text = member.firstName;
_lastNameController.text = member.lastName;
_emailController.text = member.email ?? '';

// DEPOIS
_firstNameController.text = member.firstName ?? '';
_lastNameController.text = member.lastName ?? '';
_emailController.text = member.email; // email é required
```

#### **Criação do Member:**
```dart
// ANTES
Member(
  firstName: _firstNameController.text.trim(),
  lastName: _lastNameController.text.trim(),
  email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
)

// DEPOIS
Member(
  email: _emailController.text.trim(), // required
  firstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
  lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
)
```

---

### **4. Atualizar Filtros e Pesquisas**

**Arquivos afetados:**
- `app/lib/features/worship/presentation/screens/worship_attendance_screen.dart` (linhas 155-156, 172)

**Mudanças:**
```dart
// ANTES
member.firstName.toLowerCase().contains(_searchQuery)

// DEPOIS
(member.firstName?.toLowerCase() ?? '').contains(_searchQuery)

// OU usar displayName
member.displayName.toLowerCase().contains(_searchQuery)
```

---

### **5. Atualizar Signup para Criar Registro Completo**

**Arquivo**: `app/lib/features/auth/data/auth_repository.dart`

**Mudança Necessária:**

Atualmente, o signup cria apenas um registro básico em `user_account`. Agora precisa incluir mais campos:

```dart
// Criar registro em user_account
await _supabase.from('user_account').insert({
  'id': user.id,
  'email': email,
  'full_name': fullName,
  'is_active': true,
  'status': 'visitor', // Novo usuário começa como visitante
  'created_at': DateTime.now().toIso8601String(),
});
```

---

## 📋 CHECKLIST DE MIGRAÇÃO

### **Fase 1: Correções de Compilação** ⏳
- [ ] Substituir `member.fullName` por `member.displayName` (12 arquivos)
- [ ] Substituir `member.firstName[0]` por `member.initials` (8 arquivos)
- [ ] Atualizar `member_form_screen.dart` para campos nullable
- [ ] Atualizar `edit_profile_screen.dart` para campos nullable
- [ ] Atualizar filtros em `worship_attendance_screen.dart`

### **Fase 2: Funcionalidades** ⏳
- [ ] Atualizar signup em `auth_repository.dart`
- [ ] Testar criação de conta (app mobile)
- [ ] Testar criação de visitante (dashboard)
- [ ] Testar edição de perfil
- [ ] Testar listagem de membros
- [ ] Testar listagem de visitantes

### **Fase 3: Testes Completos** ⏳
- [ ] Signup funciona
- [ ] Login funciona
- [ ] Perfil é exibido corretamente
- [ ] Edição de perfil funciona
- [ ] Listagem de membros funciona
- [ ] Listagem de visitantes funciona
- [ ] Filtros funcionam
- [ ] Pesquisa funciona

---

## 🚀 PRÓXIMOS PASSOS

1. **Executar correções automáticas** (substituir fullName → displayName)
2. **Testar compilação** do app
3. **Executar app** e testar funcionalidades
4. **Corrigir erros** encontrados
5. **Testar signup** e criação de visitantes

---

## 📝 NOTAS IMPORTANTES

### **Compatibilidade com Dados Antigos:**
- ✅ O model `Member.fromJson()` já trata campos nullable
- ✅ Se `fullName` for nulo, `displayName` usa `computedFullName`
- ✅ Se `firstName` for nulo, `initials` usa `fullName` ou `email`

### **Campos Protegidos (RLS):**
Usuários comuns **NÃO podem alterar**:
- `status`
- `member_type`
- `membership_date`
- `baptism_date`
- `conversion_date`
- `email`

Apenas **admins** (access_level >= 5) podem alterar esses campos.

---

## 🙏 Que Deus abençoe este projeto!

**Church 360 Gabriel** - Sistema de Gestão Eclesiástica

