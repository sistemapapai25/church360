# 🚀 COMO EXECUTAR A IMPORTAÇÃO DA BÍBLIA

## ⚠️ PASSO 1: OBTER A SERVICE ROLE KEY

A **Service Role Key** é necessária para inserir dados no Supabase.

### Como encontrar:

1. Abra o **Supabase Dashboard**: https://supabase.com/dashboard
2. Selecione o projeto **Church 360** (heswheljavpcyspuicsi)
3. Vá em **Settings** (⚙️ no menu lateral)
4. Clique em **API**
5. Role até a seção **Project API keys**
6. Copie a chave **`service_role`** (secret)
   - ⚠️ **NÃO** use a `anon` key (ela não tem permissão para inserir)
   - ⚠️ **NUNCA** exponha a service_role key no app Flutter!

---

## 📝 PASSO 2: EDITAR O SCRIPT

1. Abra o arquivo `import_bible.py`
2. Na linha 9, substitua `"SUA_SERVICE_ROLE_KEY_AQUI"` pela chave que você copiou
3. Salve o arquivo

Exemplo:
```python
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhlc3doZWxqYXZwY3lzcHVpY3NpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTc0Nzg0MywiZXhwIjoyMDY1MzIzODQzfQ.XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
```

---

## ▶️ PASSO 3: EXECUTAR O SCRIPT

No terminal (PowerShell), execute:

```bash
cd "C:\Users\Alcides\Desktop\Church 360 Gabriel\ARC"
python import_bible.py
```

---

## ⏱️ TEMPO ESTIMADO

- Download do JSON: ~5 segundos
- Importação dos 31.105 versículos: ~5-10 minutos
- Total: ~10-15 minutos

---

## ✅ VERIFICAR IMPORTAÇÃO

Após a execução, verifique no Supabase SQL Editor:

```sql
-- Contar total de versículos
SELECT COUNT(*) FROM bible_verse;
-- Deve retornar: 31105

-- Ver primeiro versículo
SELECT * FROM bible_verse 
WHERE book_id = 1 AND chapter = 1 AND verse = 1;
-- Deve retornar: "No princípio criou Deus os céus e a terra."

-- Ver último versículo
SELECT * FROM bible_verse 
WHERE book_id = 66 AND chapter = 22 AND verse = 21;
-- Deve retornar: "A graça de nosso Senhor Jesus Cristo seja com todos vós. Amém."
```

---

## 🎯 PRONTO!

Após a importação bem-sucedida:
1. Abra o app Flutter
2. Vá em **Menu Mais → Bíblia**
3. Navegue pelos livros
4. Leia os capítulos!

**Que Deus abençoe! 🙏📖✨**

