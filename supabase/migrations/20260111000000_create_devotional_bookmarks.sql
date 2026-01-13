CREATE TABLE IF NOT EXISTS public.devotional_bookmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  devotional_id uuid NOT NULL REFERENCES public.devotionals(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenant(id) ON DELETE CASCADE DEFAULT public.current_tenant_id(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT devotional_bookmarks_unique UNIQUE (tenant_id, devotional_id, user_id)
);

ALTER TABLE public.devotional_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS devotional_bookmarks_select_own_in_tenant ON public.devotional_bookmarks;
CREATE POLICY devotional_bookmarks_select_own_in_tenant
ON public.devotional_bookmarks
FOR SELECT
TO authenticated
USING (
  tenant_id = public.current_tenant_id()
  AND user_id = auth.uid()
);

DROP POLICY IF EXISTS devotional_bookmarks_insert_own_in_tenant ON public.devotional_bookmarks;
CREATE POLICY devotional_bookmarks_insert_own_in_tenant
ON public.devotional_bookmarks
FOR INSERT
TO authenticated
WITH CHECK (
  tenant_id = public.current_tenant_id()
  AND user_id = auth.uid()
);

DROP POLICY IF EXISTS devotional_bookmarks_update_own_in_tenant ON public.devotional_bookmarks;
CREATE POLICY devotional_bookmarks_update_own_in_tenant
ON public.devotional_bookmarks
FOR UPDATE
TO authenticated
USING (
  tenant_id = public.current_tenant_id()
  AND user_id = auth.uid()
)
WITH CHECK (
  tenant_id = public.current_tenant_id()
  AND user_id = auth.uid()
);

DROP POLICY IF EXISTS devotional_bookmarks_delete_own_in_tenant ON public.devotional_bookmarks;
CREATE POLICY devotional_bookmarks_delete_own_in_tenant
ON public.devotional_bookmarks
FOR DELETE
TO authenticated
USING (
  tenant_id = public.current_tenant_id()
  AND user_id = auth.uid()
);

CREATE INDEX IF NOT EXISTS idx_devotional_bookmarks_tenant_id ON public.devotional_bookmarks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_devotional_bookmarks_user_id ON public.devotional_bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_devotional_bookmarks_devotional_id ON public.devotional_bookmarks(devotional_id);
