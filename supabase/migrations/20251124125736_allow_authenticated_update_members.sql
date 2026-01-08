-- Criar política para permitir que usuários autenticados atualizem membros
-- (assumindo que apenas administradores/staff terão acesso ao sistema)
CREATE POLICY "authenticated_can_update_members"
ON user_account
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Comentário: Esta política permite que qualquer usuário autenticado atualize membros.
-- Se você quiser restringir apenas para administradores, você pode modificar para:
-- USING (EXISTS (SELECT 1 FROM user_account WHERE id = auth.uid() AND role_global IN ('admin', 'staff')))
-- WITH CHECK (EXISTS (SELECT 1 FROM user_account WHERE id = auth.uid() AND role_global IN ('admin', 'staff')));;
