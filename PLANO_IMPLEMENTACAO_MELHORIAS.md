# 🚀 PLANO DE IMPLEMENTAÇÃO - MELHORIAS DO BERG NO CHURCH 360

## 📋 **VISÃO GERAL**

Este documento detalha o plano para implementar as melhores funcionalidades do sistema Berg no Church 360 Gabriel.

---

## 🎯 **FASES DE IMPLEMENTAÇÃO**

### **FASE 1: FUNDAÇÃO** (Prioridade ALTA - 2-3 semanas)

#### **1.1 Sistema de Profissões** ⭐⭐⭐⭐⭐
**Complexidade**: Baixa | **Valor**: Alto | **Tempo**: 2 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.profession (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  category TEXT, -- Ex: "Saúde", "Educação", "Tecnologia"
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Popular com 220 profissões do Berg
INSERT INTO public.profession (name, category) VALUES
('Administração', 'Gestão'),
('Medicina', 'Saúde'),
('Engenharia Civil', 'Engenharia'),
-- ... (220 profissões)
```

**Flutter:**
- Model: `Profession`
- Repository: `ProfessionRepository`
- Provider: `professionsProvider`
- Widget: `ProfessionDropdown`

**Alteração na tabela member:**
```sql
ALTER TABLE public.member 
ADD COLUMN profession_id UUID REFERENCES public.profession(id);
```

---

#### **1.2 Relacionamentos Familiares** ⭐⭐⭐⭐⭐
**Complexidade**: Média | **Valor**: Muito Alto | **Tempo**: 5 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.family_relationship (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  relative_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  relationship_type TEXT NOT NULL, -- 'pai', 'mae', 'filho', 'filha', 'conjuge', 'irmao', 'irma', 'avo', 'ava', 'neto', 'neta', 'tutor'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, relative_id, relationship_type)
);

CREATE INDEX idx_family_member ON public.family_relationship(member_id);
CREATE INDEX idx_family_relative ON public.family_relationship(relative_id);
```

**Flutter:**
- Model: `FamilyRelationship`
- Repository: `FamilyRelationshipRepository`
- Providers:
  - `familyMembersProvider(memberId)` - Retorna família do membro
  - `familyTreeProvider(memberId)` - Retorna árvore genealógica
- Screens:
  - `family_tree_screen.dart` - Visualização da árvore familiar
  - `add_relationship_screen.dart` - Adicionar relacionamento
- Widgets:
  - `FamilyMemberCard` - Card de membro da família
  - `RelationshipBadge` - Badge do tipo de relacionamento

**Funcionalidades:**
- ✅ Adicionar relacionamento
- ✅ Remover relacionamento
- ✅ Visualizar árvore familiar
- ✅ Buscar parentes
- ✅ Validação de relacionamentos (não permitir duplicatas)

---

#### **1.3 Áreas dentro de Ministérios** ⭐⭐⭐⭐
**Complexidade**: Média | **Valor**: Alto | **Tempo**: 3 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.ministry_area (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ministry_id UUID NOT NULL REFERENCES public.ministry(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  leader1_id UUID REFERENCES public.member(id) ON DELETE SET NULL,
  leader2_id UUID REFERENCES public.member(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ministry_area_ministry ON public.ministry_area(ministry_id);
```

**Exemplos de Áreas:**
- Louvor → Louvor Domingo Manhã, Louvor Domingo Noite, Ensaios
- Infantil → Berçário, Maternal, Jardim, Primários
- Jovens → Teens, Jovens, Universitários

**Flutter:**
- Model: `MinistryArea`
- Repository: Adicionar métodos em `MinistriesRepository`
- Providers:
  - `ministryAreasProvider(ministryId)`
  - `areaByIdProvider(areaId)`
- Screens:
  - Adicionar lista de áreas em `ministry_detail_screen.dart`
  - `ministry_area_form_screen.dart` - Criar/editar área

---

### **FASE 2: DONS ESPIRITUAIS** (Prioridade ALTA - 2 semanas)

#### **2.1 Sistema de Dons** ⭐⭐⭐⭐⭐
**Complexidade**: Alta | **Valor**: Muito Alto | **Tempo**: 10 dias

**Banco de Dados:**
```sql
-- Tabela de Dons
CREATE TABLE IF NOT EXISTS public.spiritual_gift (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE, -- 'A', 'B', 'C', etc.
  name TEXT NOT NULL, -- 'Profecia', 'Serviço', etc.
  description TEXT,
  biblical_reference TEXT, -- Referências bíblicas
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de Frases para Avaliação
CREATE TABLE IF NOT EXISTS public.gift_question (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_id UUID NOT NULL REFERENCES public.spiritual_gift(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  order_number INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de Respostas dos Membros
CREATE TABLE IF NOT EXISTS public.gift_answer (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.gift_question(id) ON DELETE CASCADE,
  score INTEGER NOT NULL CHECK (score >= 0 AND score <= 5), -- 0 a 5
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, question_id)
);

-- Tabela de Resultados
CREATE TABLE IF NOT EXISTS public.gift_result (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  gift_id UUID NOT NULL REFERENCES public.spiritual_gift(id) ON DELETE CASCADE,
  total_score INTEGER NOT NULL,
  percentage DECIMAL(5,2),
  rank INTEGER, -- 1º, 2º, 3º dom
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, gift_id)
);
```

**9 Dons Espirituais:**
1. **Profecia** (A) - Romanos 12:6
2. **Serviço** (B) - Romanos 12:7
3. **Ensino** (C) - Romanos 12:7
4. **Exortação** (D) - Romanos 12:8
5. **Contribuição** (E) - Romanos 12:8
6. **Governo** (F) - Romanos 12:8
7. **Misericórdia** (G) - Romanos 12:8
8. **Evangelista** (H) - Efésios 4:11
9. **Pastor** (I) - Efésios 4:11

**Flutter:**
- Models: `SpiritualGift`, `GiftQuestion`, `GiftAnswer`, `GiftResult`
- Repository: `SpiritualGiftsRepository`
- Providers:
  - `spiritualGiftsProvider`
  - `giftQuestionsProvider`
  - `memberGiftResultsProvider(memberId)`
- Screens:
  - `gifts_assessment_screen.dart` - Tela de avaliação
  - `gifts_results_screen.dart` - Resultados do membro
  - `gifts_info_screen.dart` - Informações sobre dons
- Widgets:
  - `GiftQuestionCard` - Card de pergunta
  - `GiftScoreSlider` - Slider de 0 a 5
  - `GiftResultChart` - Gráfico de resultados
  - `GiftBadge` - Badge do dom

**Funcionalidades:**
- ✅ Questionário de 45-90 perguntas (5-10 por dom)
- ✅ Escala de 0 a 5 para cada pergunta
- ✅ Cálculo automático de resultados
- ✅ Ranking dos 3 principais dons
- ✅ Gráfico visual dos resultados
- ✅ Descrição detalhada de cada dom
- ✅ Sugestões de ministérios baseadas nos dons

---

### **FASE 3: SISTEMA DE ENSINO** (Prioridade MÉDIA - 2 semanas)

#### **3.1 Salas** ⭐⭐⭐⭐
**Complexidade**: Baixa | **Valor**: Médio | **Tempo**: 2 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.room (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  capacity INTEGER,
  location TEXT,
  resources TEXT, -- Ex: "Projetor, Quadro, Ar condicionado"
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

#### **3.2 Turmas** ⭐⭐⭐⭐
**Complexidade**: Média | **Valor**: Alto | **Tempo**: 3 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.class (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  ministry_id UUID REFERENCES public.ministry(id) ON DELETE SET NULL,
  age_range TEXT, -- Ex: "3-5 anos", "6-8 anos"
  teacher_id UUID REFERENCES public.member(id) ON DELETE SET NULL,
  room_id UUID REFERENCES public.room(id) ON DELETE SET NULL,
  schedule TEXT, -- Ex: "Domingo 9h"
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Membros da turma
CREATE TABLE IF NOT EXISTS public.class_member (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.class(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'Aluno', -- 'Professor', 'Auxiliar', 'Aluno'
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(class_id, member_id)
);
```

---

#### **3.3 Aulas** ⭐⭐⭐⭐⭐
**Complexidade**: Alta | **Valor**: Muito Alto | **Tempo**: 5 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.lesson (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.class(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  biblical_theme TEXT, -- Ex: "Velho Testamento", "Novo Testamento"
  lesson_date DATE NOT NULL,
  age_range TEXT,
  teacher_id UUID REFERENCES public.member(id) ON DELETE SET NULL,
  objective TEXT,
  key_verse TEXT, -- Versículo-chave
  summary TEXT,
  planned_activity TEXT,
  required_materials TEXT,
  status TEXT DEFAULT 'Planejada', -- 'Planejada', 'Em andamento', 'Concluída', 'Cancelada'
  post_lesson_notes TEXT,
  material_file TEXT, -- URL do arquivo
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Presença nas aulas
CREATE TABLE IF NOT EXISTS public.lesson_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES public.lesson(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  present BOOLEAN DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(lesson_id, member_id)
);
```

**Flutter:**
- Models: `Room`, `Class`, `ClassMember`, `Lesson`, `LessonAttendance`
- Repositories: `RoomRepository`, `ClassRepository`, `LessonRepository`
- Screens:
  - `rooms_screen.dart` - Lista de salas
  - `classes_screen.dart` - Lista de turmas
  - `class_detail_screen.dart` - Detalhes da turma
  - `lessons_screen.dart` - Lista de aulas
  - `lesson_form_screen.dart` - Criar/editar aula
  - `lesson_detail_screen.dart` - Detalhes da aula
  - `attendance_screen.dart` - Chamada de presença

---

### **FASE 4: FUNÇÕES E PERMISSÕES** (Prioridade MÉDIA - 1 semana)

#### **4.1 Funções Específicas** ⭐⭐⭐⭐
**Complexidade**: Média | **Valor**: Alto | **Tempo**: 3 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.ministry_function (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  requires_skill BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Funções dos membros
CREATE TABLE IF NOT EXISTS public.member_function (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  function_id UUID NOT NULL REFERENCES public.ministry_function(id) ON DELETE CASCADE,
  ministry_id UUID REFERENCES public.ministry(id) ON DELETE SET NULL,
  skill_level INTEGER CHECK (skill_level >= 1 AND skill_level <= 5), -- 1 a 5
  certified BOOLEAN DEFAULT false,
  certification_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, function_id, ministry_id)
);
```

**22 Funções Pré-definidas:**
- Vocal Principal
- Backing Vocal
- Tecladista
- Guitarrista
- Baixista
- Baterista
- Técnico de Som
- Professor Principal
- Auxiliar de Turma
- Recepcionista
- Coordenador de Atividades
- Limpeza Geral
- Organização de Cadeiras
- Recepção
- Segurança
- Portaria
- etc.

---

#### **4.2 Sistema de Permissões** ⭐⭐⭐⭐
**Complexidade**: Média | **Valor**: Alto | **Tempo**: 2 dias

**Banco de Dados:**
```sql
CREATE TYPE permission_level AS ENUM ('USR', 'OPE', 'MTR', 'ADM');

ALTER TABLE public.member 
ADD COLUMN permission_level permission_level DEFAULT 'USR';

-- USR: Usuário comum (visualizar)
-- OPE: Operador (criar/editar conteúdo)
-- MTR: Mestre/Pastor (gerenciar ministérios)
-- ADM: Administrador (acesso total)
```

**Flutter:**
- Enum: `PermissionLevel`
- Middleware: `PermissionGuard`
- Widgets:
  - `PermissionGate` - Exibe conteúdo baseado em permissão
  - `AdminOnlyRoute` - Rota apenas para admins
  - `LeaderOnlyRoute` - Rota apenas para líderes

---

### **FASE 5: SEGURANÇA INFANTIL** (Prioridade BAIXA - 3 dias)

#### **5.1 Restrições Kids** ⭐⭐⭐⭐
**Complexidade**: Média | **Valor**: Alto | **Tempo**: 3 dias

**Banco de Dados:**
```sql
CREATE TABLE IF NOT EXISTS public.kids_restriction (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  authorized_person_id UUID REFERENCES public.member(id) ON DELETE CASCADE,
  authorized_person_name TEXT, -- Para não-membros
  authorized_person_phone TEXT,
  relationship TEXT, -- 'Pai', 'Mãe', 'Avô', 'Tio', etc.
  photo TEXT, -- Foto da pessoa autorizada
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Registro de retiradas
CREATE TABLE IF NOT EXISTS public.kids_pickup (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  picked_up_by_id UUID REFERENCES public.member(id) ON DELETE SET NULL,
  picked_up_by_name TEXT,
  pickup_time TIMESTAMPTZ DEFAULT NOW(),
  authorized BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 📊 **CRONOGRAMA RESUMIDO**

| Fase | Funcionalidade | Tempo | Prioridade |
|------|----------------|-------|------------|
| 1.1 | Profissões | 2 dias | ⭐⭐⭐⭐⭐ |
| 1.2 | Relacionamentos Familiares | 5 dias | ⭐⭐⭐⭐⭐ |
| 1.3 | Áreas de Ministérios | 3 dias | ⭐⭐⭐⭐ |
| 2.1 | Sistema de Dons | 10 dias | ⭐⭐⭐⭐⭐ |
| 3.1 | Salas | 2 dias | ⭐⭐⭐⭐ |
| 3.2 | Turmas | 3 dias | ⭐⭐⭐⭐ |
| 3.3 | Aulas | 5 dias | ⭐⭐⭐⭐⭐ |
| 4.1 | Funções Específicas | 3 dias | ⭐⭐⭐⭐ |
| 4.2 | Permissões | 2 dias | ⭐⭐⭐⭐ |
| 5.1 | Restrições Kids | 3 dias | ⭐⭐⭐⭐ |

**TOTAL: ~38 dias (7-8 semanas)**

---

## 🎯 **ORDEM RECOMENDADA DE IMPLEMENTAÇÃO**

1. ✅ **Profissões** (2 dias) - Rápido e útil
2. ✅ **Relacionamentos Familiares** (5 dias) - Alto valor
3. ✅ **Sistema de Dons** (10 dias) - Diferencial único
4. ✅ **Áreas de Ministérios** (3 dias) - Complementa ministérios
5. ✅ **Salas + Turmas** (5 dias) - Base para aulas
6. ✅ **Aulas** (5 dias) - Sistema completo de ensino
7. ✅ **Funções Específicas** (3 dias) - Organização
8. ✅ **Permissões** (2 dias) - Segurança
9. ✅ **Restrições Kids** (3 dias) - Segurança infantil

---

**COM ESSAS IMPLEMENTAÇÕES, O CHURCH 360 SERÁ O SISTEMA MAIS COMPLETO DO BRASIL!** 🇧🇷⛪✨🙏

