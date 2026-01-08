-- ============================================
-- FIX PERMISSIONS FOR COMMUNITY FEATURES
-- ============================================

-- 1. Policies for Community Post Likes (was missing)
-- Allow anyone to see likes
DROP POLICY IF EXISTS "Users can view likes" ON public.community_post_likes;
CREATE POLICY "Users can view likes" ON public.community_post_likes
    FOR SELECT USING (true);

-- Allow users to like (insert own)
DROP POLICY IF EXISTS "Users can like posts" ON public.community_post_likes;
CREATE POLICY "Users can like posts" ON public.community_post_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow users to unlike (delete own)
DROP POLICY IF EXISTS "Users can unlike posts" ON public.community_post_likes;
CREATE POLICY "Users can unlike posts" ON public.community_post_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Allow users to change their own reaction
DROP POLICY IF EXISTS "Users can update own reactions" ON public.community_post_likes;
CREATE POLICY "Users can update own reactions" ON public.community_post_likes
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Policies for Admins/Leaders to Moderate Posts
-- View ALL posts (including pending/rejected)
DROP POLICY IF EXISTS "Admins can view all posts" ON public.community_posts;
CREATE POLICY "Admins can view all posts" ON public.community_posts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_account
            WHERE id = auth.uid()
            AND role_global IN ('owner', 'admin', 'leader')
        )
    );

-- Update ALL posts (approve/reject)
DROP POLICY IF EXISTS "Admins can update all posts" ON public.community_posts;
CREATE POLICY "Admins can update all posts" ON public.community_posts
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_account
            WHERE id = auth.uid()
            AND role_global IN ('owner', 'admin', 'leader')
        )
    );

-- Delete ALL posts
DROP POLICY IF EXISTS "Admins can delete all posts" ON public.community_posts;
CREATE POLICY "Admins can delete all posts" ON public.community_posts
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_account
            WHERE id = auth.uid()
            AND role_global IN ('owner', 'admin', 'leader')
        )
    );

-- 3. Policies for Admins/Leaders to Moderate Classifieds
-- View ALL classifieds
DROP POLICY IF EXISTS "Admins can view all classifieds" ON public.classifieds;
CREATE POLICY "Admins can view all classifieds" ON public.classifieds
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_account
            WHERE id = auth.uid()
            AND role_global IN ('owner', 'admin', 'leader')
        )
    );

-- Update ALL classifieds
DROP POLICY IF EXISTS "Admins can update all classifieds" ON public.classifieds;
CREATE POLICY "Admins can update all classifieds" ON public.classifieds
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_account
            WHERE id = auth.uid()
            AND role_global IN ('owner', 'admin', 'leader')
        )
    );

-- Delete ALL classifieds
DROP POLICY IF EXISTS "Admins can delete all classifieds" ON public.classifieds;
CREATE POLICY "Admins can delete all classifieds" ON public.classifieds
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_account
            WHERE id = auth.uid()
            AND role_global IN ('owner', 'admin', 'leader')
        )
    );

-- 4. Policies for Regular Users (Create Posts/Classifieds)
-- Allow users to create posts
DROP POLICY IF EXISTS "Users can create posts" ON public.community_posts;
CREATE POLICY "Users can create posts" ON public.community_posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

-- Allow users to view approved posts (if not already exists)
DROP POLICY IF EXISTS "Users can view approved posts" ON public.community_posts;
CREATE POLICY "Users can view approved posts" ON public.community_posts
    FOR SELECT USING (status = 'approved' OR auth.uid() = author_id);

-- Allow users to create classifieds
DROP POLICY IF EXISTS "Users can create classifieds" ON public.classifieds;
CREATE POLICY "Users can create classifieds" ON public.classifieds
    FOR INSERT WITH CHECK (auth.uid() = author_id);

-- Allow users to update their own classifieds
DROP POLICY IF EXISTS "Users can update own classifieds" ON public.classifieds;
CREATE POLICY "Users can update own classifieds" ON public.classifieds
    FOR UPDATE USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

-- Allow users to view approved classifieds (if not already exists)
DROP POLICY IF EXISTS "Users can view approved classifieds" ON public.classifieds;
CREATE POLICY "Users can view approved classifieds" ON public.classifieds
    FOR SELECT USING (status = 'approved' OR auth.uid() = author_id);
