DO $$
BEGIN
  CREATE TYPE public.how_found_church AS ENUM (
    'friend_invitation',
    'family',
    'social_media',
    'google_search',
    'passing_by',
    'event',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.visitor_source AS ENUM (
    'church',
    'house',
    'evangelism',
    'event',
    'online',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.user_account
  ADD COLUMN IF NOT EXISTS first_name text,
  ADD COLUMN IF NOT EXISTS last_name text,
  ADD COLUMN IF NOT EXISTS nickname text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS cpf text,
  ADD COLUMN IF NOT EXISTS birthdate date,
  ADD COLUMN IF NOT EXISTS gender public.member_gender,
  ADD COLUMN IF NOT EXISTS marital_status public.marital_status,
  ADD COLUMN IF NOT EXISTS marriage_date date,
  ADD COLUMN IF NOT EXISTS profession text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS address_complement text,
  ADD COLUMN IF NOT EXISTS neighborhood text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS zip_code text,
  ADD COLUMN IF NOT EXISTS status public.member_status DEFAULT 'visitor',
  ADD COLUMN IF NOT EXISTS member_type text,
  ADD COLUMN IF NOT EXISTS photo_url text,
  ADD COLUMN IF NOT EXISTS household_id uuid REFERENCES public.household(id),
  ADD COLUMN IF NOT EXISTS campus_id uuid REFERENCES public.campus(id),
  ADD COLUMN IF NOT EXISTS conversion_date date,
  ADD COLUMN IF NOT EXISTS baptism_date date,
  ADD COLUMN IF NOT EXISTS membership_date date,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.user_account(id),
  ADD COLUMN IF NOT EXISTS first_visit_date date,
  ADD COLUMN IF NOT EXISTS last_visit_date date,
  ADD COLUMN IF NOT EXISTS total_visits integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS how_found public.how_found_church,
  ADD COLUMN IF NOT EXISTS visitor_source public.visitor_source,
  ADD COLUMN IF NOT EXISTS prayer_request text,
  ADD COLUMN IF NOT EXISTS interests text,
  ADD COLUMN IF NOT EXISTS is_salvation boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS salvation_date date,
  ADD COLUMN IF NOT EXISTS testimony text,
  ADD COLUMN IF NOT EXISTS wants_baptism boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS baptism_event_id uuid,
  ADD COLUMN IF NOT EXISTS baptism_course_id uuid,
  ADD COLUMN IF NOT EXISTS wants_discipleship boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS discipleship_course_id uuid,
  ADD COLUMN IF NOT EXISTS assigned_mentor_id uuid REFERENCES public.user_account(id),
  ADD COLUMN IF NOT EXISTS follow_up_status text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS last_contact_date date,
  ADD COLUMN IF NOT EXISTS wants_contact boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS wants_to_return boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS show_birthday boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS show_contact boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS entrevistador boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
