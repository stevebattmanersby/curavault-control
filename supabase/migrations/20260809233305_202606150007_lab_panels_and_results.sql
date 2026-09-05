-- Phase 7: Blood results (lab panels + marker results)
--
-- Goals:
-- - Panel-first persistence suitable for real lab workflows
-- - Strict ownership RLS: `owner_user_id = auth.uid()`
-- - Fast queries via indexes
-- - Idempotent client retries via operation id columns (see 0006)

create extension if not exists pgcrypto;

do $$ begin
  -- ---------------------------------------------------------------------------
  -- Lab panels (parent)
  -- ---------------------------------------------------------------------------

  create table if not exists public.lab_panels (
    id uuid primary key,
    owner_user_id uuid not null references auth.users (id) on delete cascade,
    patient_member_id uuid not null references public.family_members (id) on delete restrict,
    panel_type text not null default '',
    collected_at timestamptz not null,
    lab_name text null,
    notes text null,
    archived_at timestamptz null,
    client_operation_id uuid null,
    last_client_operation_id uuid null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

  create index if not exists idx_lab_panels_owner on public.lab_panels (owner_user_id);
  create index if not exists idx_lab_panels_patient on public.lab_panels (patient_member_id);
  create index if not exists idx_lab_panels_collected_at on public.lab_panels (collected_at desc);
  create unique index if not exists uq_lab_panels_owner_client_op
    on public.lab_panels (owner_user_id, client_operation_id)
    where client_operation_id is not null;

  alter table public.lab_panels enable row level security;

  drop trigger if exists trg_lab_panels_updated_at on public.lab_panels;
  create trigger trg_lab_panels_updated_at
  before update on public.lab_panels
  for each row
  execute function public.set_updated_at();

  drop policy if exists "lab_panels_select_own" on public.lab_panels;
  create policy "lab_panels_select_own"
  on public.lab_panels
  for select
  using (auth.uid() = owner_user_id);

  drop policy if exists "lab_panels_insert_own" on public.lab_panels;
  create policy "lab_panels_insert_own"
  on public.lab_panels
  for insert
  with check (
    auth.uid() = owner_user_id
    and public.member_belongs_to_owner(patient_member_id, auth.uid())
  );

  drop policy if exists "lab_panels_update_own" on public.lab_panels;
  create policy "lab_panels_update_own"
  on public.lab_panels
  for update
  using (auth.uid() = owner_user_id)
  with check (
    auth.uid() = owner_user_id
    and public.member_belongs_to_owner(patient_member_id, auth.uid())
  );

  drop policy if exists "lab_panels_delete_own" on public.lab_panels;
  create policy "lab_panels_delete_own"
  on public.lab_panels
  for delete
  using (auth.uid() = owner_user_id);

  -- ---------------------------------------------------------------------------
  -- Lab results (child)
  --
  -- We denormalize owner/patient/collected_at onto the child row for:
  -- - easier RLS checks
  -- - fast queries / future aggregation
  -- ---------------------------------------------------------------------------

  create table if not exists public.lab_results (
    id uuid primary key,
    panel_id uuid not null references public.lab_panels (id) on delete cascade,
    owner_user_id uuid not null references auth.users (id) on delete cascade,
    patient_member_id uuid not null references public.family_members (id) on delete restrict,
    collected_at timestamptz not null,
    marker_name text not null default '',
    value numeric not null,
    unit text not null default '',
    reference_range_low numeric null,
    reference_range_high numeric null,
    flag_high boolean not null default false,
    flag_low boolean not null default false,
    archived_at timestamptz null,
    client_operation_id uuid null,
    last_client_operation_id uuid null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

  create index if not exists idx_lab_results_owner on public.lab_results (owner_user_id);
  create index if not exists idx_lab_results_patient on public.lab_results (patient_member_id);
  create index if not exists idx_lab_results_collected_at on public.lab_results (collected_at desc);
  create index if not exists idx_lab_results_panel on public.lab_results (panel_id);
  create unique index if not exists uq_lab_results_owner_client_op
    on public.lab_results (owner_user_id, client_operation_id)
    where client_operation_id is not null;

  alter table public.lab_results enable row level security;

  drop trigger if exists trg_lab_results_updated_at on public.lab_results;
  create trigger trg_lab_results_updated_at
  before update on public.lab_results
  for each row
  execute function public.set_updated_at();

  drop policy if exists "lab_results_select_own" on public.lab_results;
  create policy "lab_results_select_own"
  on public.lab_results
  for select
  using (auth.uid() = owner_user_id);

  drop policy if exists "lab_results_insert_own" on public.lab_results;
  create policy "lab_results_insert_own"
  on public.lab_results
  for insert
  with check (
    auth.uid() = owner_user_id
    and public.member_belongs_to_owner(patient_member_id, auth.uid())
    and exists(
      select 1 from public.lab_panels p
      where p.id = panel_id
        and p.owner_user_id = auth.uid()
        and p.patient_member_id = patient_member_id
    )
  );

  drop policy if exists "lab_results_update_own" on public.lab_results;
  create policy "lab_results_update_own"
  on public.lab_results
  for update
  using (auth.uid() = owner_user_id)
  with check (
    auth.uid() = owner_user_id
    and public.member_belongs_to_owner(patient_member_id, auth.uid())
    and exists(
      select 1 from public.lab_panels p
      where p.id = panel_id
        and p.owner_user_id = auth.uid()
        and p.patient_member_id = patient_member_id
    )
  );

  drop policy if exists "lab_results_delete_own" on public.lab_results;
  create policy "lab_results_delete_own"
  on public.lab_results
  for delete
  using (auth.uid() = owner_user_id);

end $$;
;
