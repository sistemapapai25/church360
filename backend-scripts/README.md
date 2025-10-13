# Backend Scripts - Church 360

Este diretório contém os scripts SQL para configurar o backend do Church 360 no Supabase.

## 📋 Ordem de Execução

Execute os scripts na seguinte ordem:

### 1. `00_schema_base.sql`
**O que faz:**
- Cria todas as tabelas do banco de dados
- Define enums e tipos
- Cria índices para performance
- Adiciona triggers para updated_at
- Insere dados seed (fundos, tags, steps)

**Como executar:**
1. Acesse: https://heswheljavpcyspuicsi.supabase.co
2. Faça login
3. Vá em: **SQL Editor** (menu lateral esquerdo)
4. Clique em **"New Query"**
5. Copie TODO o conteúdo de `00_schema_base.sql`
6. Cole no editor
7. Clique em **"Run"** (ou Ctrl+Enter)
8. Aguarde execução (10-30 segundos)
9. ✅ Verifique se não há erros vermelhos

**Validação:**
- Vá em **Table Editor** → Deve ver múltiplas tabelas criadas
- Verifique tabela `fund` → Deve ter 5 registros (Dízimos, Ofertas, etc)
- Verifique tabela `tag` → Deve ter 6 registros
- Verifique tabela `step` → Deve ter 5 registros

---

### 2. `01_rls_policies.sql`
**O que faz:**
- Habilita Row Level Security (RLS) em todas as tabelas
- Cria políticas de acesso
- Garante segurança dos dados

**Como executar:**
1. No **SQL Editor**, clique em **"New Query"**
2. Copie TODO o conteúdo de `01_rls_policies.sql`
3. Cole no editor
4. Clique em **"Run"**
5. Aguarde execução
6. ✅ Verifique se não há erros

**Validação:**
- Vá em **Authentication** → **Policies**
- Deve ver múltiplas policies listadas

---

## 🔑 Credenciais

As credenciais do Supabase estão em `CREDENTIALS.txt` (não commitado no Git).

**Credenciais atuais:**
- **Project URL:** https://heswheljavpcyspuicsi.supabase.co
- **Anon Key:** (ver CREDENTIALS.txt)

---

## 📝 Próximos Passos

Após executar os scripts:

1. ✅ Criar primeiro usuário owner (via Authentication)
2. ✅ Testar conexão
3. ✅ Partir para Fase 2 (Flutter Foundation)

---

## ⚠️ Importante

- **NUNCA** commite o arquivo `CREDENTIALS.txt` no Git
- O `service_role` key é SECRETO - nunca exponha no app
- Use apenas `anon` key no Flutter
- Cada igreja terá seu próprio banco de dados (single-tenant)

---

## 🆘 Problemas?

Se encontrar erros ao executar os scripts:

1. Copie a mensagem de erro completa
2. Verifique se executou na ordem correta
3. Verifique se o projeto Supabase está ativo
4. Entre em contato para suporte

---

**Última atualização:** 13/10/2025

