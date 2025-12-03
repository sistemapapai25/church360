# Políticas RLS - Sistema de Permissões

## Problema Identificado

O erro `PostgrestException(message: new row violates row-level security policy for table "roles", code: 42501)` ocorreu porque as políticas RLS estavam usando apenas `USING` para operações `FOR ALL`, mas o PostgreSQL requer `WITH CHECK` para operações de INSERT/UPDATE/DELETE.

## Solução Aplicada

### 1. Separação das Políticas por Operação

Ao invés de usar `FOR ALL`, criamos políticas específicas para cada operação:
- `FOR SELECT` - Usa apenas `USING`
- `FOR INSERT` - Usa apenas `WITH CHECK`
- `FOR UPDATE` - Usa `USING` e `WITH CHECK`
- `FOR DELETE` - Usa apenas `USING`

### 2. Políticas Temporárias (Para Desenvolvimento)

**⚠️ IMPORTANTE: Estas políticas são TEMPORÁRIAS e devem ser ajustadas em produção!**

Atualmente, as políticas permitem que **qualquer usuário autenticado** (`auth.uid() IS NOT NULL`) possa gerenciar cargos, contextos e permissões. Isso foi feito para facilitar o desenvolvimento e testes.

#### Tabela: `roles`

```sql
-- SELECT: Todos podem ver cargos ativos
CREATE POLICY "Todos podem ver cargos ativos"
  ON roles FOR SELECT
  USING (is_active = true);

-- INSERT: Qualquer usuário autenticado pode criar (TEMPORÁRIO)
CREATE POLICY "Criar cargos requer permissão"
  ON roles FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL OR check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- UPDATE: Qualquer usuário autenticado pode atualizar (TEMPORÁRIO)
CREATE POLICY "Atualizar cargos requer permissão"
  ON roles FOR UPDATE
  USING (
    auth.uid() IS NOT NULL OR check_user_permission(auth.uid(), 'settings.manage_roles')
  )
  WITH CHECK (
    auth.uid() IS NOT NULL OR check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- DELETE: Qualquer usuário autenticado pode deletar (TEMPORÁRIO)
CREATE POLICY "Deletar cargos requer permissão"
  ON roles FOR DELETE
  USING (
    auth.uid() IS NOT NULL OR check_user_permission(auth.uid(), 'settings.manage_roles')
  );
```

#### Tabela: `role_contexts`

Mesma estrutura da tabela `roles`, permitindo qualquer usuário autenticado gerenciar contextos.

#### Tabela: `role_permissions`

Mesma estrutura, permitindo qualquer usuário autenticado gerenciar permissões de cargos.

#### Tabela: `user_roles`

```sql
-- SELECT: Usuários veem próprios cargos
CREATE POLICY "Usuários veem próprios cargos"
  ON user_roles FOR SELECT
  USING (user_id = auth.uid());

-- SELECT: Quem tem permissão pode ver todos
CREATE POLICY "Ver todos cargos requer permissão"
  ON user_roles FOR SELECT
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- INSERT/UPDATE/DELETE: Qualquer usuário autenticado (TEMPORÁRIO)
-- ... (mesma estrutura das outras tabelas)
```

## Próximos Passos (Produção)

### 1. Configurar Níveis de Acesso

Antes de ir para produção, você deve:

1. **Definir níveis de acesso para todos os usuários**:
   ```sql
   INSERT INTO user_access_level (user_id, access_level_number)
   VALUES ('user-uuid-here', 5); -- 5 = Admin
   ```

2. **Criar cargos iniciais** (Pastor, Líder, etc.)

3. **Atribuir permissões aos cargos**:
   ```sql
   INSERT INTO role_permissions (role_id, permission_id)
   SELECT 'role-uuid', id FROM permissions WHERE code = 'settings.manage_roles';
   ```

4. **Atribuir cargos aos usuários**:
   ```sql
   INSERT INTO user_roles (user_id, role_id)
   VALUES ('user-uuid', 'role-uuid');
   ```

### 2. Remover Políticas Temporárias

Depois de configurar os cargos e permissões, **REMOVA** a parte `auth.uid() IS NOT NULL OR` das políticas:

```sql
-- ANTES (Temporário - Desenvolvimento)
CREATE POLICY "Criar cargos requer permissão"
  ON roles FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL OR check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- DEPOIS (Produção)
CREATE POLICY "Criar cargos requer permissão"
  ON roles FOR INSERT
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );
```

### 3. Script de Produção

Execute o script `17_fix_roles_rls.sql` que contém as políticas corretas (sem a parte temporária).

## Testando o Sistema

1. **Criar um cargo** (ex: "Pastor")
2. **Atribuir permissões ao cargo** (ex: `settings.manage_roles`)
3. **Atribuir o cargo a um usuário**
4. **Testar se o usuário consegue criar novos cargos**

## Permissões Necessárias

Para gerenciar o sistema de permissões, um usuário precisa de:

- `settings.manage_roles` - Gerenciar cargos e contextos
- `settings.manage_permissions` - Atribuir cargos a usuários e gerenciar permissões customizadas

## Segurança

⚠️ **ATENÇÃO**: As políticas atuais são TEMPORÁRIAS e permitem que qualquer usuário autenticado gerencie o sistema. Isso é adequado apenas para desenvolvimento/testes.

Em produção, você DEVE:
1. Remover a condição `auth.uid() IS NOT NULL OR`
2. Garantir que apenas usuários com as permissões corretas possam gerenciar o sistema
3. Testar todas as operações com diferentes níveis de acesso

## Arquivos Relacionados

- `15_permissions_system.sql` - Script original (com políticas incorretas)
- `17_fix_roles_rls.sql` - Script de correção (políticas corretas para produção)
- Este arquivo - Documentação das políticas aplicadas

