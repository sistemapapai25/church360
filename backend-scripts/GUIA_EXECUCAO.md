# 🚀 Guia de Execução dos Scripts SQL

## ⚠️ IMPORTANTE: Execute na ORDEM CORRETA!

---

## 📝 PASSO 1: Executar Schema Base

### 1.1 Abrir SQL Editor
1. Acesse: https://heswheljavpcyspuicsi.supabase.co
2. Faça login
3. Clique em **"SQL Editor"** no menu lateral esquerdo
4. Clique em **"New Query"**

### 1.2 Copiar e Executar
1. Abra o arquivo **`00_schema_base.sql`** no VS Code
2. Selecione TODO o conteúdo (Ctrl+A)
3. Copie (Ctrl+C)
4. Volte para o Supabase SQL Editor
5. Cole no editor (Ctrl+V)
6. Clique no botão **"Run"** (ou Ctrl+Enter)
7. ⏳ Aguarde 10-30 segundos

### 1.3 Verificar Sucesso
✅ **Deve aparecer:** Mensagem de sucesso (sem erros vermelhos)
❌ **Se aparecer erro:** Copie a mensagem completa e me envie

### 1.4 Validar Tabelas Criadas
1. Clique em **"Table Editor"** no menu lateral
2. Você deve ver estas tabelas:
   - ✅ user_account
   - ✅ church_settings
   - ✅ campus
   - ✅ household
   - ✅ member
   - ✅ tag
   - ✅ step
   - ✅ fund
   - ✅ group
   - ✅ event
   - ✅ donation

3. Clique na tabela **`fund`** → Deve ter **5 registros**:
   - Dízimos
   - Ofertas
   - Missões
   - Construção
   - Ação Social

4. Clique na tabela **`tag`** → Deve ter **6 registros**

5. Clique na tabela **`step`** → Deve ter **5 registros**

---

## 📝 PASSO 2: Executar RLS Policies

### 2.1 Nova Query
1. Volte para **"SQL Editor"**
2. Clique em **"New Query"** (nova aba)

### 2.2 Copiar e Executar
1. Abra o arquivo **`01_rls_policies.sql`** no VS Code
2. Selecione TODO o conteúdo (Ctrl+A)
3. Copie (Ctrl+C)
4. Volte para o Supabase SQL Editor
5. Cole no editor (Ctrl+V)
6. Clique em **"Run"**
7. ⏳ Aguarde execução

### 2.3 Verificar Sucesso
✅ **Deve aparecer:** Mensagem de sucesso
❌ **Se aparecer erro:** Copie e me envie

### 2.4 Validar Policies Criadas
1. Vá em **"Authentication"** → **"Policies"** no menu lateral
2. Deve ver múltiplas policies listadas para cada tabela

---

## 🎉 CONCLUSÃO

Quando ambos os scripts executarem com sucesso:

✅ Backend configurado!
✅ Tabelas criadas!
✅ Dados seed inseridos!
✅ Segurança RLS ativada!

**Próximo passo:** Criar primeiro usuário owner

---

## 🆘 Problemas Comuns

### Erro: "relation does not exist"
**Causa:** Você executou o script 01 antes do 00
**Solução:** Execute o 00_schema_base.sql PRIMEIRO

### Erro: "type already exists"
**Causa:** Script já foi executado parcialmente
**Solução:** Me avise para criar script de limpeza

### Erro: "permission denied"
**Causa:** Problema de autenticação
**Solução:** Verifique se está logado no projeto correto

---

**Última atualização:** 13/10/2025

