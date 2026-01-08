
-- Criar tabela para templates de certificados
CREATE TABLE public.certificados_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  tipo TEXT NOT NULL CHECK (tipo IN ('curso', 'evento', 'participacao', 'workshop', 'conferencia', 'ministerio', 'outro')),
  layout_config JSONB NOT NULL DEFAULT '{}',
  campos_personalizaveis TEXT[] DEFAULT ARRAY['nome', 'curso', 'data', 'carga_horaria'],
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_por UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para certificados emitidos
CREATE TABLE public.certificados_emitidos (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  template_id UUID REFERENCES public.certificados_templates(id) ON DELETE RESTRICT NOT NULL,
  user_id UUID NOT NULL,
  codigo_verificacao TEXT NOT NULL UNIQUE,
  dados_certificado JSONB NOT NULL,
  evento_id UUID REFERENCES public.eventos(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'revogado', 'expirado')),
  data_emissao TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  data_expiracao TIMESTAMP WITH TIME ZONE,
  url_pdf TEXT,
  emitido_por UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para validações de certificados
CREATE TABLE public.certificado_validacoes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  certificado_id UUID REFERENCES public.certificados_emitidos(id) ON DELETE CASCADE NOT NULL,
  codigo_verificacao TEXT NOT NULL,
  ip_origem TEXT,
  user_agent TEXT,
  resultado TEXT NOT NULL CHECK (resultado IN ('valido', 'invalido', 'expirado', 'revogado')),
  detalhes_validacao JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS nas novas tabelas
ALTER TABLE public.certificados_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificados_emitidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificado_validacoes ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para certificados_templates
CREATE POLICY "Todos podem visualizar templates ativos"
  ON public.certificados_templates
  FOR SELECT
  TO authenticated
  USING (ativo = true);

CREATE POLICY "Admins e pastores podem gerenciar templates"
  ON public.certificados_templates
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para certificados_emitidos
CREATE POLICY "Usuários podem ver seus próprios certificados"
  ON public.certificados_emitidos
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins e pastores podem visualizar todos os certificados"
  ON public.certificados_emitidos
  FOR SELECT
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Admins e pastores podem inserir certificados"
  ON public.certificados_emitidos
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Admins e pastores podem atualizar certificados"
  ON public.certificados_emitidos
  FOR UPDATE
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Admins e pastores podem deletar certificados"
  ON public.certificados_emitidos
  FOR DELETE
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Política para validação pública (sem autenticação)
CREATE POLICY "Validação pública de certificados"
  ON public.certificados_emitidos
  FOR SELECT
  TO public
  USING (status = 'ativo');

-- Políticas RLS para certificado_validacoes
CREATE POLICY "Admins podem visualizar validações"
  ON public.certificado_validacoes
  FOR SELECT
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Permitir inserção de validações"
  ON public.certificado_validacoes
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Função para gerar código de verificação único
CREATE OR REPLACE FUNCTION public.gerar_codigo_verificacao()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  codigo TEXT;
BEGIN
  LOOP
    codigo := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 12));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.certificados_emitidos WHERE codigo_verificacao = codigo);
  END LOOP;
  RETURN codigo;
END;
$$;

-- Triggers para updated_at
CREATE TRIGGER handle_certificados_templates_updated_at
  BEFORE UPDATE ON public.certificados_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_certificados_emitidos_updated_at
  BEFORE UPDATE ON public.certificados_emitidos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Inserir templates padrão
INSERT INTO public.certificados_templates (nome, descricao, tipo, layout_config, campos_personalizaveis) VALUES
('Certificado de Participação em Evento', 'Template padrão para certificados de participação em eventos da igreja', 'evento', 
 '{"background": "#ffffff", "primaryColor": "#7c3aed", "secondaryColor": "#4f46e5", "fontFamily": "Arial", "fontSize": 14}',
 ARRAY['nome', 'evento', 'data', 'local']),
('Certificado de Conclusão de Curso', 'Template para certificados de cursos e workshops', 'curso',
 '{"background": "#ffffff", "primaryColor": "#059669", "secondaryColor": "#047857", "fontFamily": "Times New Roman", "fontSize": 14}',
 ARRAY['nome', 'curso', 'data', 'carga_horaria', 'instrutor']),
('Certificado de Ministério', 'Template para certificados de participação em ministérios', 'ministerio',
 '{"background": "#ffffff", "primaryColor": "#dc2626", "secondaryColor": "#991b1b", "fontFamily": "Arial", "fontSize": 14}',
 ARRAY['nome', 'ministerio', 'periodo', 'responsavel']);

-- Criar índices para performance
CREATE INDEX idx_certificados_emitidos_user_id ON public.certificados_emitidos(user_id);
CREATE INDEX idx_certificados_emitidos_codigo ON public.certificados_emitidos(codigo_verificacao);
CREATE INDEX idx_certificados_emitidos_evento_id ON public.certificados_emitidos(evento_id);
CREATE INDEX idx_certificado_validacoes_certificado_id ON public.certificado_validacoes(certificado_id);
CREATE INDEX idx_certificado_validacoes_codigo ON public.certificado_validacoes(codigo_verificacao);
;
