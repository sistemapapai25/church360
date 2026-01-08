
-- Corrigir função para criar role padrão (visitante em vez de membro)
CREATE OR REPLACE FUNCTION public.handle_new_user_role()
RETURNS TRIGGER AS $$
BEGIN
  -- Inserir role padrão 'visitante' para novos usuários
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'visitante'::app_role)
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro mas não bloqueia a criação do usuário
    RAISE WARNING 'Erro ao criar role para usuário %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Garantir que o trigger existe e está ativo
DROP TRIGGER IF EXISTS on_auth_user_created_role ON auth.users;
CREATE TRIGGER on_auth_user_created_role
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_role();

-- Corrigir políticas RLS para permitir inserção automática de roles
DROP POLICY IF EXISTS "Sistema pode criar roles automáticos" ON public.user_roles;
CREATE POLICY "Sistema pode criar roles automáticos" 
  ON public.user_roles 
  FOR INSERT 
  WITH CHECK (true);

-- Permitir que o sistema atualize roles quando necessário
DROP POLICY IF EXISTS "Sistema pode atualizar roles" ON public.user_roles;
CREATE POLICY "Sistema pode atualizar roles" 
  ON public.user_roles 
  FOR UPDATE 
  USING (true);

-- Garantir que admins podem gerenciar todos os roles
DROP POLICY IF EXISTS "Admins podem gerenciar todos os roles" ON public.user_roles;
CREATE POLICY "Admins podem gerenciar todos os roles" 
  ON public.user_roles 
  FOR ALL 
  USING (public.has_role(auth.uid(), 'admin'));

-- Criar roles para usuários existentes que não têm
INSERT INTO public.user_roles (user_id, role)
SELECT u.id, 'visitante'::app_role
FROM auth.users u
LEFT JOIN public.user_roles ur ON u.id = ur.user_id
WHERE ur.user_id IS NULL
ON CONFLICT (user_id, role) DO NOTHING;
;
