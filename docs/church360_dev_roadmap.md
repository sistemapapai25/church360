# 🏗️ Church 360 - Guia de Desenvolvimento Completo

> **Documento Vivo:** Atualize este arquivo conforme avança no projeto. Use-o como referência para manter contexto entre sessões.

---

## 📊 ESTADO ATUAL DO PROJETO

```
🔄 FASE ATUAL: Fase 0 - Setup Inicial (Em Progresso)
📍 ÚLTIMO PASSO CONCLUÍDO: F0.P6 - Estrutura de pastas criada
📅 ÚLTIMA ATUALIZAÇÃO: 13/10/2025
🎯 PROGRESSO GERAL: 8% (1/11 fases completas - Doações e Offline-First adiados)
```

### ⚡ Próxima Ação
- [x] **Fase 0 COMPLETA** ✅
- [ ] Iniciar **Fase 1** - Backend Foundation

---

## 📑 ÍNDICE DE NAVEGAÇÃO

### 🏗️ FUNDAÇÃO (Semanas 1-3)
- [Fase 0: Setup Inicial](#fase-0-setup-inicial) - 1-2 dias
- [Fase 1: Backend Foundation](#fase-1-backend-foundation) - 2-3 dias
- [Fase 2: Flutter Foundation](#fase-2-flutter-foundation) - 2-3 dias
- [Fase 3: Autenticação Multi-DB](#fase-3-autenticação-multi-db) - 3-4 dias

### 🎯 MVP CORE (Semanas 4-8)
- [Fase 4: Módulo Membros](#fase-4-módulo-membros) - 5-7 dias
- [Fase 5: Módulo Grupos](#fase-5-módulo-grupos) - 4-5 dias
- [Fase 6: Módulo Eventos](#fase-6-módulo-eventos) - 5-6 dias
- [Fase 7: Módulo Doações](#fase-7-módulo-doações) - 5-6 dias
- [Fase 8: Módulo Agenda](#fase-8-módulo-agenda) - 3-4 dias

### 🔗 INTEGRAÇÃO (Semanas 9-10)
- [Fase 9: Comunicações](#fase-9-comunicações) - 3-4 dias
- [Fase 10: Relatórios MVP](#fase-10-relatórios-mvp) - 2-3 dias
- [Fase 11: Offline-First](#fase-11-offline-first) - 4-5 dias

### 🚀 FINALIZAÇÃO (Semanas 11-12)
- [Fase 12: Testes & Qualidade](#fase-12-testes--qualidade) - 3-4 dias
- [Fase 13: Deploy & Publicação](#fase-13-deploy--publicação) - 2-3 dias

---

# 🏗️ FUNDAÇÃO

---

## Fase 0: Setup Inicial

**Status:** ✅ COMPLETO
**Tempo Estimado:** 1-2 dias
**Dependências:** Nenhuma
**Sistema:** Windows

### 🎯 Objetivo da Fase
Preparar ambiente de desenvolvimento com todas as ferramentas necessárias para construir o Church 360.

### 📦 Entregáveis
- [x] Flutter SDK instalado e funcional ✅
- [x] Android Studio configurado com emulador ✅
- [x] VS Code com extensões Flutter ✅
- [x] Git configurado ✅
- [x] Supabase CLI instalado ✅
- [x] Node.js instalado (para Supabase) ✅
- [x] Estrutura de pastas do projeto criada ✅

### 📝 Passos

#### F0.P1: Instalar Flutter SDK
**O QUE:**  
Baixar e configurar Flutter para desenvolvimento Windows.

**POR QUÊ:**  
Flutter é o framework base para criar o app iOS e Android a partir de um único código.

**VALIDAÇÃO:**  
Executar `flutter doctor` no terminal e verificar se há checkmarks verdes. Alguns warnings sobre Xcode (macOS) são normais no Windows.

**PRÓXIMO:** F0.P2

---

#### F0.P2: Instalar Android Studio
**O QUE:**  
Baixar Android Studio com SDK Android e criar um emulador virtual.

**POR QUÊ:**  
Necessário para compilar o app Android e testar sem dispositivo físico.

**VALIDAÇÃO:**  
Abrir Android Studio → Tools → AVD Manager → Criar emulador (Pixel 7 com API 34 recomendado) → Iniciar emulador e ver a tela inicial do Android.

**PRÓXIMO:** F0.P3

---

#### F0.P3: Instalar VS Code com Extensões
**O QUE:**  
Instalar Visual Studio Code e adicionar extensões Flutter, Dart e Git.

**POR QUÊ:**  
VS Code é o editor recomendado para Flutter, mais leve que Android Studio para codificação.

**EXTENSÕES NECESSÁRIAS:**
- Flutter (Dart Code)
- Dart
- GitLens
- Error Lens
- Material Icon Theme

**VALIDAÇÃO:**  
Abrir VS Code → Extensions → Verificar se "Flutter" e "Dart" estão instalados → Abrir Command Palette (Ctrl+Shift+P) → Digitar "Flutter: New Project" → Deve aparecer a opção.

**PRÓXIMO:** F0.P4

---

#### F0.P4: Instalar Node.js e Supabase CLI
**O QUE:**  
Instalar Node.js (LTS) e depois o Supabase CLI via npm.

**POR QUÊ:**  
Supabase CLI permite gerenciar banco de dados, executar migrations e testar Edge Functions localmente.

**VALIDAÇÃO:**  
No terminal:
1. `node --version` (deve mostrar v20.x ou superior)
2. `npm --version` (deve mostrar versão)
3. `npx supabase --version` (deve mostrar versão do Supabase CLI)

**PRÓXIMO:** F0.P5

---

#### F0.P5: Configurar Git e GitHub
**O QUE:**  
Instalar Git, configurar usuário/email e criar repositório GitHub para o projeto.

**POR QUÊ:**  
Controle de versão essencial para não perder código e permitir colaboração futura.

**VALIDAÇÃO:**
1. `git --version` (deve mostrar versão)
2. Criar repositório no GitHub chamado `church360-app`
3. Clonar localmente: `git clone <url-do-repo>`
4. Criar arquivo `.gitignore` para Flutter

**PRÓXIMO:** F0.P6

---

#### F0.P6: Criar Estrutura de Pastas
**O QUE:**  
Organizar workspace com pastas separadas para app, backend scripts e documentação.

**ESTRUTURA:**
```
church360/
├── app/                    # Projeto Flutter
├── backend-scripts/        # SQL templates, scripts
├── docs/                   # Documentação
│   ├── arquitetura.md
│   └── este-guia.md
└── README.md
```

**POR QUÊ:**  
Separar claramente código do app, scripts de backend e documentação facilita organização.

**VALIDAÇÃO:**  
Estrutura de pastas criada e commitada no Git.

**PRÓXIMO:** Fase 1

---

### ✅ Checklist de Conclusão - Fase 0
Marque cada item quando concluído:
- [x] F0.P1 - Flutter SDK instalado ✅
- [x] F0.P2 - Android Studio + Emulador ✅
- [x] F0.P3 - VS Code configurado ✅
- [x] F0.P4 - Node.js + Supabase CLI ✅
- [x] F0.P5 - Git configurado ✅
- [x] F0.P6 - Estrutura de pastas criada ✅

**✅ FASE 0 COMPLETA!** Atualizado em 13/10/2025.

---

## Fase 1: Backend Foundation

**Status:** 🔴 TODO  
**Tempo Estimado:** 2-3 dias  
**Dependências:** ✅ Fase 0 completa  

### 🎯 Objetivo da Fase
Criar e configurar o backend Supabase com banco de dados PostgreSQL, incluindo schema completo, RLS e dados seed.

### 📦 Entregáveis
- [ ] Projeto Supabase criado (gratuito)
- [ ] Schema SQL completo executado
- [ ] RLS (Row Level Security) configurado
- [ ] Dados seed carregados (fundos, tags, steps)
- [ ] Primeiro usuário owner criado
- [ ] Conexão testada via Supabase Studio

### 📝 Passos

#### F1.P1: Criar Conta e Projeto Supabase
**O QUE:**  
Acessar supabase.com, criar conta gratuita e iniciar novo projeto.

**DETALHES:**
- Nome do projeto: `church360-dev`
- Região: South America (São Paulo) se disponível
- Senha do DB: Anotar em local seguro (será necessária)
- Plano: Free Tier (2 projetos gratuitos)

**POR QUÊ:**  
Supabase fornece Postgres + Auth + Storage + Edge Functions em uma plataforma unificada.

**VALIDAÇÃO:**  
Acessar Dashboard do Supabase → Ver projeto criado → Clicar em "Table Editor" → Ver interface vazia pronta para receber tabelas.

**PRÓXIMO:** F1.P2

---

#### F1.P2: Preparar SQL Templates
**O QUE:**  
Na pasta `backend-scripts/`, criar arquivo `00_schema_base.sql` com o schema completo do banco.

**CONTEÚDO:**  
Usar o SQL template que já foi criado anteriormente (artifact "Church 360 - Template SQL Base"). Copiar todo o conteúdo para este arquivo.

**POR QUÊ:**  
Ter o schema versionado em arquivo permite recriar o banco facilmente e manter histórico de mudanças.

**VALIDAÇÃO:**  
Arquivo `00_schema_base.sql` existe com aproximadamente 600+ linhas de SQL.

**PRÓXIMO:** F1.P3

---

#### F1.P3: Executar Schema SQL no Supabase
**O QUE:**  
Copiar conteúdo do arquivo SQL e executar no SQL Editor do Supabase.

**PASSOS:**
1. No Dashboard Supabase → SQL Editor (menu lateral)
2. Clicar em "New Query"
3. Colar todo conteúdo do `00_schema_base.sql`
4. Clicar em "Run" (Ctrl+Enter)
5. Aguardar execução (pode levar 10-20 segundos)

**POR QUÊ:**  
Cria todas as tabelas, relacionamentos, índices e dados iniciais de uma vez.

**VALIDAÇÃO:**  
- Nenhum erro vermelho aparece após execução
- Table Editor → Ver múltiplas tabelas criadas: member, church_settings, campus, fund, etc
- Verificar se dados seed existem: fund deve ter 5 registros (Dízimos, Ofertas, etc)

**ATENÇÃO:** Se houver erros, não prossiga. Copie o erro e peça ajuda para debugar.

**PRÓXIMO:** F1.P4

---

#### F1.P4: Criar RLS Policies
**O QUE:**  
Criar arquivo `01_rls_policies.sql` com políticas de segurança Row Level Security.

**CONTEÚDO:**
```sql
-- Habilitar RLS em todas as tabelas principais
ALTER TABLE member ENABLE ROW LEVEL SECURITY;
ALTER TABLE "group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE event ENABLE ROW LEVEL SECURITY;
ALTER TABLE donation ENABLE ROW LEVEL SECURITY;

-- Política básica: usuários veem apenas dados da própria igreja
-- (Como estamos em single-tenant, esta política inicial é permissiva)
CREATE POLICY "Users can access all data in their DB"
  ON member
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Replicar para outras tabelas
CREATE POLICY "Users can access all data in their DB"
  ON "group"
  FOR ALL
  USING (true);

CREATE POLICY "Users can access all data in their DB"
  ON event
  FOR ALL
  USING (true);

CREATE POLICY "Users can access all data in their DB"
  ON donation
  FOR ALL
  USING (true);
```

**POR QUÊ:**  
RLS garante que mesmo com credenciais vazadas, dados ficam protegidos. Em single-tenant, a segurança principal é o isolamento por DB, mas RLS adiciona camada extra.

**VALIDAÇÃO:**  
Executar SQL no Editor → Sem erros → Authentication → Policies → Ver policies listadas.

**PRÓXIMO:** F1.P5

---

#### F1.P5: Criar Primeiro Usuário (Owner)
**O QUE:**  
Criar usuário de teste via Authentication do Supabase para simular o owner de uma igreja.

**PASSOS:**
1. Dashboard → Authentication → Users
2. Clicar "Add User"
3. Email: `owner@teste.com` (ou seu e-mail real)
4. Password: `Teste@123` (anotar)
5. Auto Confirm User: ON
6. Salvar

Depois, adicionar na tabela `user_account`:
```sql
INSERT INTO user_account (id, email, full_name, role_global, is_active)
VALUES (
  'cole-aqui-o-UUID-do-user-criado',
  'owner@teste.com',
  'Owner Teste',
  'owner',
  true
);
```

**POR QUÊ:**  
Permite testar login no app assim que conectarmos.

**VALIDAÇÃO:**  
- User aparece em Authentication → Users
- Registro existe em Table Editor → user_account

**PRÓXIMO:** F1.P6

---

#### F1.P6: Testar Conexão e Obter Credenciais
**O QUE:**  
Anotar as credenciais do projeto Supabase para usar no Flutter.

**ONDE ENCONTRAR:**  
Dashboard → Settings → API

**ANOTAR:**
- Project URL (ex: `https://xyzabc.supabase.co`)
- `anon` public key (chave longa começando com `eyJ...`)
- `service_role` secret key (NUNCA expor no app, só para scripts)

**POR QUÊ:**  
Flutter precisa dessas credenciais para se conectar ao Supabase.

**VALIDAÇÃO:**  
Copiar e colar em arquivo `backend-scripts/CREDENTIALS.txt` (adicionar ao .gitignore!).

**PRÓXIMO:** Fase 2

---

### ✅ Checklist de Conclusão - Fase 1
- [ ] F1.P1 - Projeto Supabase criado
- [ ] F1.P2 - SQL templates preparados
- [ ] F1.P3 - Schema executado
- [ ] F1.P4 - RLS configurado
- [ ] F1.P5 - Usuário owner criado
- [ ] F1.P6 - Credenciais anotadas

**QUANDO TODOS MARCADOS:** Backend está pronto! Atualizar "Estado Atual" para Fase 2.

---

## Fase 2: Flutter Foundation

**Status:** 🔴 TODO  
**Tempo Estimado:** 2-3 dias  
**Dependências:** ✅ Fase 0 e Fase 1 completas

### 🎯 Objetivo da Fase
Criar projeto Flutter base com arquitetura Clean, navegação, tema e integração com Supabase.

### 📦 Entregáveis
- [ ] Projeto Flutter criado
- [ ] Arquitetura Clean implementada (pastas)
- [ ] Dependências instaladas (Riverpod, GoRouter, Supabase)
- [ ] Tema Material 3 configurado
- [ ] Navegação básica funcionando
- [ ] Splash screen → Login screen

### 📝 Passos

#### F2.P1: Criar Projeto Flutter
**O QUE:**  
Usar Flutter CLI para criar novo projeto.

**NOME DO PROJETO:** `church360_app` (sem hífen, snake_case)

**ONDE CRIAR:**  
Dentro da pasta `church360/app/`

**POR QUÊ:**  
Estabelece estrutura base do Flutter com arquivos necessários.

**VALIDAÇÃO:**  
- Pasta `church360/app/church360_app` criada
- Arquivo `pubspec.yaml` existe
- Executar projeto: deve abrir contador padrão do Flutter

**PRÓXIMO:** F2.P2

---

#### F2.P2: Limpar Projeto Padrão
**O QUE:**  
Remover código exemplo do Flutter (contador) e preparar para nossa estrutura.

**AÇÕES:**
1. Deletar arquivo `lib/main.dart` completamente
2. Criar nova estrutura de pastas dentro de `lib/`
3. Criar novo `main.dart` minimalista

**ESTRUTURA DE PASTAS:**
```
lib/
├── main.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── network/
└── features/
    ├── auth/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── members/
        ├── data/
        ├── domain/
        └── presentation/
```

**POR QUÊ:**  
Clean Architecture separa responsabilidades em camadas claras: data (API/DB), domain (regras negócio), presentation (UI).

**VALIDAÇÃO:**  
Estrutura de pastas criada. App não compila ainda (esperado).

**PRÓXIMO:** F2.P3

---

#### F2.P3: Adicionar Dependências Principais
**O QUE:**  
Editar `pubspec.yaml` e adicionar pacotes necessários para o MVP.

**DEPENDÊNCIAS A ADICIONAR:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Navigation
  go_router: ^13.0.0
  
  # Backend
  supabase_flutter: ^2.0.0
  
  # Local Storage
  shared_preferences: ^2.2.0
  
  # Forms
  reactive_forms: ^16.1.0
  
  # Utils
  intl: ^0.18.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
```

**POR QUÊ:**  
Esses pacotes fornecem gerenciamento de estado (Riverpod), navegação (GoRouter), backend (Supabase) e utilitários essenciais.

**VALIDAÇÃO:**  
Executar no terminal dentro de `church360_app/`: verificar se todas as dependências baixam sem erros.

**PRÓXIMO:** F2.P4

---

#### F2.P4: Configurar Tema Material 3
**O QUE:**  
Criar arquivo de tema com cores e estilos baseados em Material Design 3.

**CRIAR ARQUIVO:** `lib/core/theme/app_theme.dart`

**CONTEÚDO BÁSICO:**
```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6), // Azul primary
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.dark,
    ),
  );
}
```

**POR QUÊ:**  
Centralizar tema permite mudanças visuais globais facilmente e carregamento de cores por igreja futuramente.

**VALIDAÇÃO:**  
Arquivo criado sem erros de compilação.

**PRÓXIMO:** F2.P5

---

#### F2.P5: Criar Main.dart com Provider Scope
**O QUE:**  
Configurar `main.dart` com Riverpod e estrutura base do app.

**CRIAR ARQUIVO:** `lib/main.dart`

**CONTEÚDO:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: 'COLE_SEU_PROJECT_URL_AQUI',
    anonKey: 'COLE_SEU_ANON_KEY_AQUI',
  );

  runApp(
    const ProviderScope(
      child: Church360App(),
    ),
  );
}

class Church360App extends StatelessWidget {
  const Church360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church 360',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.church, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            const Text('Church 360', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
```

**IMPORTANTE:**  
Substituir `COLE_SEU_PROJECT_URL_AQUI` e `COLE_SEU_ANON_KEY_AQUI` pelas credenciais anotadas na Fase 1.

**POR QUÊ:**  
Main.dart é o ponto de entrada do app. ProviderScope permite usar Riverpod em qualquer lugar.

**VALIDAÇÃO:**  
Executar app → Ver splash screen com ícone de igreja e texto "Church 360".

**PRÓXIMO:** F2.P6

---

#### F2.P6: Implementar Navegação com GoRouter
**O QUE:**  
Configurar rotas básicas: Splash → Login → Home.

**CRIAR ARQUIVO:** `lib/core/navigation/app_router.dart`

**ESTRUTURA:**
```dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);

// Telas placeholder (criar arquivos separados depois)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // TODO: Adicionar lógica de verificação de auth
    Future.delayed(const Duration(seconds: 2), () {
      context.go('/login');
    });
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/home'),
          child: const Text('Login (Placeholder)'),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Church 360')),
      body: const Center(child: Text('Home Screen')),
    );
  }
}
```

**ATUALIZAR main.dart:**  
Trocar `MaterialApp` por `MaterialApp.router` e usar `appRouter`.

**POR QUÊ:**  
GoRouter simplifica navegação, deep links e gerenciamento de rotas.

**VALIDAÇÃO:**  
- App abre → Splash por 2s → Redireciona para Login → Botão leva para Home
- Navegação fluida sem erros

**PRÓXIMO:** Fase 3

---

### ✅ Checklist de Conclusão - Fase 2
- [ ] F2.P1 - Projeto Flutter criado
- [ ] F2.P2 - Estrutura Clean organizada
- [ ] F2.P3 - Dependências instaladas
- [ ] F2.P4 - Tema configurado
- [ ] F2.P5 - Main.dart com Supabase
- [ ] F2.P6 - Navegação funcionando

**QUANDO TODOS MARCADOS:** Base do app pronta! Atualizar "Estado Atual" para Fase 3.

---

## Fase 3: Autenticação Multi-DB

**Status:** 🔴 TODO  
**Tempo Estimado:** 3-4 dias  
**Dependências:** ✅ Fase 2 completa

### 🎯 Objetivo da Fase
Implementar sistema de autenticação que conecta usuário ao banco de dados correto da igreja (single-tenant por DB).

### 📦 Entregáveis
- [ ] API Central criada (Edge Function no Supabase)
- [ ] Fluxo de login roteado implementado
- [ ] Persistência de sessão local
- [ ] Tela de login funcional
- [ ] Proteção de rotas (auth guard)
- [ ] Logout funcional

### 📝 Passos

#### F3.P1: Entender Fluxo de Autenticação Multi-DB
**O QUE:**  
Revisar como funciona o login em arquitetura single-tenant por DB.

**FLUXO:**
```
1. Usuário insere e-mail
2. App consulta API Central (qual DB pertence este e-mail?)
3. API Central retorna: db_url + church_id
4. App conecta ao Supabase correto
5. Usuário insere senha
6. Supabase autentica
7. App salva sessão + db_url localmente
```

**POR QUÊ:**  
Como cada igreja tem seu próprio banco, precisamos descobrir ONDE o usuário está cadastrado antes de autenticar.

**VALIDAÇÃO:**  
Compreensão do fluxo (não há código neste passo).

**PRÓXIMO:** F3.P2

---

#### F3.P2: Criar API Central (Simplificada para MVP)
**O QUE:**  
Para o MVP, vamos simplificar: criar uma tabela no próprio Supabase que mapeia e-mails para DBs (futuramente será um serviço separado).

**CRIAR TABELA no Supabase (SQL Editor):**
```sql
CREATE TABLE church_registry (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  church_name TEXT NOT NULL,
  church_slug TEXT UNIQUE NOT NULL,
  db_url TEXT NOT NULL,
  owner_email TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inserir registro de teste
INSERT INTO church_registry (church_name, church_slug, db_url, owner_email)
VALUES (
  'Igreja Teste',
  'igreja-teste',
  'https://seu-projeto.supabase.co',
  'owner@teste.com'
);
```

**POR QUÊ:**  
Para MVP, uma tabela simples resolve. Em produção, seria um serviço separado.

**VALIDAÇÃO:**  
Tabela `church_registry` criada com 1 registro de teste.

**PRÓXIMO:** F3.P3

---

#### F3.P3: Criar Repository de Autenticação
**O QUE:**  
Implementar camada de dados que se comunica com Supabase Auth.

**CRIAR ARQUIVO:** `lib/features/auth/data/auth_repository.dart`

**CONTEÚDO (simplificado):**
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Login com e-mail e senha
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Verificar se está autenticado
  User? get currentUser => _supabase.auth.currentUser;

  // Stream de mudanças de auth
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
```

**POR QUÊ:**  
Separar lógica de auth em repository facilita testes e manutenção.

**VALIDAÇÃO:**  
Arquivo criado sem erros de compilação.

**PRÓXIMO:** F3.P4

---

#### F3.P4: Criar Provider de Autenticação (Riverpod)
**O QUE:**  
Criar provider Riverpod que expõe estado de autenticação para toda a app.

**CRIAR ARQUIVO:** `lib/features/auth/presentation/providers/auth_provider.dart`

**CONTEÚDO:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});
```

**POR QUÊ:**  
Providers permitem acessar estado de auth de qualquer widget e rebuildar UI automaticamente.

**VALIDAÇÃO:**  
Arquivo criado. Pode adicionar import no main.dart para garantir que compila.

**PRÓXIMO:** F3.P5

---

#### F3.P5: Implementar Tela de Login
**O QUE:**  
Criar UI de login com campos de e-mail e senha.

**CRIAR ARQUIVO:** `lib/features/auth/presentation/screens/login_screen.dart`

**ESTRUTURA DA TELA:**
- Campo de texto para e-mail
- Campo de texto para senha (obscureText)
- Botão "Entrar"
- Indicador de loading durante login
- Mensagens de erro

**FUNCIONALIDADES:**
1. Validar formato de e-mail
2. Validar senha não vazia
3. Ao clicar "Entrar", chamar `authRepository.signIn()`
4. Se sucesso: navegar para `/home`
5. Se erro: mostrar SnackBar com mensagem

**POR QUÊ:**  
Permite usuário se autenticar no sistema.

**VALIDAÇÃO:**  
- Abrir app → Ver tela de login
- Inserir `owner@teste.com` + `Teste@123` → Login bem-sucedido → Navegar para home
- Inserir credenciais erradas → Ver mensagem de erro

**PRÓXIMO:** F3.P6

---

#### F3.P6: Implementar Proteção de Rotas
**O QUE:**  
Modificar `app_router.dart` para redirecionar usuários não autenticados.

**ADICIONAR ao GoRouter:**
```dart
redirect: (context, state) {
  final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
  final isLoggingIn = state.matchedLocation == '/login';
  
  if (!isAuthenticated && !isLoggingIn) {
    return '/login';
  }
  if (isAuthenticated && isLoggingIn) {
    return '/home';
  }
  return null;
}
```

**POR QUÊ:**  
Protege rotas privadas de acesso não autorizado.

**VALIDAÇÃO:**  
- Fechar e reabrir app sem login → Redireciona para /login
- Fazer login → Redireciona para /home
- Tentar acessar /home sem login → Bloqueia

**PRÓXIMO:** F3.P7

---

#### F3.P7: Implementar Persistência de Sessão
**O QUE:**  
Garantir que usuário não precise fazer login toda vez que abre o app.

**CONFIGURAÇÃO:**  
Supabase já persiste sessão automaticamente via `shared_preferences`. Apenas garantir que ao abrir app, verificamos sessão existente no splash.

**MODIFICAR SplashScreen:**
```dart
@override
void initState() {
  super.initState();
  _checkAuth();
}

Future<void> _checkAuth() async {
  await Future.delayed(const Duration(seconds: 2));
  final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
  context.go(isAuthenticated ? '/home' : '/login');
}
```

**POR QUÊ:**  
Melhora UX ao não exigir login repetido.

**VALIDAÇÃO:**  
- Fazer login → Fechar app → Reabrir → Estar logado (ir direto para home)

**PRÓXIMO:** Fase 4

---

### ✅ Checklist de Conclusão - Fase 3
- [ ] F3.P1 - Fluxo multi-DB compreendido
- [ ] F3.P2 - API Central criada (tabela registry)
- [ ] F3.P3 - AuthRepository implementado
- [ ] F3.P4 - Providers criados
- [ ] F3.P5 - Tela de login funcional
- [ ] F3.P6 - Rotas protegidas
- [ ] F3.P7 - Sessão persistida

**QUANDO TODOS MARCADOS:** Autenticação completa! Atualizar "Estado Atual" para Fase 4.

---

# 🎯 MVP CORE

---

## Fase 4: Módulo Membros

**Status:** 🔴 TODO  
**Tempo Estimado:** 5-7 dias  
**Dependências:** ✅ Fase 3 completa

### 🎯 Objetivo da Fase
Implementar CRUD completo de membros com lista, detalhes, cadastro e edição.

### 📦 Entregáveis
- [ ] Models e Entities de Member
- [ ] Repository com operações CRUD
- [ ] Providers Riverpod
- [ ] Tela de listagem com busca
- [ ] Tela de detalhes do membro
- [ ] Formulário de cadastro/edição
- [ ] Cache offline básico
- [ ] Validações de campos

### 📝 Passos

#### F4.P1: Criar Domain Entities
**O QUE:**  
Criar classes de domínio (entidades) representando Member e Household.

**CRIAR ARQUIVO:** `lib/features/members/domain/entities/member.dart`

**ESTRUTURA:**
```dart
class Member {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final MemberStatus status;
  final DateTime? birthdate;
  final DateTime createdAt;
  
  // ... outros campos
}

enum MemberStatus {
  visitor,
  newConvert,
  memberActive,
  memberInactive,
}
```

**POR QUÊ:**  
Entities representam regras de negócio puras, independentes de framework ou database.

**VALIDAÇÃO:**  
Arquivo criado com todas as propriedades do schema SQL (member table).

**PRÓXIMO:** F4.P2

---

#### F4.P2: Criar Data Models (DTOs)
**O QUE:**  
Criar models que representam dados vindos/indo para Supabase (com fromJson/toJson).

**CRIAR ARQUIVO:** `lib/features/members/data/models/member_model.dart`

**FUNCIONALIDADES:**
- Herdar de `Member` entity
- Adicionar `fromJson()` para converter JSON do Supabase
- Adicionar `toJson()` para enviar dados para Supabase
- Tratar campos nulos e conversões de tipo

**POR QUÊ:**  
Separar model (dados) de entity (negócio) mantém camadas desacopladas.

**VALIDAÇÃO:**  
Model criado e consegue serializar/deserializar JSON de teste.

**PRÓXIMO:** F4.P3

---

#### F4.P3: Criar Repository de Membros
**O QUE:**  
Implementar classe que realiza operações CRUD no Supabase.

**CRIAR ARQUIVO:** `lib/features/members/data/repositories/members_repository.dart`

**MÉTODOS PRINCIPAIS:**
```dart
class MembersRepository {
  Future<List<Member>> getMembers();
  Future<Member?> getMemberById(String id);
  Future<Member> createMember(Member member);
  Future<Member> updateMember(Member member);
  Future<void> deleteMember(String id);
  Future<List<Member>> searchMembers(String query);
}
```

**IMPLEMENTAÇÃO:**  
Usar `Supabase.instance.client.from('member')` para queries.

**POR QUÊ:**  
Centraliza toda comunicação com banco em um lugar.

**VALIDAÇÃO:**  
Testar cada método manualmente (pode criar arquivo de teste ou usar diretamente na UI).

**PRÓXIMO:** F4.P4

---

#### F4.P4: Criar Providers Riverpod
**O QUE:**  
Expor repository e streams de dados via providers.

**CRIAR ARQUIVO:** `lib/features/members/presentation/providers/members_provider.dart`

**PROVIDERS:**
```dart
// Repository provider
final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository(ref.watch(supabaseClientProvider));
});

// Lista de membros
final membersListProvider = FutureProvider<List<Member>>((ref) async {
  return ref.watch(membersRepositoryProvider).getMembers();
});

// Busca
final membersSearchProvider = StateProvider<String>((ref) => '');

// Filtrados por busca
final filteredMembersProvider = Provider<AsyncValue<List<Member>>>((ref) {
  final search = ref.watch(membersSearchProvider);
  // ... lógica de filtro
});
```

**POR QUÊ:**  
Providers permitem widgets reativos e gerenciamento de estado eficiente.

**VALIDAÇÃO:**  
Providers criados sem erros.

**PRÓXIMO:** F4.P5

---

#### F4.P5: Criar Tela de Listagem de Membros
**O QUE:**  
Interface que mostra todos os membros em lista com busca.

**CRIAR ARQUIVO:** `lib/features/members/presentation/screens/members_list_screen.dart`

**COMPONENTES:**
- AppBar com título "Membros"
- Campo de busca no topo
- ListView com cards de membros
- Floating Action Button para adicionar
- Loading indicator
- Empty state quando sem membros
- Pull-to-refresh

**POR QUÊ:**  
Principal ponto de entrada do módulo de membros.

**VALIDAÇÃO:**  
- Abrir tela → Ver lista de membros (se houver no DB)
- Buscar nome → Lista filtrada
- Pull down → Recarrega dados

**PRÓXIMO:** F4.P6

---

#### F4.P6: Criar Tela de Detalhes do Membro
**O QUE:**  
Tela que mostra todas as informações de um membro específico.

**CRIAR ARQUIVO:** `lib/features/members/presentation/screens/member_detail_screen.dart`

**SEÇÕES:**
- Foto/Avatar do membro
- Informações pessoais (nome, email, telefone)
- Status (badge colorido)
- Datas importantes (conversão, batismo)
- Botões de ação (editar, deletar)

**POR QUÊ:**  
Visualização completa e ações sobre o membro.

**VALIDAÇÃO:**  
Tocar em um membro da lista → Abrir detalhes → Ver informações corretas.

**PRÓXIMO:** F4.P7

---

#### F4.P7: Criar Formulário de Cadastro/Edição
**O QUE:**  
Tela com formulário para criar novo membro ou editar existente.

**CRIAR ARQUIVO:** `lib/features/members/presentation/screens/member_form_screen.dart`

**CAMPOS:**
- Nome (obrigatório)
- Sobrenome (obrigatório)
- Email (validar formato)
- Telefone (máscara brasileira)
- Data de nascimento (date picker)
- Status (dropdown)
- Botão Salvar

**VALIDAÇÕES:**
- Nome e sobrenome não vazios
- Email válido (se preenchido)
- Telefone formato correto
- Mostrar erros inline

**POR QUÊ:**  
Permite gestão completa do cadastro de membros.

**VALIDAÇÃO:**  
- Criar novo membro → Salvar → Ver na lista
- Editar membro existente → Atualizar → Ver mudanças

**PRÓXIMO:** F4.P8

---

#### F4.P8: Implementar Cache Offline Básico
**O QUE:**  
Usar shared_preferences para cachear lista de membros.

**ESTRATÉGIA:**
- Após buscar membros do Supabase, salvar JSON em cache
- Ao abrir app offline, carregar do cache
- Indicar visualmente quando dados são do cache

**POR QUÊ:**  
Melhora experiência em conexões ruins.

**VALIDAÇÃO:**  
- Abrir app online → Carregar membros
- Ativar modo avião
- Fechar e reabrir app → Ver membros do cache

**PRÓXIMO:** Fase 5

---

### ✅ Checklist de Conclusão - Fase 4
- [ ] F4.P1 - Entities criadas
- [ ] F4.P2 - Models (DTOs) criados
- [ ] F4.P3 - Repository implementado
- [ ] F4.P4 - Providers configurados
- [ ] F4.P5 - Lista de membros funcional
- [ ] F4.P6 - Detalhes funcionais
- [ ] F4.P7 - Formulário completo
- [ ] F4.P8 - Cache offline básico

**QUANDO TODOS MARCADOS:** Primeiro módulo MVP pronto! Atualizar para Fase 5.

---

## Fase 5: Módulo Grupos

**Status:** 🔴 TODO  
**Tempo Estimado:** 4-5 dias  
**Dependências:** ✅ Fase 4 completa

### 🎯 Objetivo da Fase
Implementar gestão de grupos/células com encontros e registro de presença.

### 📦 Entregáveis
- [ ] CRUD de Grupos
- [ ] Gestão de encontros
- [ ] Registro de presença
- [ ] Relatório básico de frequência

**ESTRUTURA SIMILAR À FASE 4:**  
Seguir mesmo padrão: Entities → Models → Repository → Providers → UI

### 📝 Passos
(Detalhamento similar à Fase 4, adaptado para grupos)

---

## Fase 6: Módulo Eventos

**Status:** 🔴 TODO  
**Tempo Estimado:** 5-6 dias  
**Dependências:** ✅ Fase 5 completa

### 🎯 Objetivo da Fase
Sistema de eventos com inscrições, geração de QR codes e check-in.

### 📦 Entregáveis
- [ ] CRUD de Eventos
- [ ] Sistema de inscrições
- [ ] Geração de QR code
- [ ] Tela de check-in com scanner
- [ ] Modo offline para check-in

---

## Fase 7: Módulo Doações

**Status:** 🔴 TODO  
**Tempo Estimado:** 5-6 dias  
**Dependências:** ✅ Fase 6 completa

### 🎯 Objetivo da Fase
Integração com pagamentos (Pix/Cartão) e emissão de recibos.

### 📦 Entregáveis
- [ ] Integração com Stripe/Pagar.me
- [ ] Fluxo de doação via Pix
- [ ] Geração de recibo PDF
- [ ] Histórico de doações

---

## Fase 8: Módulo Agenda

**Status:** 🔴 TODO  
**Tempo Estimado:** 3-4 dias  
**Dependências:** ✅ Fases 5 e 6 completas

### 🎯 Objetivo da Fase
Visualização unificada de agenda com eventos, grupos e escalas.

### 📦 Entregáveis
- [ ] Calendário visual
- [ ] Filtros por tipo
- [ ] Sincronização de itens

---

# 🔗 INTEGRAÇÃO

---

## Fase 9: Comunicações

**Status:** 🔴 TODO  
**Tempo Estimado:** 3-4 dias  
**Dependências:** ✅ Fase 4 completa (precisa de membros)

### 🎯 Objetivo da Fase
Sistema de push notifications para comunicação com membros.

### 📦 Entregáveis
- [ ] Firebase Cloud Messaging configurado
- [ ] Envio de notificações
- [ ] Templates básicos

---

## Fase 10: Relatórios MVP

**Status:** 🔴 TODO  
**Tempo Estimado:** 2-3 dias  
**Dependências:** ✅ Fases 4-8 completas

### 🎯 Objetivo da Fase
Dashboards e relatórios essenciais.

### 📦 Entregáveis
- [ ] Dashboard home com KPIs
- [ ] Relatório de presença
- [ ] Relatório financeiro básico

---

## Fase 11: Offline-First

**Status:** 🔴 TODO  
**Tempo Estimado:** 4-5 dias  
**Dependências:** ✅ Todas as fases de módulos completas

### 🎯 Objetivo da Fase
Melhorar funcionamento offline com sincronização bidirecional.

### 📦 Entregáveis
- [ ] Drift/Isar implementado
- [ ] Fila de sincronização
- [ ] Resolução de conflitos básica

---

# 🚀 FINALIZAÇÃO

---

## Fase 12: Testes & Qualidade

**Status:** 🔴 TODO  
**Tempo Estimado:** 3-4 dias  
**Dependências:** ✅ Fase 11 completa

### 🎯 Objetivo da Fase
Garantir qualidade e estabilidade do app.

### 📦 Entregáveis
- [ ] Testes unitários dos repositories
- [ ] Testes de widget principais
- [ ] Correção de bugs críticos
- [ ] Teste manual completo

---

## Fase 13: Deploy & Publicação

**Status:** 🔴 TODO  
**Tempo Estimado:** 2-3 dias  
**Dependências:** ✅ Fase 12 completa

### 🎯 Objetivo da Fase
Publicar MVP nas lojas.

### 📦 Entregáveis
- [ ] Build Android (AAB)
- [ ] Configurar Google Play Console
- [ ] Publicar beta fechado
- [ ] Documentação de uso

---

## 🎉 CONCLUSÃO DO MVP

Quando Fase 13 estiver completa, você terá:
✅ App funcional em produção  
✅ Backend configurado  
✅ Primeiros usuários testando  
✅ Base sólida para Fase 2 e 3

---

## 📌 NOTAS IMPORTANTES

### Como Usar Este Documento
1. **Sempre atualizar "Estado Atual"** no topo ao concluir uma fase
2. **Marcar checkboxes** conforme progride
3. **Anotar problemas** encontrados em cada fase
4. **Revisar semanalmente** o progresso geral

### Flexibilidade
- Ordem das fases 5-8 pode ser ajustada conforme prioridade
- Passos podem ser quebrados em sub-tarefas se necessário
- Timeframes são estimativas - ajustar conforme realidade

### Quando Pedir Ajuda
Se travar em qualquer passo:
1. Mencionar a fase e passo exato (ex: "F4.P3")
2. Descrever o que tentou
3. Copiar mensagens de erro

**Próximo Passo Imediato:** Começar F0.P1 - Instalar Flutter SDK

---

*Última atualização: [Data]*  
*Versão do Documento: 1.0*