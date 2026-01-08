-- 63_create_church_info_table.sql

-- Create church_info table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.church_info (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    logo_url text,
    mission text,
    vision text,
    "values" text[],
    history text,
    address text,
    phone text,
    email text,
    website text,
    social_media jsonb,
    service_times jsonb,
    pastors jsonb,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz
);

-- Enable RLS
ALTER TABLE public.church_info ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any to avoid conflicts during re-runs
DROP POLICY IF EXISTS "Church info is viewable by everyone" ON public.church_info;
DROP POLICY IF EXISTS "Church info is insertable by authenticated users" ON public.church_info;
DROP POLICY IF EXISTS "Church info is updatable by authenticated users" ON public.church_info;

-- Create policies
-- Allow everyone to read church info (public profile)
CREATE POLICY "Church info is viewable by everyone" ON public.church_info
    FOR SELECT
    USING (true);

-- Allow authenticated users to insert/update church info
-- Ideally restrict to admins, but for now authenticated is better than nothing or broken
CREATE POLICY "Church info is insertable by authenticated users" ON public.church_info
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Church info is updatable by authenticated users" ON public.church_info
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT SELECT ON public.church_info TO anon;
GRANT SELECT ON public.church_info TO authenticated;
GRANT INSERT, UPDATE ON public.church_info TO authenticated;
