-- =====================================================
-- POPULAR MINISTÉRIOS - 25 MINISTÉRIOS COMPLETOS
-- =====================================================
-- Este script pode ser executado múltiplas vezes
-- Ele deleta os ministérios existentes e recria todos

-- Deletar ministérios existentes (CASCADE deleta membros também)
DELETE FROM public.ministry;

-- =====================================================
-- INSERIR 25 MINISTÉRIOS COM ÍCONES ÚNICOS
-- =====================================================

-- ADORAÇÃO & ENSINO (6 ministérios)
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Louvor e Adoração', 'Ministério responsável pela música e adoração nos cultos e eventos da igreja.', 'music', '#E91E63', true),
('Intercessão', 'Ministério dedicado à oração e intercessão pela igreja, líderes e necessidades.', 'hands-praying', '#9C27B0', true),
('Ensino/Escola Bíblica', 'Ministério focado no ensino da Palavra de Deus através de aulas e estudos bíblicos.', 'book-bible', '#3F51B5', true),
('Discipulado', 'Ministério que acompanha novos convertidos e membros em seu crescimento espiritual.', 'people-arrows', '#2196F3', true),
('Teatro/Artes', 'Ministério que usa teatro, dramatizações e artes para comunicar o evangelho.', 'masks-theater', '#FF5722', true),
('Dança', 'Ministério de dança profética e coreografias para adoração.', 'person-running', '#FF9800', true);

-- EVANGELISMO & MISSÕES (4 ministérios)
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Evangelismo', 'Ministério focado em levar o evangelho às pessoas através de ações evangelísticas.', 'bullhorn', '#F44336', true),
('Missões', 'Ministério dedicado ao apoio e envio de missionários para outras regiões e países.', 'earth-americas', '#4CAF50', true),
('Visitação', 'Ministério que visita membros, enfermos e novos visitantes da igreja.', 'house-heart', '#00BCD4', true),
('Células/Grupos Pequenos', 'Ministério que coordena e apoia os grupos pequenos e células da igreja.', 'people-group', '#009688', true);

-- FAIXAS ETÁRIAS (2 ministérios)
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Crianças', 'Ministério dedicado ao ensino e cuidado das crianças da igreja.', 'child-reaching', '#FFC107', true),
('Terceira Idade', 'Ministério voltado para o cuidado e atividades com a melhor idade.', 'person-cane', '#795548', true);

-- GRUPOS ESPECÍFICOS (5 ministérios)
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Adolescentes', 'Ministério focado no desenvolvimento espiritual e social dos adolescentes.', 'user-graduate', '#FF6F00', true),
('Jovens', 'Ministério dedicado aos jovens da igreja, promovendo comunhão e crescimento.', 'users-between-lines', '#00E676', true),
('Casais', 'Ministério que fortalece os casamentos através de encontros e aconselhamento.', 'heart', '#E91E63', true),
('Homens', 'Ministério voltado para o desenvolvimento espiritual e liderança dos homens.', 'person', '#1976D2', true),
('Mulheres', 'Ministério dedicado ao fortalecimento espiritual e comunhão entre as mulheres.', 'person-dress', '#D81B60', true);

-- SERVIÇOS & APOIO (8 ministérios)
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Diaconia', 'Ministério de assistência social e apoio aos necessitados da igreja e comunidade.', 'hand-holding-heart', '#8BC34A', true),
('Recepção/Hospitalidade', 'Ministério responsável por receber e acolher visitantes e membros da igreja.', 'handshake', '#03A9F4', true),
('Mídia/Comunicação', 'Ministério que cuida da comunicação visual, redes sociais e transmissões.', 'video', '#673AB7', true),
('Aconselhamento', 'Ministério que oferece apoio e aconselhamento espiritual aos membros.', 'comments', '#607D8B', true),
('Segurança', 'Ministério responsável pela segurança e ordem durante os cultos e eventos.', 'shield-halved', '#455A64', true),
('Estacionamento', 'Ministério que organiza e auxilia no estacionamento da igreja.', 'car', '#546E7A', true),
('Limpeza/Manutenção', 'Ministério responsável pela limpeza e manutenção das instalações da igreja.', 'broom', '#78909C', true),
('Cozinha/Alimentação', 'Ministério que prepara e serve alimentos em eventos e confraternizações.', 'utensils', '#FF7043', true);

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

-- Contar ministérios criados
SELECT COUNT(*) as total_ministerios FROM public.ministry;

-- Listar todos os ministérios
SELECT name, icon, color, is_active FROM public.ministry ORDER BY name;

