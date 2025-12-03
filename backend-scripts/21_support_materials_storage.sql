-- =====================================================
-- SCRIPT 21: SUPABASE STORAGE BUCKETS FOR SUPPORT MATERIALS
-- =====================================================
-- Descrição: Cria buckets de armazenamento para arquivos e vídeos de materiais de apoio
-- Data: 2025-10-22
-- =====================================================

-- Criar bucket para arquivos de materiais (PDF, PowerPoint, etc.)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'support-material-files',
  'support-material-files',
  true,
  52428800, -- 50MB
  ARRAY[
    'application/pdf',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'application/zip',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/mp4'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Criar bucket para vídeos de materiais
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'support-material-videos',
  'support-material-videos',
  true,
  524288000, -- 500MB
  ARRAY[
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- POLÍTICAS DE ACESSO AOS BUCKETS
-- =====================================================

-- Política para permitir upload de arquivos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can upload support material files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'support-material-files');

-- Política para permitir leitura pública de arquivos
CREATE POLICY "Public can view support material files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'support-material-files');

-- Política para permitir atualização de arquivos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can update support material files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'support-material-files');

-- Política para permitir exclusão de arquivos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can delete support material files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'support-material-files');

-- Política para permitir upload de vídeos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can upload support material videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'support-material-videos');

-- Política para permitir leitura pública de vídeos
CREATE POLICY "Public can view support material videos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'support-material-videos');

-- Política para permitir atualização de vídeos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can update support material videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'support-material-videos');

-- Política para permitir exclusão de vídeos (apenas usuários autenticados)
CREATE POLICY "Authenticated users can delete support material videos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'support-material-videos');

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

