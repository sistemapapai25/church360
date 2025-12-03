# 📱 Church 360 Gabriel - Resumo do Projeto

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Tecnologias Utilizadas](#tecnologias-utilizadas)
3. [Funcionalidades Implementadas](#funcionalidades-implementadas)
4. [Estrutura do Projeto](#estrutura-do-projeto)
5. [Banco de Dados (Supabase)](#banco-de-dados-supabase)
6. [Próximos Passos - OPÇÃO 3](#próximos-passos---opção-3)
7. [Detalhamento da Implementação](#detalhamento-da-implementação)

---

## 🎯 Visão Geral

**Church 360 Gabriel** é um sistema completo de gerenciamento de igreja desenvolvido em Flutter com backend Supabase.

**Desenvolvedor:** Alcides (alcidescostant@hotmail.com)  
**Repositório:** C:/Users/Alcides/Desktop/Church 360 Gabriel  
**Projeto Supabase:** Church 360 (ID: heswheljavpcyspuicsi, Region: sa-east-1)

---

## 🛠️ Tecnologias Utilizadas

### **Frontend**
- **Flutter** (Dart)
- **Riverpod** - State Management
- **go_router** - Navegação
- **qr_flutter** - Geração de QR Codes
- **mobile_scanner** - Leitura de QR Codes
- **intl** - Formatação de datas
- **uuid** - Geração de IDs únicos

### **Backend**
- **Supabase** (PostgreSQL)
  - Authentication
  - Database
  - Storage
  - Row Level Security (RLS)

---

## ✅ Funcionalidades Implementadas

### **1. Sistema de Autenticação**
- ✅ Login com email/senha
- ✅ Registro de novos usuários
- ✅ Recuperação de senha
- ✅ Logout
- ✅ Provider: `currentUserProvider`

### **2. Dashboard Administrativo**
- ✅ Menu lateral (Drawer)
- ✅ Tela principal com cards de acesso rápido
- ✅ Navegação para módulos

### **3. Gestão de Membros**
- ✅ Listagem de membros
- ✅ Filtros e busca
- ✅ Perfil detalhado do membro
  - Informações pessoais
  - Endereço com link para Google Maps
  - Indicador de completude do cadastro
  - Seção de liderança (para líderes)
  - **QR Code único para cada membro**
- ✅ Provider: `currentMemberProvider` (busca membro por email do usuário)

### **4. Gestão de Visitantes**
- ✅ Tela idêntica à de membros
- ✅ Filtra apenas visitantes (status='visitor')
- ✅ Transição automática para membro

### **5. Sistema de Eventos**
- ✅ Listagem de eventos
- ✅ Detalhes do evento
- ✅ Criação/edição de eventos
- ✅ **Sistema de Inscrições:**
  - Tela pública de inscrição
  - Suporte a eventos gratuitos e pagos
  - Geração de ingresso com QR Code único
  - Tela de inscritos
  - Check-in manual
- ✅ **QR Code para Eventos:**
  - Formato: `EVENT_TICKET:eventId:memberId:ticketId`
  - Validação de ingresso
  - Check-in automático via scanner

### **6. Sistema de QR Code**
- ✅ **Scanner de QR Code:**
  - Acesso via Dashboard → Menu → "Leitor de QR Code"
  - Câmera em tempo real
  - Detecção de 2 tipos de QR Code:
    1. **Membro:** Apenas o ID do membro
    2. **Evento:** `EVENT_TICKET:eventId:memberId:ticketId`
  - Flash e troca de câmera
- ✅ **Geração de QR Code:**
  - QR Code único para cada membro (no perfil)
  - QR Code único para cada ingresso de evento

---

## 📁 Estrutura do Projeto

```
app/
├── lib/
│   ├── core/
│   │   ├── navigation/
│   │   │   └── app_router.dart          # Rotas do app
│   │   └── theme/
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       └── providers/
│   │   │           └── auth_provider.dart  # currentUserProvider
│   │   ├── members/
│   │   │   ├── data/
│   │   │   │   └── members_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── models/
│   │   │   │       └── member.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── members_provider.dart  # currentMemberProvider
│   │   │       └── screens/
│   │   │           ├── members_screen.dart
│   │   │           ├── visitors_screen.dart
│   │   │           └── member_profile_screen.dart
│   │   ├── events/
│   │   │   ├── data/
│   │   │   │   └── events_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── models/
│   │   │   │       └── event.dart  # Event, EventRegistration, EventTicket
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── events_provider.dart
│   │   │       └── screens/
│   │   │           ├── events_screen.dart
│   │   │           ├── event_detail_screen.dart
│   │   │           ├── event_registration_screen.dart  # Inscrição pública
│   │   │           └── event_registrations_screen.dart  # Lista de inscritos
│   │   ├── qr_scanner/
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           └── qr_scanner_screen.dart
│   │   └── dashboard/
│   │       └── presentation/
│   │           └── screens/
│   │               └── dashboard_screen.dart
│   └── main.dart
```

---

## 🗄️ Banco de Dados (Supabase)

### **Tabelas Principais**

#### **1. user_account**
- `id` (UUID, PK)
- `email` (TEXT, UNIQUE)
- `created_at` (TIMESTAMP)

#### **2. member**
- `id` (UUID, PK)
- `name` (TEXT)
- `email` (TEXT, UNIQUE)
- `phone` (TEXT)
- `birth_date` (DATE)
- `status` (TEXT) - 'active', 'inactive', 'visitor'
- `address` (TEXT)
- `city` (TEXT)
- `state` (TEXT)
- `zip_code` (TEXT)
- `photo_url` (TEXT)
- `is_leader` (BOOLEAN)
- `leadership_role` (TEXT)
- `created_at` (TIMESTAMP)

#### **3. event**
- `id` (UUID, PK)
- `name` (TEXT)
- `description` (TEXT)
- `start_date` (TIMESTAMP)
- `end_date` (TIMESTAMP)
- `location` (TEXT)
- `image_url` (TEXT)
- `status` (TEXT) - 'draft', 'published', 'cancelled', 'completed'
- `requires_registration` (BOOLEAN)
- `price` (NUMERIC)
- `is_free` (BOOLEAN)
- `max_capacity` (INTEGER)
- `registration_count` (INTEGER)
- `created_at` (TIMESTAMP)

#### **4. event_registration**
- `id` (UUID, PK)
- `event_id` (UUID, FK → event.id)
- `member_id` (UUID, FK → member.id) ⚠️ **IMPORTANTE: FK aponta para member, não user_account**
- `registered_at` (TIMESTAMP)
- `checked_in_at` (TIMESTAMP, nullable)
- `ticket_id` (TEXT, nullable)

**⚠️ ATENÇÃO:** A constraint `event_registration_member_id_fkey` valida contra a tabela `member`, não `user_account`. Sempre usar `member.id` ao criar registros.

---

## 🚀 Próximos Passos - OPÇÃO 3

### **Implementação: Menu Lateral com Categorias Expansíveis**

#### **Estrutura Proposta:**

```
Dashboard (Menu Lateral)
├── 👥 PESSOAS
│   ├── Membros
│   └── Visitantes
├── 📅 EVENTOS
│   └── Gerenciar Eventos
├── 📱 CONTEÚDO DO APP
│   ├── Home
│   │   ├── Banners
│   │   ├── Testemunhos
│   │   ├── Pedidos de Oração
│   │   ├── Para sua Edificação
│   │   └── Fique por dentro
│   ├── Palavras (Mensagens/Sermões)
│   └── Contribua (Dados Bancários)
├── 📚 MÓDULOS
│   ├── Cursos
│   ├── A Igreja
│   ├── Agenda
│   ├── Kid
│   ├── Notícias
│   └── Planos de Leitura
└── ⚙️ CONFIGURAÇÕES
```

---

## 📝 Detalhamento da Implementação

### **FASE 1: Reestruturar Menu Lateral do Dashboard**

#### **Passo 1.1: Criar Widget de Menu Expansível**
- Criar `ExpansionTile` customizado
- Suportar categorias e sub-itens
- Animações de expansão/colapso
- Ícones e cores personalizadas

#### **Passo 1.2: Atualizar dashboard_screen.dart**
- Substituir menu atual por menu com categorias
- Implementar categorias:
  - 👥 PESSOAS
  - 📅 EVENTOS
  - 📱 CONTEÚDO DO APP
  - 📚 MÓDULOS
  - ⚙️ CONFIGURAÇÕES

### **FASE 2: Implementar Módulos de Conteúdo do App**

#### **Módulo: Home - Banners**
- Tela de listagem de banners
- CRUD de banners (criar, editar, excluir)
- Upload de imagens
- Ordenação (arrastar e soltar)
- Ativar/desativar banner
- **Tabela:** `home_banner`

#### **Módulo: Home - Testemunhos**
- Listagem de testemunhos
- CRUD de testemunhos
- Aprovação/rejeição
- **Tabela:** `testimony`

#### **Módulo: Home - Pedidos de Oração**
- Listagem de pedidos
- CRUD de pedidos
- Status (pendente, em oração, respondido)
- **Tabela:** `prayer_request`

#### **Módulo: Home - Para sua Edificação**
- Cards de conteúdo edificante
- CRUD de cards
- **Tabela:** `edification_card`

#### **Módulo: Home - Fique por Dentro**
- Avisos e notícias rápidas
- CRUD de avisos
- **Tabela:** `quick_news`

#### **Módulo: Palavras (Mensagens/Sermões)**
- Listagem de mensagens
- CRUD de mensagens
- Upload de áudio/vídeo
- Categorias (domingo, quarta, especial)
- **Tabela:** `message`

#### **Módulo: Contribua**
- Cadastro de dados bancários da igreja
- PIX, conta bancária, etc.
- **Tabela:** `church_bank_info`

### **FASE 3: Implementar Módulos do Menu "Mais"**

#### **Módulo: Cursos**
- Listagem de cursos
- CRUD de cursos
- Inscrições
- **Tabela:** `course`

#### **Módulo: A Igreja**
- Informações sobre a igreja
- História, missão, visão, valores
- Equipe pastoral
- **Tabela:** `church_info`

#### **Módulo: Agenda**
- Calendário de atividades
- CRUD de atividades
- **Tabela:** `schedule`

#### **Módulo: Kid**
- Conteúdo infantil
- Atividades, histórias, etc.
- **Tabela:** `kids_content`

#### **Módulo: Notícias**
- Blog/notícias da igreja
- CRUD de notícias
- **Tabela:** `news`

#### **Módulo: Planos de Leitura**
- Planos de leitura bíblica
- CRUD de planos
- Acompanhamento de progresso
- **Tabela:** `reading_plan`

---

## 🎯 Ordem de Implementação Sugerida

1. ✅ **Reestruturar Menu Lateral** (FASE 1)
2. ✅ **Banners da Home** (mais simples, bom para começar)
3. ✅ **Palavras/Mensagens** (importante para o app)
4. ✅ **Testemunhos e Pedidos de Oração**
5. ✅ **Contribua** (simples, apenas dados bancários)
6. ✅ **Cards da Home** (Para sua Edificação, Fique por Dentro)
7. ✅ **Módulos do Menu Mais** (um por vez)

---

## 📌 Informações Importantes

### **Providers Existentes:**
- `currentUserProvider` - Retorna o usuário autenticado (user_account)
- `currentMemberProvider` - Retorna o membro baseado no email do usuário (member)
- `eventByIdProvider(eventId)` - Retorna evento por ID
- `eventRegistrationsProvider(eventId)` - Retorna inscrições de um evento

### **Navegação:**
- Usar `context.push('/rota')` para navegar
- Rotas definidas em `app_router.dart`

### **Boas Práticas:**
- Sempre usar `currentMemberProvider` quando precisar do ID do membro
- Nunca usar `user.id` para FK de `member_id`
- Usar Riverpod para state management
- Seguir arquitetura em camadas (data/domain/presentation)

---

## 🔧 Comandos Úteis

```bash
# Rodar o app
flutter run -d emulator-5554

# Instalar dependências
flutter pub get

# Limpar build
flutter clean

# Ver dispositivos
flutter devices
```

---

## 📞 Contato

**Desenvolvedor:** Alcides  
**Email:** alcidescostant@hotmail.com  
**GitHub:** RGAGroup

---

**Última Atualização:** 2025-10-21  
**Status:** Pronto para implementar OPÇÃO 3 - Menu Lateral com Categorias Expansíveis

