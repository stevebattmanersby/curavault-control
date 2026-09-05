-- Admin-only UI metadata: theme preference for the control site.
-- This must not expose any public user data.

alter table public.admin_users
add column if not exists theme_preference text not null default 'system';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'admin_users_theme_preference_check'
      and conrelid = 'public.admin_users'::regclass
  ) then
    alter table public.admin_users
    add constraint admin_users_theme_preference_check
    check (theme_preference in ('system', 'light', 'dark', 'ai'));
  end if;
end $$;
;
