
-- Atualizar a função para criar role padrão 'visitante' ao cadastrar usuário
CREATE OR REPLACE FUNCTION public.handle_new_user_role()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'visitante'::app_role);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar usuários existentes que têm role 'membro' para 'visitante' se necessário
-- (apenas se for o único role que possuem)
UPDATE public.user_roles 
SET role = 'visitante'::app_role 
WHERE role = 'membro'::app_role 
AND user_id NOT IN (
  SELECT user_id FROM public.user_roles 
  WHERE role IN ('admin', 'pastor', 'lider', 'diacono')
);
;
