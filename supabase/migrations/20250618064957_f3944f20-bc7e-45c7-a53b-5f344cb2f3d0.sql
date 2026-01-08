
-- Adicionar role padrão 'visitante' para novos usuários
INSERT INTO public.user_roles (user_id, role)
SELECT u.id, 'membro'::app_role
FROM auth.users u
LEFT JOIN public.user_roles ur ON u.id = ur.user_id
WHERE ur.user_id IS NULL;

-- Função para criar role padrão ao cadastrar usuário
CREATE OR REPLACE FUNCTION public.handle_new_user_role()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'membro'::app_role);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para criar role automático
DROP TRIGGER IF EXISTS on_auth_user_created_role ON auth.users;
CREATE TRIGGER on_auth_user_created_role
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_role();

-- Atualizar políticas RLS para user_roles
DROP POLICY IF EXISTS "Admins e pastores podem ver todos os roles" ON public.user_roles;
DROP POLICY IF EXISTS "Usuários podem ver seus próprios roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins podem gerenciar roles" ON public.user_roles;

CREATE POLICY "Admins e pastores podem ver todos os roles" 
  ON public.user_roles 
  FOR SELECT 
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Usuários podem ver seus próprios roles" 
  ON public.user_roles 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Admins podem gerenciar roles" 
  ON public.user_roles 
  FOR ALL 
  USING (public.has_role(auth.uid(), 'admin'));

-- Adicionar políticas para profiles permitindo admins verem todos
DROP POLICY IF EXISTS "Admins podem ver todos os perfis" ON public.profiles;
CREATE POLICY "Admins podem ver todos os perfis" 
  ON public.profiles 
  FOR SELECT 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Permitir admins editarem perfis
DROP POLICY IF EXISTS "Admins podem editar perfis" ON public.profiles;
CREATE POLICY "Admins podem editar perfis" 
  ON public.profiles 
  FOR UPDATE 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Permitir admins criarem perfis
DROP POLICY IF EXISTS "Admins podem criar perfis" ON public.profiles;
CREATE POLICY "Admins podem criar perfis" 
  ON public.profiles 
  FOR INSERT 
  WITH CHECK (public.is_admin_or_pastor(auth.uid()));
;
