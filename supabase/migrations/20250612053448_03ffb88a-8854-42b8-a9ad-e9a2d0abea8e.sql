
-- Criar tabela de perfis dos usuários
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  nome TEXT NOT NULL,
  sobrenome TEXT NOT NULL,
  apelido TEXT,
  cpf TEXT UNIQUE,
  celular TEXT,
  data_nascimento DATE,
  estado_civil TEXT CHECK (estado_civil IN ('Solteiro', 'Casado', 'Divorciado', 'Amasiado', 'Viúvo')),
  cep TEXT,
  rua TEXT,
  numero TEXT,
  complemento TEXT,
  bairro TEXT,
  cidade TEXT,
  estado TEXT,
  profile_completion_percentage INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Política para usuários verem apenas seu próprio perfil
CREATE POLICY "Users can view their own profile" 
  ON public.profiles 
  FOR SELECT 
  USING (auth.uid() = user_id);

-- Política para usuários criarem seu próprio perfil
CREATE POLICY "Users can create their own profile" 
  ON public.profiles 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Política para usuários atualizarem seu próprio perfil
CREATE POLICY "Users can update their own profile" 
  ON public.profiles 
  FOR UPDATE 
  USING (auth.uid() = user_id);

-- Função para atualizar timestamp de updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar timestamp automaticamente
CREATE TRIGGER handle_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Função para calcular porcentagem de preenchimento do perfil
CREATE OR REPLACE FUNCTION public.calculate_profile_completion(profile_row public.profiles)
RETURNS INTEGER AS $$
DECLARE
  total_fields INTEGER := 13; -- total de campos importantes
  filled_fields INTEGER := 0;
BEGIN
  -- Contar campos preenchidos
  IF profile_row.nome IS NOT NULL AND profile_row.nome != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.sobrenome IS NOT NULL AND profile_row.sobrenome != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.cpf IS NOT NULL AND profile_row.cpf != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.celular IS NOT NULL AND profile_row.celular != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.data_nascimento IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.estado_civil IS NOT NULL AND profile_row.estado_civil != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.cep IS NOT NULL AND profile_row.cep != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.rua IS NOT NULL AND profile_row.rua != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.numero IS NOT NULL AND profile_row.numero != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.bairro IS NOT NULL AND profile_row.bairro != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.cidade IS NOT NULL AND profile_row.cidade != '' THEN filled_fields := filled_fields + 1; END IF;
  IF profile_row.estado IS NOT NULL AND profile_row.estado != '' THEN filled_fields := filled_fields + 1; END IF;
  -- apelido e complemento são opcionais, mas contam se preenchidos
  IF profile_row.apelido IS NOT NULL AND profile_row.apelido != '' THEN filled_fields := filled_fields + 1; END IF;
  
  -- Calcular porcentagem (ajustar total se campos opcionais preenchidos)
  IF profile_row.apelido IS NOT NULL AND profile_row.apelido != '' THEN
    total_fields := total_fields + 1;
  END IF;
  
  RETURN ROUND((filled_fields::FLOAT / total_fields::FLOAT) * 100);
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar automaticamente a porcentagem de preenchimento
CREATE OR REPLACE FUNCTION public.update_profile_completion()
RETURNS TRIGGER AS $$
BEGIN
  NEW.profile_completion_percentage := public.calculate_profile_completion(NEW);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profile_completion_trigger
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_profile_completion();
;
