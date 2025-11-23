# Widgets de Controle de Permissões

Este diretório contém widgets para controlar o acesso baseado em permissões.

## Widgets Disponíveis

### 1. PermissionGate

Controla a exibição de widgets baseado em permissões do usuário.

**Uso básico:**
```dart
PermissionGate(
  permission: 'members.create',
  child: ElevatedButton(
    onPressed: () => createMember(),
    child: Text('Criar Membro'),
  ),
  fallback: Text('Sem permissão'),
)
```

**Com loading:**
```dart
PermissionGate(
  permission: 'financial.view',
  showLoading: true,
  child: FinancialWidget(),
)
```

### 2. MultiPermissionGate

Controla a exibição baseado em múltiplas permissões.

**Lógica AND (requer todas):**
```dart
MultiPermissionGate(
  permissions: ['members.create', 'members.edit'],
  requireAll: true,
  child: MemberFormWidget(),
)
```

**Lógica OR (requer pelo menos uma):**
```dart
MultiPermissionGate(
  permissions: ['financial.view', 'financial.view_reports'],
  requireAll: false,
  child: FinancialDashboard(),
)
```

### 3. PermissionBuilder

Builder pattern para controle de permissões com mais flexibilidade.

```dart
PermissionBuilder(
  permission: 'members.edit',
  builder: (context, hasPermission) {
    return ElevatedButton(
      onPressed: hasPermission ? () => editMember() : null,
      child: Text('Editar'),
    );
  },
)
```

### 4. DisabledByPermission

Desabilita um widget se o usuário não tiver permissão.

```dart
DisabledByPermission(
  permission: 'members.delete',
  disabledTooltip: 'Você não tem permissão para deletar membros',
  child: IconButton(
    icon: Icon(Icons.delete),
    onPressed: () => deleteMember(),
  ),
)
```

### 5. DashboardAccessGate

Controla o acesso ao Dashboard baseado no nível de acesso do usuário.

**Uso em rotas:**
```dart
GoRoute(
  path: '/dashboard',
  builder: (context, state) => DashboardAccessGate(
    child: DashboardScreen(),
  ),
)
```

**Com redirecionamento:**
```dart
DashboardAccessGate(
  redirectOnDenied: true,
  redirectRoute: '/home',
  child: DashboardScreen(),
)
```

### 6. DashboardMenuItem

Item de menu que só aparece se o usuário tiver acesso ao Dashboard.

```dart
DashboardMenuItem(
  icon: Icons.dashboard,
  title: 'Dashboard',
  onTap: () => context.push('/dashboard'),
)
```

### 7. ConditionalDashboardAccess

Builder pattern para acesso condicional ao Dashboard.

```dart
ConditionalDashboardAccess(
  builder: (context, canAccess) {
    if (canAccess) {
      return DashboardButton();
    } else {
      return UpgradeButton();
    }
  },
)
```

## Códigos de Permissões

### Membros
- `members.view` - Ver membros
- `members.create` - Criar membro
- `members.edit` - Editar membro
- `members.delete` - Deletar membro
- `members.export` - Exportar membros

### Grupos
- `groups.view` - Ver grupos
- `groups.create` - Criar grupo
- `groups.edit` - Editar grupo
- `groups.delete` - Deletar grupo
- `groups.manage_own` - Gerenciar próprio grupo (requer contexto)
- `groups.manage_all` - Gerenciar todos grupos

### Eventos
- `events.view` - Ver eventos
- `events.create` - Criar evento
- `events.edit` - Editar evento
- `events.delete` - Deletar evento
- `events.checkin` - Check-in eventos

### Finanças
- `financial.view` - Ver finanças
- `financial.view_reports` - Ver relatórios financeiros
- `financial.create_contribution` - Registrar contribuição
- `financial.create_expense` - Registrar despesa
- `financial.edit` - Editar finanças
- `financial.delete` - Deletar finanças
- `financial.approve` - Aprovar despesas

### Visitantes
- `visitors.view` - Ver visitantes
- `visitors.create` - Registrar visitante
- `visitors.edit` - Editar visitante
- `visitors.delete` - Deletar visitante
- `visitors.followup` - Acompanhar visitante

### Ministérios
- `ministries.view` - Ver ministérios
- `ministries.create` - Criar ministério
- `ministries.edit` - Editar ministério
- `ministries.delete` - Deletar ministério
- `ministries.manage_members` - Gerenciar membros do ministério (requer contexto)
- `ministries.manage_schedule` - Gerenciar escalas (requer contexto)

### Configurações
- `settings.view` - Ver configurações
- `settings.edit` - Editar configurações
- `settings.manage_users` - Gerenciar usuários
- `settings.manage_permissions` - Gerenciar permissões
- `settings.manage_roles` - Gerenciar cargos
- `settings.manage_access_levels` - Gerenciar níveis de acesso

### Dashboard
- `dashboard.access` - Acessar Dashboard
- `dashboard.configure` - Configurar Dashboard

## Exemplos Práticos

### Botão de Criar Membro
```dart
PermissionGate(
  permission: 'members.create',
  child: FloatingActionButton(
    onPressed: () => context.push('/members/create'),
    child: Icon(Icons.add),
  ),
)
```

### Menu de Ações com Múltiplas Permissões
```dart
MultiPermissionGate(
  permissions: ['members.edit', 'members.delete'],
  requireAll: false,
  child: PopupMenuButton(
    itemBuilder: (context) => [
      PopupMenuItem(child: Text('Editar')),
      PopupMenuItem(child: Text('Deletar')),
    ],
  ),
)
```

### Botão Desabilitado por Permissão
```dart
DisabledByPermission(
  permission: 'financial.approve',
  child: ElevatedButton(
    onPressed: () => approvExpense(),
    child: Text('Aprovar Despesa'),
  ),
)
```

### Tela Protegida por Permissão
```dart
class MembersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: 'members.view',
      child: Scaffold(
        appBar: AppBar(title: Text('Membros')),
        body: MembersList(),
        floatingActionButton: PermissionGate(
          permission: 'members.create',
          child: FloatingActionButton(
            onPressed: () => context.push('/members/create'),
            child: Icon(Icons.add),
          ),
        ),
      ),
      fallback: Scaffold(
        appBar: AppBar(title: Text('Acesso Negado')),
        body: Center(
          child: Text('Você não tem permissão para ver membros'),
        ),
      ),
    );
  }
}
```

