alter table public.community_reactions
  drop constraint if exists community_reactions_item_type_check;

alter table public.community_reactions
  add constraint community_reactions_item_type_check
  check (item_type in ('post', 'classified', 'devotional'));

alter table public.community_comments
  drop constraint if exists community_comments_item_type_check;

alter table public.community_comments
  add constraint community_comments_item_type_check
  check (item_type in ('post', 'classified', 'devotional'));

notify pgrst, 'reload schema';

