-- ============================================
-- FIXES AND UPDATES FOR COMMUNITY FEATURES
-- ============================================

-- 1. FIX CLASSIFIEDS TABLE
-- Add missing columns to classifieds table
ALTER TABLE public.classifieds
ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'product',
ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS contact_info text,
ADD COLUMN IF NOT EXISTS deal_status text NOT NULL DEFAULT 'available',
ADD COLUMN IF NOT EXISTS views_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS likes_count integer DEFAULT 0;

-- 2. UPDATE COMMUNITY_POSTS TABLE
-- Add new fields for privacy and contact options
ALTER TABLE public.community_posts
ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS allow_whatsapp_contact boolean DEFAULT false,
-- Add new fields for polls
ADD COLUMN IF NOT EXISTS poll_options jsonb DEFAULT '[]'::jsonb, -- Array of strings
ADD COLUMN IF NOT EXISTS poll_votes jsonb DEFAULT '{}'::jsonb,   -- Map of { "option_index": [user_ids] }
ADD COLUMN IF NOT EXISTS likes_count integer DEFAULT 0;

-- 2.1 UNIFIED REACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.community_reactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  item_type text NOT NULL CHECK (item_type IN ('post', 'classified', 'devotional')),
  item_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES public.user_account(id) ON DELETE CASCADE,
  reaction text NOT NULL DEFAULT 'like',
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(item_type, item_id, user_id)
);

ALTER TABLE public.community_reactions
  DROP CONSTRAINT IF EXISTS community_reactions_item_type_check;
ALTER TABLE public.community_reactions
  ADD CONSTRAINT community_reactions_item_type_check
  CHECK (item_type IN ('post', 'classified', 'devotional'));

-- 2.2 UNIFIED COMMENTS TABLE
CREATE TABLE IF NOT EXISTS public.community_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  item_type text NOT NULL CHECK (item_type IN ('post', 'classified', 'devotional')),
  item_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES public.user_account(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.community_comments
  DROP CONSTRAINT IF EXISTS community_comments_item_type_check;
ALTER TABLE public.community_comments
  ADD CONSTRAINT community_comments_item_type_check
  CHECK (item_type IN ('post', 'classified', 'devotional'));

-- 2.3 RLS POLICIES FOR REACTIONS AND COMMENTS
ALTER TABLE public.community_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reactions are readable by all" ON public.community_reactions;
CREATE POLICY "Reactions are readable by all" ON public.community_reactions
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users insert their reactions" ON public.community_reactions;
CREATE POLICY "Users insert their reactions" ON public.community_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users update their reactions" ON public.community_reactions;
CREATE POLICY "Users update their reactions" ON public.community_reactions
  FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users delete their reactions" ON public.community_reactions;
CREATE POLICY "Users delete their reactions" ON public.community_reactions
  FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Comments are readable by all" ON public.community_comments;
CREATE POLICY "Comments are readable by all" ON public.community_comments
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users insert their comments" ON public.community_comments;
CREATE POLICY "Users insert their comments" ON public.community_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users update their comments" ON public.community_comments;
CREATE POLICY "Users update their comments" ON public.community_comments
  FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users delete their comments" ON public.community_comments;
CREATE POLICY "Users delete their comments" ON public.community_comments
  FOR DELETE USING (auth.uid() = user_id);

-- 2.4 TRIGGER: KEEP likes_count IN SYNC FOR POSTS AND CLASSIFIEDS
CREATE OR REPLACE FUNCTION public.community_reactions_like_counter()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF NEW.reaction = 'like' THEN
      IF NEW.item_type = 'post' THEN
        UPDATE public.community_posts SET likes_count = likes_count + 1 WHERE id = NEW.item_id;
      ELSIF NEW.item_type = 'classified' THEN
        UPDATE public.classifieds SET likes_count = likes_count + 1 WHERE id = NEW.item_id;
      END IF;
    END IF;
    RETURN NEW;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF COALESCE(OLD.reaction, '') <> COALESCE(NEW.reaction, '') THEN
      IF OLD.reaction = 'like' THEN
        IF OLD.item_type = 'post' THEN
          UPDATE public.community_posts SET likes_count = likes_count - 1 WHERE id = OLD.item_id;
        ELSIF OLD.item_type = 'classified' THEN
          UPDATE public.classifieds SET likes_count = likes_count - 1 WHERE id = OLD.item_id;
        END IF;
      END IF;
      IF NEW.reaction = 'like' THEN
        IF NEW.item_type = 'post' THEN
          UPDATE public.community_posts SET likes_count = likes_count + 1 WHERE id = NEW.item_id;
        ELSIF NEW.item_type = 'classified' THEN
          UPDATE public.classifieds SET likes_count = likes_count + 1 WHERE id = NEW.item_id;
        END IF;
      END IF;
    END IF;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    IF OLD.reaction = 'like' THEN
      IF OLD.item_type = 'post' THEN
        UPDATE public.community_posts SET likes_count = likes_count - 1 WHERE id = OLD.item_id;
      ELSIF OLD.item_type = 'classified' THEN
        UPDATE public.classifieds SET likes_count = likes_count - 1 WHERE id = OLD.item_id;
      END IF;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS community_reactions_like_counter_trg ON public.community_reactions;
CREATE TRIGGER community_reactions_like_counter_trg
AFTER INSERT OR UPDATE OR DELETE ON public.community_reactions
FOR EACH ROW EXECUTE FUNCTION public.community_reactions_like_counter();

-- 2.5 BACKFILL: MIGRATE EXISTING LIKES INTO UNIFIED community_reactions
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'community_post_likes'
  ) THEN
    INSERT INTO public.community_reactions (item_type, item_id, user_id, reaction, created_at)
    SELECT 'post', post_id, user_id, COALESCE(reaction, 'like'), created_at
    FROM public.community_post_likes
    ON CONFLICT DO NOTHING;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'classified_likes'
  ) THEN
    INSERT INTO public.community_reactions (item_type, item_id, user_id, reaction, created_at)
    SELECT 'classified', classified_id, user_id, COALESCE(reaction, 'like'), created_at
    FROM public.classified_likes
    ON CONFLICT DO NOTHING;
  END IF;
END
$$;

-- 3. REFRESH SCHEMA CACHE
-- This is crucial for Supabase to recognize the new columns immediately
NOTIFY pgrst, 'reload schema';
