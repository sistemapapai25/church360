-- =====================================================
-- TABELAS: BÍBLIA SAGRADA
-- =====================================================

-- =====================================================
-- TABELA: LIVROS DA BÍBLIA
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_book (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  abbrev TEXT NOT NULL,
  testament TEXT NOT NULL, -- 'OT' (Old Testament) ou 'NT' (New Testament)
  order_number INTEGER NOT NULL,
  chapters INTEGER NOT NULL
);

-- Habilitar RLS
ALTER TABLE public.bible_book ENABLE ROW LEVEL SECURITY;

-- Criar políticas (todos podem ler)
DROP POLICY IF EXISTS "Todos podem visualizar livros da Bíblia" ON public.bible_book;
CREATE POLICY "Todos podem visualizar livros da Bíblia"
  ON public.bible_book
  FOR SELECT
  USING (true);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_bible_book_testament ON public.bible_book(testament);
CREATE INDEX IF NOT EXISTS idx_bible_book_order ON public.bible_book(order_number);

-- =====================================================
-- TABELA: VERSÍCULOS DA BÍBLIA
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_verse (
  id SERIAL PRIMARY KEY,
  book_id INTEGER NOT NULL REFERENCES public.bible_book(id) ON DELETE CASCADE,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  text TEXT NOT NULL,
  UNIQUE(book_id, chapter, verse)
);

-- Habilitar RLS
ALTER TABLE public.bible_verse ENABLE ROW LEVEL SECURITY;

-- Criar políticas (todos podem ler)
DROP POLICY IF EXISTS "Todos podem visualizar versículos da Bíblia" ON public.bible_verse;
CREATE POLICY "Todos podem visualizar versículos da Bíblia"
  ON public.bible_verse
  FOR SELECT
  USING (true);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_bible_verse_book ON public.bible_verse(book_id);
CREATE INDEX IF NOT EXISTS idx_bible_verse_chapter ON public.bible_verse(book_id, chapter);
CREATE INDEX IF NOT EXISTS idx_bible_verse_text ON public.bible_verse USING gin(to_tsvector('portuguese', text));

-- =====================================================
-- TABELA: FAVORITOS/MARCADORES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_bookmark (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  verse_id INTEGER NOT NULL REFERENCES public.bible_verse(id) ON DELETE CASCADE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, verse_id)
);

-- Habilitar RLS
ALTER TABLE public.bible_bookmark ENABLE ROW LEVEL SECURITY;

-- Criar políticas
DROP POLICY IF EXISTS "Usuários podem ver seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem ver seus próprios favoritos"
  ON public.bible_bookmark
  FOR SELECT
  USING (auth.uid() = member_id);

DROP POLICY IF EXISTS "Usuários podem criar seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem criar seus próprios favoritos"
  ON public.bible_bookmark
  FOR INSERT
  WITH CHECK (auth.uid() = member_id);

DROP POLICY IF EXISTS "Usuários podem atualizar seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem atualizar seus próprios favoritos"
  ON public.bible_bookmark
  FOR UPDATE
  USING (auth.uid() = member_id);

DROP POLICY IF EXISTS "Usuários podem deletar seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem deletar seus próprios favoritos"
  ON public.bible_bookmark
  FOR DELETE
  USING (auth.uid() = member_id);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_bible_bookmark_member ON public.bible_bookmark(member_id);
CREATE INDEX IF NOT EXISTS idx_bible_bookmark_verse ON public.bible_bookmark(verse_id);

-- =====================================================
-- DADOS: LIVROS DA BÍBLIA (66 livros)
-- =====================================================

INSERT INTO public.bible_book (id, name, abbrev, testament, order_number, chapters) VALUES
-- ANTIGO TESTAMENTO
(1, 'Gênesis', 'Gn', 'OT', 1, 50),
(2, 'Êxodo', 'Êx', 'OT', 2, 40),
(3, 'Levítico', 'Lv', 'OT', 3, 27),
(4, 'Números', 'Nm', 'OT', 4, 36),
(5, 'Deuteronômio', 'Dt', 'OT', 5, 34),
(6, 'Josué', 'Js', 'OT', 6, 24),
(7, 'Juízes', 'Jz', 'OT', 7, 21),
(8, 'Rute', 'Rt', 'OT', 8, 4),
(9, '1 Samuel', '1Sm', 'OT', 9, 31),
(10, '2 Samuel', '2Sm', 'OT', 10, 24),
(11, '1 Reis', '1Rs', 'OT', 11, 22),
(12, '2 Reis', '2Rs', 'OT', 12, 25),
(13, '1 Crônicas', '1Cr', 'OT', 13, 29),
(14, '2 Crônicas', '2Cr', 'OT', 14, 36),
(15, 'Esdras', 'Ed', 'OT', 15, 10),
(16, 'Neemias', 'Ne', 'OT', 16, 13),
(17, 'Ester', 'Et', 'OT', 17, 10),
(18, 'Jó', 'Jó', 'OT', 18, 42),
(19, 'Salmos', 'Sl', 'OT', 19, 150),
(20, 'Provérbios', 'Pv', 'OT', 20, 31),
(21, 'Eclesiastes', 'Ec', 'OT', 21, 12),
(22, 'Cânticos', 'Ct', 'OT', 22, 8),
(23, 'Isaías', 'Is', 'OT', 23, 66),
(24, 'Jeremias', 'Jr', 'OT', 24, 52),
(25, 'Lamentações', 'Lm', 'OT', 25, 5),
(26, 'Ezequiel', 'Ez', 'OT', 26, 48),
(27, 'Daniel', 'Dn', 'OT', 27, 12),
(28, 'Oséias', 'Os', 'OT', 28, 14),
(29, 'Joel', 'Jl', 'OT', 29, 3),
(30, 'Amós', 'Am', 'OT', 30, 9),
(31, 'Obadias', 'Ob', 'OT', 31, 1),
(32, 'Jonas', 'Jn', 'OT', 32, 4),
(33, 'Miquéias', 'Mq', 'OT', 33, 7),
(34, 'Naum', 'Na', 'OT', 34, 3),
(35, 'Habacuque', 'Hc', 'OT', 35, 3),
(36, 'Sofonias', 'Sf', 'OT', 36, 3),
(37, 'Ageu', 'Ag', 'OT', 37, 2),
(38, 'Zacarias', 'Zc', 'OT', 38, 14),
(39, 'Malaquias', 'Ml', 'OT', 39, 4),

-- NOVO TESTAMENTO
(40, 'Mateus', 'Mt', 'NT', 40, 28),
(41, 'Marcos', 'Mc', 'NT', 41, 16),
(42, 'Lucas', 'Lc', 'NT', 42, 24),
(43, 'João', 'Jo', 'NT', 43, 21),
(44, 'Atos', 'At', 'NT', 44, 28),
(45, 'Romanos', 'Rm', 'NT', 45, 16),
(46, '1 Coríntios', '1Co', 'NT', 46, 16),
(47, '2 Coríntios', '2Co', 'NT', 47, 13),
(48, 'Gálatas', 'Gl', 'NT', 48, 6),
(49, 'Efésios', 'Ef', 'NT', 49, 6),
(50, 'Filipenses', 'Fp', 'NT', 50, 4),
(51, 'Colossenses', 'Cl', 'NT', 51, 4),
(52, '1 Tessalonicenses', '1Ts', 'NT', 52, 5),
(53, '2 Tessalonicenses', '2Ts', 'NT', 53, 3),
(54, '1 Timóteo', '1Tm', 'NT', 54, 6),
(55, '2 Timóteo', '2Tm', 'NT', 55, 4),
(56, 'Tito', 'Tt', 'NT', 56, 3),
(57, 'Filemom', 'Fm', 'NT', 57, 1),
(58, 'Hebreus', 'Hb', 'NT', 58, 13),
(59, 'Tiago', 'Tg', 'NT', 59, 5),
(60, '1 Pedro', '1Pe', 'NT', 60, 5),
(61, '2 Pedro', '2Pe', 'NT', 61, 3),
(62, '1 João', '1Jo', 'NT', 62, 5),
(63, '2 João', '2Jo', 'NT', 63, 1),
(64, '3 João', '3Jo', 'NT', 64, 1),
(65, 'Judas', 'Jd', 'NT', 65, 1),
(66, 'Apocalipse', 'Ap', 'NT', 66, 22)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- NOTA IMPORTANTE
-- =====================================================
-- Os versículos da Bíblia (31.105 versículos) serão importados
-- em um script separado devido ao tamanho do arquivo.
-- 
-- Para importar os versículos:
-- 1. Baixe o JSON da Bíblia ARC do repositório:
--    https://github.com/damarals/biblias/blob/master/inst/json/ARC.json
-- 
-- 2. Use um script Python/Node.js para converter o JSON em SQL
--    e importar para a tabela bible_verse
-- 
-- 3. Ou use a API do Supabase para importar os dados via código
-- =====================================================

