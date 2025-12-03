-- ============================================
-- FIX: RLS Policies para Custom Reports
-- ============================================
-- SOLUÇÃO DEFINITIVA: Policies simples sem recursão

-- Dropar TODAS as policies antigas
DROP POLICY IF EXISTS "custom_report_select_policy" ON custom_report;
DROP POLICY IF EXISTS "custom_report_insert_policy" ON custom_report;
DROP POLICY IF EXISTS "custom_report_update_policy" ON custom_report;
DROP POLICY IF EXISTS "custom_report_delete_policy" ON custom_report;
DROP POLICY IF EXISTS "custom_report_select_simple" ON custom_report;
DROP POLICY IF EXISTS "custom_report_insert_simple" ON custom_report;
DROP POLICY IF EXISTS "custom_report_update_simple" ON custom_report;
DROP POLICY IF EXISTS "custom_report_delete_simple" ON custom_report;

DROP POLICY IF EXISTS "custom_report_permission_select_policy" ON custom_report_permission;
DROP POLICY IF EXISTS "custom_report_permission_insert_policy" ON custom_report_permission;
DROP POLICY IF EXISTS "custom_report_permission_update_policy" ON custom_report_permission;
DROP POLICY IF EXISTS "custom_report_permission_delete_policy" ON custom_report_permission;

-- Desabilitar RLS em custom_report_permission (evita recursão)
ALTER TABLE custom_report_permission DISABLE ROW LEVEL SECURITY;

-- ============================================
-- CUSTOM_REPORT POLICIES (ULTRA-SIMPLES)
-- ============================================
-- Não verifica custom_report_permission para evitar recursão
-- A lógica de compartilhamento será feita no código Dart

-- SELECT: Ver apenas relatórios próprios OU se for admin
CREATE POLICY "custom_report_select_simple" ON custom_report
FOR SELECT
USING (
  created_by = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM user_account
    WHERE user_account.id = auth.uid()
    AND user_account.role_global IN ('admin', 'owner')
  )
);

-- INSERT: Qualquer usuário autenticado pode criar
CREATE POLICY "custom_report_insert_simple" ON custom_report
FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL
  AND created_by = auth.uid()
);

-- UPDATE: Apenas criador ou admin
CREATE POLICY "custom_report_update_simple" ON custom_report
FOR UPDATE
USING (
  created_by = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM user_account
    WHERE user_account.id = auth.uid()
    AND user_account.role_global IN ('admin', 'owner')
  )
);

-- DELETE: Apenas criador ou admin
CREATE POLICY "custom_report_delete_simple" ON custom_report
FOR DELETE
USING (
  created_by = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM user_account
    WHERE user_account.id = auth.uid()
    AND user_account.role_global IN ('admin', 'owner')
  )
);

-- ============================================
-- CUSTOM_REPORT_PERMISSION
-- ============================================
-- RLS DESABILITADO para evitar recursão infinita
-- A segurança será gerenciada pelo código Dart

-- Nota: RLS foi desabilitado com:
-- ALTER TABLE custom_report_permission DISABLE ROW LEVEL SECURITY;

-- ============================================
-- SUCESSO!
-- ============================================
-- ✅ Policies ultra-simples sem recursão
-- ✅ RLS desabilitado em custom_report_permission
-- ✅ Lógica de compartilhamento será no código Dart

