import json
import requests
from supabase import create_client, Client

# Configurações do Supabase
SUPABASE_URL = "https://heswheljavpcyspuicsi.supabase.co"
# ⚠️ IMPORTANTE: Use a SERVICE ROLE KEY (não a anon key)
# Encontre em: Supabase Dashboard → Settings → API → service_role (secret)
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhlc3doZWxqYXZwY3lzcHVpY3NpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTc0Nzg0MywiZXhwIjoyMDY1MzIzODQzfQ.XawqffPzsxhiqBxB-fcbIRTqVHnb2tya4VR2lYfdnps"

# Criar cliente Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Baixar JSON da Bíblia
print("Baixando Bíblia ARC...")
url = "https://raw.githubusercontent.com/damarals/biblias/master/inst/json/ARC.json"
response = requests.get(url)
bible_data = response.json()

print(f"Total de livros: {len(bible_data)}")

# Processar e importar versículos
verse_id = 1
batch = []
batch_size = 1000
total_verses = 0

for book in bible_data:
    book_id = book.get('id') or bible_data.index(book) + 1
    chapters = book.get('chapters', [])

    print(f"Processando livro {book_id}: {book.get('name', 'Desconhecido')}...")

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
            total_verses += 1

            # Inserir em lotes de 1000
            if len(batch) >= batch_size:
                print(f"  Inserindo lote de {len(batch)} versículos... (Total: {total_verses})")
                try:
                    supabase.table('bible_verse').insert(batch).execute()
                    batch = []
                except Exception as e:
                    print(f"  ❌ Erro ao inserir lote: {e}")
                    print(f"  Tentando inserir versículos individualmente...")
                    for verse in batch:
                        try:
                            supabase.table('bible_verse').insert(verse).execute()
                        except Exception as e2:
                            print(f"    ❌ Erro no versículo {verse['id']}: {e2}")
                    batch = []

# Inserir versículos restantes
if batch:
    print(f"Inserindo lote final de {len(batch)} versículos...")
    try:
        supabase.table('bible_verse').insert(batch).execute()
    except Exception as e:
        print(f"❌ Erro ao inserir lote final: {e}")
        print(f"Tentando inserir versículos individualmente...")
        for verse in batch:
            try:
                supabase.table('bible_verse').insert(verse).execute()
            except Exception as e2:
                print(f"  ❌ Erro no versículo {verse['id']}: {e2}")

print("\n✅ Importação concluída!")
print(f"Total de versículos importados: {total_verses}")
print(f"\nVerifique no Supabase:")
print(f"SELECT COUNT(*) FROM bible_verse;")