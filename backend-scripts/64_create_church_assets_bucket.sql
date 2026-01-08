-- =====================================================
-- SCRIPT 64: SUPABASE STORAGE BUCKET FOR CHURCH ASSETS
-- =====================================================
-- Descrição: Cria bucket de armazenamento para assets da igreja (logo, etc.)
-- Data: 2025-12-20
-- =====================================================

-- Criar bucket para assets da igreja
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'church-assets',
  'church-assets',
  true,
  10485760, -- 10MB
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- POLÍTICAS DE ACESSO AO BUCKET
-- =====================================================

-- Drop existing policies if any to avoid conflicts during re-runs
DROP POLICY IF EXISTS "Authenticated users can upload church assets" ON storage.objects;
DROP POLICY IF EXISTS "Public can view church assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update church assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete church assets" ON storage.objects;

-- Política para permitir upload de arquivos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can upload church assets"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'church-assets');

-- Política para permitir leitura pública de arquivos
CREATE POLICY "Public can view church assets"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'church-assets');

-- Política para permitir atualização de arquivos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can update church assets"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'church-assets');

-- Política para permitir exclusão de arquivos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can delete church assets"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'church-assets');
