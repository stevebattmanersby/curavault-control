-- Creates wellbeing_check_ins table required by WellbeingService (daily feelings)

create table if not exists public.wellbeing_check_ins (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  owner_member_id uuid not null references public.family_members(id) on delete cascade,
  local_day text not null,
  mood_level text not null,
  energy_level integer null,
  stress_level integer null,
  notes text not null default '',
  is_archived boolean not null default false,
  client_operation_id text null,
  last_client_operation_id text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wellbeing_check_ins_unique_day unique (owner_user_id, owner_member_id, local_day)
);

create index if not exists wellbeing_check_ins_owner_user_id_idx on public.wellbeing_check_ins (owner_user_id);
create index if not exists wellbeing_check_ins_owner_member_id_idx on public.wellbeing_check_ins (owner_member_id);
create index if not exists wellbeing_check_ins_updated_at_idx on public.wellbeing_check_ins (updated_at desc);

alter table public.wellbeing_check_ins enable row level security;

-- Owner can read their own rows (member must belong to them)
drop policy if exists wellbeing_check_ins_select_own on public.wellbeing_check_ins;
create policy wellbeing_check_ins_select_own on public.wellbeing_check_ins
for select
using (
  owner_user_id = auth.uid()
  and exists (
    select 1 from public.family_members fm
    where fm.id = wellbeing_check_ins.owner_member_id
      and fm.owner_user_id = auth.uid()
  )
);

-- Owner can insert for their own account only
drop policy if exists wellbeing_check_ins_insert_own on public.wellbeing_check_ins;
create policy wellbeing_check_ins_insert_own on public.wellbeing_check_ins
for insert
with check (
  owner_user_id = auth.uid()
  and exists (
    select 1 from public.family_members fm
    where fm.id = wellbeing_check_ins.owner_member_id
      and fm.owner_user_id = auth.uid()
  )
);

-- Owner can update their own rows only
drop policy if exists wellbeing_check_ins_update_own on public.wellbeing_check_ins;
create policy wellbeing_check_ins_update_own on public.wellbeing_check_ins
for update
using (
  owner_user_id = auth.uid()
  and exists (
    select 1 from public.family_members fm
    where fm.id = wellbeing_check_ins.owner_member_id
      and fm.owner_user_id = auth.uid()
  )
)
with check (
  owner_user_id = auth.uid()
  and exists (
    select 1 from public.family_members fm
    where fm.id = wellbeing_check_ins.owner_member_id
      and fm.owner_user_id = auth.uid()
  )
);

-- Owner can delete their own rows only
drop policy if exists wellbeing_check_ins_delete_own on public.wellbeing_check_ins;
create policy wellbeing_check_ins_delete_own on public.wellbeing_check_ins
for delete
using (
  owner_user_id = auth.uid()
  and exists (
    select 1 from public.family_members fm
    where fm.id = wellbeing_check_ins.owner_member_id
      and fm.owner_user_id = auth.uid()
  )
);

-- Keep updated_at fresh on update
create or replace function public.set_updated_at_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists wellbeing_check_ins_set_updated_at on public.wellbeing_check_ins;
create trigger wellbeing_check_ins_set_updated_at
before update on public.wellbeing_check_ins
for each row
execute function public.set_updated_at_timestamp();
;
