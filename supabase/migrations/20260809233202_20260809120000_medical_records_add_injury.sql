-- Additive, backwards-compatible: allow MedicalRecord to store an Injury label
-- separately from Condition so the UI can treat these concepts distinctly.

alter table public.medical_records
  add column if not exists injury text not null default '';
;
