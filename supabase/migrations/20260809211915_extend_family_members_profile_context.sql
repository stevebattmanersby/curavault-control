ALTER TABLE public.family_members
  ADD COLUMN IF NOT EXISTS preferred_name text;
;
