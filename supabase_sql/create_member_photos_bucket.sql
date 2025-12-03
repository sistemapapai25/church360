-- =====================================================
-- CRIAR BUCKET PARA FOTOS DE MEMBROS
-- =====================================================
-- Este script cria o bucket 'member-photos' no Supabase Storage
-- para armazenar as fotos de perfil dos membros.
-- =====================================================

-- Criar bucket 'member-photos' (público para leitura)
INSERT INTO storage.buckets (id, name, public)
VALUES ('member-photos', 'member-photos', true)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- POLÍTICAS DE SEGURANÇA (RLS)
-- =====================================================

-- Permitir que usuários autenticados façam upload de fotos
CREATE POLICY "Usuários autenticados podem fazer upload de fotos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'member-photos');

-- Permitir que usuários autenticados atualizem suas próprias fotos
CREATE POLICY "Usuários autenticados podem atualizar fotos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'member-photos');

-- Permitir que todos vejam as fotos (bucket público)
CREATE POLICY "Todos podem ver fotos de membros"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'member-photos');

-- Permitir que usuários autenticados deletem fotos
CREATE POLICY "Usuários autenticados podem deletar fotos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'member-photos');

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

-- Verificar se o bucket foi criado
SELECT * FROM storage.buckets WHERE id = 'member-photos';

-- Verificar políticas
SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%member%';

