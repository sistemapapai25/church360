-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for member-documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload to member-documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update member-documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete from member-documents" ON storage.objects;

-- Criar políticas para member-documents

-- Leitura pública
CREATE POLICY "member_documents_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'member-documents');

-- Upload para usuários autenticados
CREATE POLICY "member_documents_authenticated_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'member-documents');

-- Atualização para usuários autenticados
CREATE POLICY "member_documents_authenticated_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'member-documents');

-- Exclusão para usuários autenticados
CREATE POLICY "member_documents_authenticated_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'member-documents');;
