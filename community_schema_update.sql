-- Atualização da tabela de membros (user_account) para privacidade
ALTER TABLE public.user_account 
ADD COLUMN IF NOT EXISTS show_birthday boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS show_contact boolean DEFAULT false;

-- Tabela para o Feed Espiritual (Mural)
CREATE TABLE IF NOT EXISTS public.community_posts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    author_id uuid REFERENCES public.user_account(id) ON DELETE CASCADE,
    content text NOT NULL,
    type text NOT NULL CHECK (type IN ('prayer_request', 'testimony', 'general')),
    status text DEFAULT 'pending_approval' CHECK (status IN ('pending_approval', 'approved', 'rejected')),
    likes_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela para Curtidas no Feed
CREATE TABLE IF NOT EXISTS public.community_post_likes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id uuid REFERENCES public.community_posts(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.user_account(id) ON DELETE CASCADE,
    reaction text NOT NULL DEFAULT 'like',
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(post_id, user_id)
);

-- Tabela para Classificados
CREATE TABLE IF NOT EXISTS public.classifieds (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    author_id uuid REFERENCES public.user_account(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text NOT NULL,
    price decimal(10,2), -- Pode ser nulo para doações ou "a combinar"
    category text NOT NULL, -- 'product', 'service', 'job', 'donation'
    contact_info text, -- Pode ser diferente do cadastro
    image_urls text[], -- Array de URLs de imagens
    status text DEFAULT 'pending_approval' CHECK (status IN ('pending_approval', 'approved', 'rejected', 'sold')),
    views_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Políticas RLS (Row Level Security)

-- Habilitar RLS
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classifieds ENABLE ROW LEVEL SECURITY;

-- Políticas para Community Posts
CREATE POLICY "Posts visíveis apenas se aprovados ou se for o autor" ON public.community_posts
    FOR SELECT USING (status = 'approved' OR auth.uid() = author_id);

CREATE POLICY "Autores podem criar posts" ON public.community_posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Autores podem editar seus posts pendentes" ON public.community_posts
    FOR UPDATE USING (auth.uid() = author_id AND status = 'pending_approval');

CREATE POLICY "Autores podem deletar seus posts" ON public.community_posts
    FOR DELETE USING (auth.uid() = author_id);

-- Políticas para Classificados (similar aos posts)
CREATE POLICY "Classificados visíveis apenas se aprovados ou se for o autor" ON public.classifieds
    FOR SELECT USING (status = 'approved' OR auth.uid() = author_id);

CREATE POLICY "Autores podem criar classificados" ON public.classifieds
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Autores podem editar seus classificados" ON public.classifieds
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Autores podem deletar seus classificados" ON public.classifieds
    FOR DELETE USING (auth.uid() = author_id);
