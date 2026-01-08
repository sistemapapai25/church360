INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('agents.access.default', 'Acesso ao Agente Atendimento', 'Permite interagir com o agente de atendimento geral', 'agents', 'access', false),
('agents.access.kids', 'Acesso ao Agente Kids', 'Permite interagir com o agente do ministério infantil', 'agents', 'access', false),
('agents.access.media', 'Acesso ao Agente Mídia', 'Permite interagir com o agente de mídia e transmissões', 'agents', 'access', false),
('agents.access.financeiro', 'Acesso ao Agente Financeiro', 'Permite interagir com o agente financeiro', 'agents', 'access', false),
('agents.access.pastoral', 'Acesso ao Agente Pastoral', 'Permite interagir com o agente pastoral', 'agents', 'access', false),
('agents.access.moises', 'Acesso ao Agente Moisés', 'Permite interagir com o agente Moisés (Liderança)', 'agents', 'access', false),
('agents.access.biblia', 'Acesso ao Agente Bíblia', 'Permite interagir com o agente de estudos bíblicos', 'agents', 'access', false),
('agents.access.ebd', 'Acesso ao Agente EBD', 'Permite interagir com o agente da Escola Bíblica Dominical', 'agents', 'access', false),
('agents.access.jovens', 'Acesso ao Agente Jovens', 'Permite interagir com o agente de Jovens', 'agents', 'access', false)
ON CONFLICT (code) DO UPDATE SET
    category = EXCLUDED.category,
    subcategory = EXCLUDED.subcategory;
