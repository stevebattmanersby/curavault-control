-- Phase 4: Core health data (system of record = Supabase)
--
-- This migration creates all core user-owned tables and locks them down with
-- strict Row Level Security (RLS).
--
-- Design notes:
-- - Every row is owned by exactly one Supabase auth user: `owner_user_id = auth.uid()`.
-- - Every row is linked to a patient/member row (`patient_member_id`) that MUST
--   also belong to the same owner.
-- - The app always creates a "Me" family_member record for the owner, and uses
--   it as the patient context for self.
--
-- IMPORTANT:
-- We keep `public.set_updated_at()` from 0001 as the canonical updated_at trigger.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- User profile (optional but useful for multi-device preferences)
-- -----------------------------------------------------------------------------

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text null,
  full_name text null,
  theme_mode_key text not null default 'system',
  dark_palette_key text not null default 'mist',
  notifications_master_enabled boolean not null default true,
  notification_type_enabled jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_profiles enable row level security;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

drop policy if exists "user_profiles_select_own" on public.user_profiles;
create policy "user_profiles_select_own"
on public.user_profiles
for select
using (auth.uid() = user_id);

drop policy if exists "user_profiles_insert_own" on public.user_profiles;
create policy "user_profiles_insert_own"
on public.user_profiles
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_profiles_update_own" on public.user_profiles;
create policy "user_profiles_update_own"
on public.user_profiles
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Family members
-- -----------------------------------------------------------------------------

create table if not exists public.family_members (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null,
  relationship text not null,
  date_of_birth date null,
  sex text not null default 'unknown',
  notes text not null default '',
  avatar_key text not null default 'adult',
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_family_members_owner on public.family_members (owner_user_id);

alter table public.family_members enable row level security;

drop trigger if exists trg_family_members_updated_at on public.family_members;
create trigger trg_family_members_updated_at
before update on public.family_members
for each row
execute function public.set_updated_at();

drop policy if exists "family_members_select_own" on public.family_members;
create policy "family_members_select_own"
on public.family_members
for select
using (auth.uid() = owner_user_id);

drop policy if exists "family_members_insert_own" on public.family_members;
create policy "family_members_insert_own"
on public.family_members
for insert
with check (auth.uid() = owner_user_id);

drop policy if exists "family_members_update_own" on public.family_members;
create policy "family_members_update_own"
on public.family_members
for update
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists "family_members_delete_own" on public.family_members;
create policy "family_members_delete_own"
on public.family_members
for delete
using (auth.uid() = owner_user_id);

-- -----------------------------------------------------------------------------
-- Helper: enforce that patient_member_id belongs to the owner
-- -----------------------------------------------------------------------------

create or replace function public.member_belongs_to_owner(member_id uuid, owner_id uuid)
returns boolean
language sql
stable
as $$
  select exists(
    select 1 from public.family_members m
    where m.id = member_id and m.owner_user_id = owner_id
  );
$$;

-- -----------------------------------------------------------------------------
-- Core tables: medical_records, medications, insurance_cards, vaccinations,
-- appointments, blood_pressure_readings
-- -----------------------------------------------------------------------------

create table if not exists public.medical_records (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  title text not null,
  body_region_id text null,
  condition text not null default '',
  notes text not null default '',
  attached_document_ids uuid[] not null default '{}',
  archived_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_medical_records_owner on public.medical_records (owner_user_id);
create index if not exists idx_medical_records_patient on public.medical_records (patient_member_id);

alter table public.medical_records enable row level security;
drop trigger if exists trg_medical_records_updated_at on public.medical_records;
create trigger trg_medical_records_updated_at
before update on public.medical_records
for each row
execute function public.set_updated_at();

drop policy if exists "medical_records_select_own" on public.medical_records;
create policy "medical_records_select_own"
on public.medical_records
for select
using (auth.uid() = owner_user_id);

drop policy if exists "medical_records_insert_own" on public.medical_records;
create policy "medical_records_insert_own"
on public.medical_records
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "medical_records_update_own" on public.medical_records;
create policy "medical_records_update_own"
on public.medical_records
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "medical_records_delete_own" on public.medical_records;
create policy "medical_records_delete_own"
on public.medical_records
for delete
using (auth.uid() = owner_user_id);

-- Medications
create table if not exists public.medications (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  name text not null,
  dosage text not null default '',
  frequency text not null default '',
  frequency_every integer null,
  frequency_unit text null,
  route text not null default '',
  start_date date null,
  end_date date null,
  prescribing_provider text not null default '',
  reason text not null default '',
  notes text not null default '',
  status text not null default 'current' check (status in ('current', 'past', 'paused')),
  linked_medical_record_id uuid null,
  archived_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_medications_owner on public.medications (owner_user_id);
create index if not exists idx_medications_patient on public.medications (patient_member_id);

alter table public.medications enable row level security;
drop trigger if exists trg_medications_updated_at on public.medications;
create trigger trg_medications_updated_at
before update on public.medications
for each row
execute function public.set_updated_at();

drop policy if exists "medications_select_own" on public.medications;
create policy "medications_select_own"
on public.medications
for select
using (auth.uid() = owner_user_id);

drop policy if exists "medications_insert_own" on public.medications;
create policy "medications_insert_own"
on public.medications
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "medications_update_own" on public.medications;
create policy "medications_update_own"
on public.medications
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "medications_delete_own" on public.medications;
create policy "medications_delete_own"
on public.medications
for delete
using (auth.uid() = owner_user_id);

-- Insurance cards
create table if not exists public.insurance_cards (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  provider_name text not null,
  policy_or_member_number text not null default '',
  group_number text null,
  phone_number text null,
  website text null,
  notes text not null default '',
  front_image_base64 text null,
  front_image_mime_type text null,
  back_image_base64 text null,
  back_image_mime_type text null,
  effective_start date null,
  effective_end date null,
  archived_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_insurance_cards_owner on public.insurance_cards (owner_user_id);
create index if not exists idx_insurance_cards_patient on public.insurance_cards (patient_member_id);

alter table public.insurance_cards enable row level security;
drop trigger if exists trg_insurance_cards_updated_at on public.insurance_cards;
create trigger trg_insurance_cards_updated_at
before update on public.insurance_cards
for each row
execute function public.set_updated_at();

drop policy if exists "insurance_cards_select_own" on public.insurance_cards;
create policy "insurance_cards_select_own"
on public.insurance_cards
for select
using (auth.uid() = owner_user_id);

drop policy if exists "insurance_cards_insert_own" on public.insurance_cards;
create policy "insurance_cards_insert_own"
on public.insurance_cards
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "insurance_cards_update_own" on public.insurance_cards;
create policy "insurance_cards_update_own"
on public.insurance_cards
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "insurance_cards_delete_own" on public.insurance_cards;
create policy "insurance_cards_delete_own"
on public.insurance_cards
for delete
using (auth.uid() = owner_user_id);

-- Vaccinations
create table if not exists public.vaccinations (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  vaccine_name text not null,
  dose_number integer null,
  series_total_doses integer null,
  series_completed boolean not null default false,
  date_received date null,
  provider_location text not null default '',
  batch_number text null,
  notes text not null default '',
  attached_document_ids uuid[] not null default '{}',
  archived_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_vaccinations_owner on public.vaccinations (owner_user_id);
create index if not exists idx_vaccinations_patient on public.vaccinations (patient_member_id);

alter table public.vaccinations enable row level security;
drop trigger if exists trg_vaccinations_updated_at on public.vaccinations;
create trigger trg_vaccinations_updated_at
before update on public.vaccinations
for each row
execute function public.set_updated_at();

drop policy if exists "vaccinations_select_own" on public.vaccinations;
create policy "vaccinations_select_own"
on public.vaccinations
for select
using (auth.uid() = owner_user_id);

drop policy if exists "vaccinations_insert_own" on public.vaccinations;
create policy "vaccinations_insert_own"
on public.vaccinations
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "vaccinations_update_own" on public.vaccinations;
create policy "vaccinations_update_own"
on public.vaccinations
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "vaccinations_delete_own" on public.vaccinations;
create policy "vaccinations_delete_own"
on public.vaccinations
for delete
using (auth.uid() = owner_user_id);

-- Appointments
create table if not exists public.appointments (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  provider_name text not null default '',
  appointment_type text not null default '',
  title text not null,
  scheduled_at timestamptz not null,
  location text not null default '',
  notes text not null default '',
  outcome_notes text not null default '',
  reminder_enabled boolean not null default false,
  follow_up_reminder_enabled boolean not null default false,
  upload_documents_reminder_enabled boolean not null default false,
  related_record_id uuid null,
  related_document_id uuid null,
  archived_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_appointments_owner on public.appointments (owner_user_id);
create index if not exists idx_appointments_patient on public.appointments (patient_member_id);
create index if not exists idx_appointments_scheduled_at on public.appointments (scheduled_at);

alter table public.appointments enable row level security;
drop trigger if exists trg_appointments_updated_at on public.appointments;
create trigger trg_appointments_updated_at
before update on public.appointments
for each row
execute function public.set_updated_at();

drop policy if exists "appointments_select_own" on public.appointments;
create policy "appointments_select_own"
on public.appointments
for select
using (auth.uid() = owner_user_id);

drop policy if exists "appointments_insert_own" on public.appointments;
create policy "appointments_insert_own"
on public.appointments
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "appointments_update_own" on public.appointments;
create policy "appointments_update_own"
on public.appointments
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "appointments_delete_own" on public.appointments;
create policy "appointments_delete_own"
on public.appointments
for delete
using (auth.uid() = owner_user_id);

-- Blood pressure readings
create table if not exists public.blood_pressure_readings (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  systolic integer not null,
  diastolic integer not null,
  pulse integer null,
  taken_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_bp_owner on public.blood_pressure_readings (owner_user_id);
create index if not exists idx_bp_patient on public.blood_pressure_readings (patient_member_id);
create index if not exists idx_bp_taken_at on public.blood_pressure_readings (taken_at);

alter table public.blood_pressure_readings enable row level security;
drop trigger if exists trg_bp_updated_at on public.blood_pressure_readings;
create trigger trg_bp_updated_at
before update on public.blood_pressure_readings
for each row
execute function public.set_updated_at();

drop policy if exists "bp_select_own" on public.blood_pressure_readings;
create policy "bp_select_own"
on public.blood_pressure_readings
for select
using (auth.uid() = owner_user_id);

drop policy if exists "bp_insert_own" on public.blood_pressure_readings;
create policy "bp_insert_own"
on public.blood_pressure_readings
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "bp_update_own" on public.blood_pressure_readings;
create policy "bp_update_own"
on public.blood_pressure_readings
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "bp_delete_own" on public.blood_pressure_readings;
create policy "bp_delete_own"
on public.blood_pressure_readings
for delete
using (auth.uid() = owner_user_id);

-- -----------------------------------------------------------------------------
-- Documents hardening (table may already exist in your project)
-- -----------------------------------------------------------------------------

create table if not exists public.medical_documents (
  id uuid primary key,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  patient_member_id uuid not null references public.family_members (id) on delete restrict,
  title text not null default '',
  document_type text not null default '',
  note text not null default '',
  body_region_id text null,
  file_name text null,
  mime_type text null,
  file_size bigint null,
  bucket text null,
  storage_path text null,
  linked_medical_record_id uuid null,
  linked_appointment_id uuid null,
  tags text[] not null default '{}',
  archived_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_medical_documents_owner on public.medical_documents (owner_user_id);
create index if not exists idx_medical_documents_patient on public.medical_documents (patient_member_id);

alter table public.medical_documents enable row level security;

drop trigger if exists trg_medical_documents_updated_at on public.medical_documents;
create trigger trg_medical_documents_updated_at
before update on public.medical_documents
for each row
execute function public.set_updated_at();

drop policy if exists "medical_documents_select_own" on public.medical_documents;
create policy "medical_documents_select_own"
on public.medical_documents
for select
using (auth.uid() = owner_user_id);

drop policy if exists "medical_documents_insert_own" on public.medical_documents;
create policy "medical_documents_insert_own"
on public.medical_documents
for insert
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "medical_documents_update_own" on public.medical_documents;
create policy "medical_documents_update_own"
on public.medical_documents
for update
using (auth.uid() = owner_user_id)
with check (
  auth.uid() = owner_user_id
  and public.member_belongs_to_owner(patient_member_id, auth.uid())
);

drop policy if exists "medical_documents_delete_own" on public.medical_documents;
create policy "medical_documents_delete_own"
on public.medical_documents
for delete
using (auth.uid() = owner_user_id);
