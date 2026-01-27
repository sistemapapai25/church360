INSERT INTO storage.buckets (id, name, public)
VALUES
  ('boletos', 'boletos', false),
  ('comprovantes', 'comprovantes', false),
  ('assinaturas', 'assinaturas', false),
  ('logos', 'logos', false)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public;

DROP POLICY IF EXISTS financial_storage_select ON storage.objects;
DROP POLICY IF EXISTS financial_storage_insert ON storage.objects;
DROP POLICY IF EXISTS financial_storage_update ON storage.objects;
DROP POLICY IF EXISTS financial_storage_delete ON storage.objects;

CREATE POLICY financial_storage_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = ANY (ARRAY['boletos', 'comprovantes', 'assinaturas', 'logos'])
  AND public.current_tenant_id() IS NOT NULL
  AND path_tokens[1] = public.current_tenant_id()::text
  AND public.can_manage_financial(auth.uid(), public.current_tenant_id())
);

CREATE POLICY financial_storage_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = ANY (ARRAY['boletos', 'comprovantes', 'assinaturas', 'logos'])
  AND public.current_tenant_id() IS NOT NULL
  AND path_tokens[1] = public.current_tenant_id()::text
  AND public.can_manage_financial(auth.uid(), public.current_tenant_id())
);

CREATE POLICY financial_storage_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = ANY (ARRAY['boletos', 'comprovantes', 'assinaturas', 'logos'])
  AND public.current_tenant_id() IS NOT NULL
  AND path_tokens[1] = public.current_tenant_id()::text
  AND public.can_manage_financial(auth.uid(), public.current_tenant_id())
)
WITH CHECK (
  bucket_id = ANY (ARRAY['boletos', 'comprovantes', 'assinaturas', 'logos'])
  AND public.current_tenant_id() IS NOT NULL
  AND path_tokens[1] = public.current_tenant_id()::text
  AND public.can_manage_financial(auth.uid(), public.current_tenant_id())
);

CREATE POLICY financial_storage_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = ANY (ARRAY['boletos', 'comprovantes', 'assinaturas', 'logos'])
  AND public.current_tenant_id() IS NOT NULL
  AND path_tokens[1] = public.current_tenant_id()::text
  AND public.can_manage_financial(auth.uid(), public.current_tenant_id())
);
