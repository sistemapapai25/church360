DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'community_post_comments'
  ) THEN
    BEGIN
      EXECUTE 'DROP TRIGGER IF EXISTS on_comment_change ON public.community_post_comments';
    EXCEPTION WHEN undefined_table THEN
      -- ignore
    END;
    EXECUTE 'DROP TABLE IF EXISTS public.community_post_comments CASCADE';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'update_comments_count'
      AND pg_function_is_visible(oid)
  ) THEN
    EXECUTE 'DROP FUNCTION public.update_comments_count() CASCADE';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'community_posts' AND column_name = 'comments_count'
  ) THEN
    EXECUTE 'ALTER TABLE public.community_posts DROP COLUMN comments_count';
  END IF;
END
$$;
