# 📖 IMPORTAÇÃO DA BÍBLIA SAGRADA (ARC)

Este guia explica como importar os dados completos da Bíblia Almeida Revista e Corrigida (ARC) para o Supabase.

---

## ✅ **PASSO 1: CRIAR AS TABELAS**

1. Abra o **Supabase Dashboard**
2. Vá em **SQL Editor**
3. Clique em **New Query**
4. Abra o arquivo `bible_tables.sql`
5. Copie todo o conteúdo
6. Cole no SQL Editor
7. Clique em **Run** (ou Ctrl+Enter)

Isso criará:
- ✅ Tabela `bible_book` (66 livros)
- ✅ Tabela `bible_verse` (vazia, pronta para receber os versículos)
- ✅ Tabela `bible_bookmark` (favoritos dos usuários)
- ✅ Políticas RLS
- ✅ Índices para performance

---

## 📥 **PASSO 2: BAIXAR OS DADOS DA BÍBLIA**

A Bíblia ARC está disponível gratuitamente (domínio público) no GitHub:

**Link direto para download:**
https://github.com/damarals/biblias/blob/master/inst/json/ARC.json?raw=true

Ou navegue até:
https://github.com/damarals/biblias

E baixe o arquivo `inst/json/ARC.json`

---

## 🔄 **PASSO 3: CONVERTER E IMPORTAR OS DADOS**

### **OPÇÃO A: Usar Script Python (Recomendado)**

Crie um arquivo `import_bible.py`:

```python
import json
import requests
from supabase import create_client, Client

# Configurações do Supabase
SUPABASE_URL = "SUA_URL_DO_SUPABASE"
SUPABASE_KEY = "SUA_SERVICE_KEY_DO_SUPABASE"

# Criar cliente Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Baixar JSON da Bíblia
print("Baixando Bíblia ARC...")
url = "https://github.com/damarals/biblias/blob/master/inst/json/ARC.json?raw=true"
response = requests.get(url)
bible_data = response.json()

print(f"Total de livros: {len(bible_data)}")

# Processar e importar versículos
verse_id = 1
batch = []
batch_size = 1000

for book in bible_data:
    book_id = book.get('id') or bible_data.index(book) + 1
    chapters = book.get('chapters', [])
    
    for chapter_num, verses in enumerate(chapters, start=1):
        for verse_num, verse_text in enumerate(verses, start=1):
            batch.append({
                'id': verse_id,
                'book_id': book_id,
                'chapter': chapter_num,
                'verse': verse_num,
                'text': verse_text
            })
            verse_id += 1
            
            # Inserir em lotes de 1000
            if len(batch) >= batch_size:
                print(f"Inserindo lote de {len(batch)} versículos...")
                supabase.table('bible_verse').insert(batch).execute()
                batch = []

# Inserir versículos restantes
if batch:
    print(f"Inserindo lote final de {len(batch)} versículos...")
    supabase.table('bible_verse').insert(batch).execute()

print("✅ Importação concluída!")
print(f"Total de versículos importados: {verse_id - 1}")
```

Execute:
```bash
pip install supabase requests
python import_bible.py
```

---

### **OPÇÃO B: Usar Script Node.js**

Crie um arquivo `import_bible.js`:

```javascript
const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');

// Configurações do Supabase
const SUPABASE_URL = 'SUA_URL_DO_SUPABASE';
const SUPABASE_KEY = 'SUA_SERVICE_KEY_DO_SUPABASE';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function importBible() {
  console.log('Baixando Bíblia ARC...');
  
  const url = 'https://github.com/damarals/biblias/blob/master/inst/json/ARC.json?raw=true';
  const response = await axios.get(url);
  const bibleData = response.data;
  
  console.log(`Total de livros: ${bibleData.length}`);
  
  let verseId = 1;
  let batch = [];
  const batchSize = 1000;
  
  for (let bookIndex = 0; bookIndex < bibleData.length; bookIndex++) {
    const book = bibleData[bookIndex];
    const bookId = book.id || bookIndex + 1;
    const chapters = book.chapters || [];
    
    for (let chapterNum = 0; chapterNum < chapters.length; chapterNum++) {
      const verses = chapters[chapterNum];
      
      for (let verseNum = 0; verseNum < verses.length; verseNum++) {
        batch.push({
          id: verseId,
          book_id: bookId,
          chapter: chapterNum + 1,
          verse: verseNum + 1,
          text: verses[verseNum]
        });
        verseId++;
        
        // Inserir em lotes de 1000
        if (batch.length >= batchSize) {
          console.log(`Inserindo lote de ${batch.length} versículos...`);
          await supabase.from('bible_verse').insert(batch);
          batch = [];
        }
      }
    }
  }
  
  // Inserir versículos restantes
  if (batch.length > 0) {
    console.log(`Inserindo lote final de ${batch.length} versículos...`);
    await supabase.from('bible_verse').insert(batch);
  }
  
  console.log('✅ Importação concluída!');
  console.log(`Total de versículos importados: ${verseId - 1}`);
}

importBible().catch(console.error);
```

Execute:
```bash
npm install @supabase/supabase-js axios
node import_bible.js
```

---

### **OPÇÃO C: Importação Manual via CSV**

1. Baixe o JSON da Bíblia
2. Converta para CSV usando uma ferramenta online ou script
3. No Supabase Dashboard, vá em **Table Editor**
4. Selecione a tabela `bible_verse`
5. Clique em **Import data via spreadsheet**
6. Faça upload do CSV

---

## 🔍 **PASSO 4: VERIFICAR A IMPORTAÇÃO**

Execute no SQL Editor:

```sql
-- Contar total de versículos
SELECT COUNT(*) FROM bible_verse;
-- Deve retornar: 31105

-- Verificar primeiro versículo
SELECT * FROM bible_verse 
WHERE book_id = 1 AND chapter = 1 AND verse = 1;
-- Deve retornar: "No princípio criou Deus os céus e a terra."

-- Verificar último versículo
SELECT * FROM bible_verse 
WHERE book_id = 66 AND chapter = 22 AND verse = 21;
-- Deve retornar: "A graça de nosso Senhor Jesus Cristo seja com todos vós. Amém."
```

---

## ⚡ **DICAS DE PERFORMANCE**

1. **Desabilite RLS temporariamente** durante a importação:
```sql
ALTER TABLE bible_verse DISABLE ROW LEVEL SECURITY;
-- Importar dados...
ALTER TABLE bible_verse ENABLE ROW LEVEL SECURITY;
```

2. **Use transações** para importações grandes

3. **Monitore o uso de recursos** no Supabase Dashboard

---

## 📊 **ESTATÍSTICAS DA BÍBLIA ARC**

- **Total de livros**: 66
- **Antigo Testamento**: 39 livros
- **Novo Testamento**: 27 livros
- **Total de capítulos**: 1.189
- **Total de versículos**: 31.105
- **Versão**: Almeida Revista e Corrigida (1995)
- **Editora**: SBB (Sociedade Bíblica do Brasil)
- **Licença**: Domínio Público

---

## ✅ **PRONTO!**

Após a importação, o app Flutter já estará pronto para:
- ✅ Navegar pelos 66 livros
- ✅ Ler todos os 31.105 versículos
- ✅ Buscar por palavras/frases
- ✅ Favoritar versículos
- ✅ Compartilhar versículos

**Que Deus abençoe este projeto!** 🙏📖✨

