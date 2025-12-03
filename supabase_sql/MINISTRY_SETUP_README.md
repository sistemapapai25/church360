# 🏛️ SETUP DE MINISTÉRIOS

## 📋 **PASSO 1: EXECUTAR SQL**

1. Abra o **Supabase Dashboard**: https://supabase.com/dashboard
2. Selecione o projeto **Church 360**
3. Vá em **SQL Editor**
4. Clique em **New Query**
5. Cole todo o conteúdo do arquivo `ministry_tables.sql`
6. Clique em **Run** (ou pressione Ctrl+Enter)

---

## ✅ **O QUE SERÁ CRIADO:**

### **Tabelas:**
- ✅ `ministry` - Tabela de ministérios
- ✅ `ministry_member` - Tabela de membros dos ministérios

### **Ministérios Pré-Populados (25):**

**ADORAÇÃO & ENSINO:**
1. 🎵 Louvor e Adoração
2. 🙏 Intercessão
3. 📖 Ensino/Escola Bíblica
4. 💬 Discipulado
5. 🎭 Teatro/Artes
6. 💃 Dança

**EVANGELISMO & MISSÕES:**
7. 📢 Evangelismo
8. 🌍 Missões
9. 🏠 Visitação
10. 👥 Células/Grupos Pequenos

**FAIXAS ETÁRIAS:**
11. 👶 Crianças
12. 👴 Terceira Idade

**GRUPOS ESPECÍFICOS:**
13. 🧒 Adolescentes
14. 🎓 Jovens
15. 💑 Casais
16. 👨 Homens
17. 👩 Mulheres

**SERVIÇOS & APOIO:**
18. 🤝 Diaconia
19. 👋 Recepção/Hospitalidade
20. 📱 Mídia/Comunicação
21. 💼 Aconselhamento
22. 🛡️ Segurança
23. 🚗 Estacionamento
24. 🧹 Limpeza/Manutenção
25. 🍽️ Cozinha/Alimentação

---

## 🔍 **VERIFICAR IMPORTAÇÃO:**

No Supabase SQL Editor, execute:

```sql
-- Contar ministérios
SELECT COUNT(*) FROM ministry;
-- Deve retornar: 25

-- Ver todos os ministérios
SELECT name, icon, color, is_active FROM ministry ORDER BY name;

-- Ver ministérios por categoria (exemplo)
SELECT name, description FROM ministry 
WHERE name IN ('Louvor e Adoração', 'Intercessão', 'Ensino/Escola Bíblica', 'Discipulado', 'Teatro/Artes', 'Dança')
ORDER BY name;
```

---

## 🎯 **TESTAR NO APP:**

1. Abra o app Flutter
2. Vá em **Menu Mais → Ministérios**
3. Você verá todos os 25 ministérios com:
   - ✅ Ícones coloridos (Font Awesome)
   - ✅ Nome e descrição
   - ✅ Cores diferentes para cada ministério
   - ✅ Contagem de membros (0 inicialmente)

---

## 🚀 **PRÓXIMOS PASSOS (FUTURO):**

Quando quiser adicionar membros aos ministérios:
1. Clique em um ministério
2. Vá em "Adicionar Membro"
3. Selecione o membro
4. Escolha a função (Líder, Coordenador, Membro)
5. Salve!

---

**ESTÁ TUDO PRONTO!** 🎉⛪✨

Cada ministério tem:
- ✅ Ícone único (Font Awesome)
- ✅ Cor personalizada
- ✅ Descrição clara da função
- ✅ Estrutura pronta para adicionar membros

**QUE DEUS ABENÇOE TODOS OS MINISTÉRIOS DA IGREJA!** 🙏📖✨

