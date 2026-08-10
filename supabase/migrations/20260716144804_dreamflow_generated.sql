-- CuraVault demo/sample data for Dreamflow "Create Sample Data".
--
-- This file is intentionally data-only:
-- - no schema changes
-- - no RLS/policy changes
-- - no storage writes
-- - no real PHI
--
-- It seeds each existing auth user with a safe demo profile, a "Me" member,
-- core health rows, and vault document metadata matching the uploaded test
-- image set. Re-running the file updates the same deterministic rows.

do $$
declare
  u record;
  member_id uuid;
  record_id uuid;
  appointment_id uuid;
  appointment_doc_id uuid;

  make_uuid text;
begin
  for u in
    select id, email
    from auth.users
    where email is not null
  loop
    member_id := (
      substr(md5(u.id::text || ':sample:member:me'), 1, 8) || '-' ||
      substr(md5(u.id::text || ':sample:member:me'), 9, 4) || '-' ||
      substr(md5(u.id::text || ':sample:member:me'), 13, 4) || '-' ||
      substr(md5(u.id::text || ':sample:member:me'), 17, 4) || '-' ||
      substr(md5(u.id::text || ':sample:member:me'), 21, 12)
    )::uuid;

    record_id := (
      substr(md5(u.id::text || ':sample:record:knee'), 1, 8) || '-' ||
      substr(md5(u.id::text || ':sample:record:knee'), 9, 4) || '-' ||
      substr(md5(u.id::text || ':sample:record:knee'), 13, 4) || '-' ||
      substr(md5(u.id::text || ':sample:record:knee'), 17, 4) || '-' ||
      substr(md5(u.id::text || ':sample:record:knee'), 21, 12)
    )::uuid;

    appointment_id := (
      substr(md5(u.id::text || ':sample:appointment:gp'), 1, 8) || '-' ||
      substr(md5(u.id::text || ':sample:appointment:gp'), 9, 4) || '-' ||
      substr(md5(u.id::text || ':sample:appointment:gp'), 13, 4) || '-' ||
      substr(md5(u.id::text || ':sample:appointment:gp'), 17, 4) || '-' ||
      substr(md5(u.id::text || ':sample:appointment:gp'), 21, 12)
    )::uuid;

    appointment_doc_id := (
      substr(md5(u.id::text || ':sample:doc:appointment'), 1, 8) || '-' ||
      substr(md5(u.id::text || ':sample:doc:appointment'), 9, 4) || '-' ||
      substr(md5(u.id::text || ':sample:doc:appointment'), 13, 4) || '-' ||
      substr(md5(u.id::text || ':sample:doc:appointment'), 17, 4) || '-' ||
      substr(md5(u.id::text || ':sample:doc:appointment'), 21, 12)
    )::uuid;

    insert into public.user_profiles (user_id, email, full_name)
    values (u.id, u.email, 'Demo User')
    on conflict (user_id) do update
      set email = excluded.email,
          full_name = coalesce(nullif(public.user_profiles.full_name, ''), excluded.full_name),
          updated_at = now();

    insert into public.user_entitlements (
      user_id,
      plan,
      ai_access,
      export_access,
      document_quota_mb,
      subscription_status,
      source_platform
    )
    values (
      u.id,
      'pro',
      true,
      true,
      50000,
      'active',
      'internal'
    )
    on conflict (user_id) do update
      set plan = excluded.plan,
          ai_access = excluded.ai_access,
          export_access = excluded.export_access,
          document_quota_mb = excluded.document_quota_mb,
          subscription_status = excluded.subscription_status,
          source_platform = excluded.source_platform,
          updated_at = now();

    insert into public.family_members (
      id,
      owner_user_id,
      display_name,
      relationship,
      date_of_birth,
      sex,
      notes,
      avatar_key
    )
    values (
      member_id,
      u.id,
      'Me',
      'self',
      date '1990-01-01',
      'unknown',
      'Demo profile for CuraVault sample data.',
      'adult'
    )
    on conflict (id) do update
      set display_name = excluded.display_name,
          relationship = excluded.relationship,
          notes = excluded.notes,
          updated_at = now();

    insert into public.medical_records (
      id,
      owner_user_id,
      patient_member_id,
      title,
      body_region_id,
      condition,
      notes,
      attached_document_ids
    )
    values (
      record_id,
      u.id,
      member_id,
      'Sample knee injury assessment',
      'knee',
      'Knee injury follow-up',
      'Safe demo record based on the uploaded injury assessment test image.',
      '{}'
    )
    on conflict (id) do update
      set title = excluded.title,
          body_region_id = excluded.body_region_id,
          condition = excluded.condition,
          notes = excluded.notes,
          updated_at = now();

    insert into public.appointments (
      id,
      owner_user_id,
      patient_member_id,
      provider_name,
      appointment_type,
      title,
      scheduled_at,
      location,
      notes,
      upload_documents_reminder_enabled,
      related_record_id
    )
    values (
      appointment_id,
      u.id,
      member_id,
      'Demo Family Clinic',
      'GP appointment',
      'Sample GP follow-up',
      now() + interval '14 days',
      'Demo Clinic',
      'Bring the uploaded appointment letter test image.',
      true,
      record_id
    )
    on conflict (id) do update
      set provider_name = excluded.provider_name,
          appointment_type = excluded.appointment_type,
          title = excluded.title,
          scheduled_at = excluded.scheduled_at,
          location = excluded.location,
          notes = excluded.notes,
          upload_documents_reminder_enabled = excluded.upload_documents_reminder_enabled,
          related_record_id = excluded.related_record_id,
          updated_at = now();

    insert into public.medications (
      id,
      owner_user_id,
      patient_member_id,
      name,
      dosage,
      frequency,
      route,
      start_date,
      prescribing_provider,
      reason,
      notes,
      status,
      linked_medical_record_id
    )
    values (
      (
        substr(md5(u.id::text || ':sample:medication:amoxicillin'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:medication:amoxicillin'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:medication:amoxicillin'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:medication:amoxicillin'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:medication:amoxicillin'), 21, 12)
      )::uuid,
      u.id,
      member_id,
      'Amoxicillin',
      '500 mg',
      'Three times daily',
      'Oral',
      current_date - 7,
      'Demo Clinic',
      'Sample prescription test data',
      'Demo row based on prescription test image.',
      'current',
      record_id
    )
    on conflict (id) do update
      set name = excluded.name,
          dosage = excluded.dosage,
          frequency = excluded.frequency,
          route = excluded.route,
          start_date = excluded.start_date,
          prescribing_provider = excluded.prescribing_provider,
          reason = excluded.reason,
          notes = excluded.notes,
          status = excluded.status,
          linked_medical_record_id = excluded.linked_medical_record_id,
          updated_at = now();

    insert into public.vaccinations (
      id,
      owner_user_id,
      patient_member_id,
      vaccine_name,
      dose_number,
      series_total_doses,
      series_completed,
      date_received,
      provider_location,
      notes
    )
    values (
      (
        substr(md5(u.id::text || ':sample:vaccination:flu'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:vaccination:flu'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:vaccination:flu'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:vaccination:flu'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:vaccination:flu'), 21, 12)
      )::uuid,
      u.id,
      member_id,
      'Influenza',
      1,
      1,
      true,
      current_date - 60,
      'Demo Pharmacy',
      'Demo row based on vaccination record test image.'
    )
    on conflict (id) do update
      set vaccine_name = excluded.vaccine_name,
          dose_number = excluded.dose_number,
          series_total_doses = excluded.series_total_doses,
          series_completed = excluded.series_completed,
          date_received = excluded.date_received,
          provider_location = excluded.provider_location,
          notes = excluded.notes,
          updated_at = now();

    insert into public.insurance_cards (
      id,
      owner_user_id,
      patient_member_id,
      provider_name,
      policy_or_member_number,
      group_number,
      phone_number,
      website,
      notes,
      effective_start,
      effective_end
    )
    values (
      (
        substr(md5(u.id::text || ':sample:insurance:demo'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:insurance:demo'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:insurance:demo'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:insurance:demo'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:insurance:demo'), 21, 12)
      )::uuid,
      u.id,
      member_id,
      'Demo Health Cover',
      'DEMO-123456',
      'GROUP-DEMO',
      '+353 00 000 0000',
      'https://example.com',
      'Demo insurance policy/card sample.',
      current_date - 120,
      current_date + 245
    )
    on conflict (id) do update
      set provider_name = excluded.provider_name,
          policy_or_member_number = excluded.policy_or_member_number,
          group_number = excluded.group_number,
          phone_number = excluded.phone_number,
          website = excluded.website,
          notes = excluded.notes,
          effective_start = excluded.effective_start,
          effective_end = excluded.effective_end,
          updated_at = now();

    insert into public.blood_pressure_readings (
      id,
      owner_user_id,
      patient_member_id,
      systolic,
      diastolic,
      pulse,
      taken_at
    )
    values (
      (
        substr(md5(u.id::text || ':sample:bp:one'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:bp:one'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:bp:one'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:bp:one'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:bp:one'), 21, 12)
      )::uuid,
      u.id,
      member_id,
      122,
      78,
      72,
      now() - interval '3 days'
    )
    on conflict (id) do update
      set systolic = excluded.systolic,
          diastolic = excluded.diastolic,
          pulse = excluded.pulse,
          taken_at = excluded.taken_at,
          updated_at = now();

    insert into public.medical_documents (
      id,
      owner_user_id,
      patient_member_id,
      title,
      document_type,
      note,
      body_region_id,
      file_name,
      mime_type,
      file_size,
      linked_medical_record_id,
      linked_appointment_id,
      tags
    )
    values
      (appointment_doc_id, u.id, member_id, 'Sample appointment letter', 'Appointment Letter', 'Upload TEST IMAGE 1 - Apt.png to test OCR and AI intake.', null, 'TEST IMAGE 1 - Apt.png', 'image/png', 832164, null, appointment_id, array['sample', 'appointment']),
      ((
        substr(md5(u.id::text || ':sample:doc:vaccination-appt'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-appt'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-appt'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-appt'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-appt'), 21, 12)
      )::uuid, u.id, member_id, 'Sample vaccination appointment', 'Appointment Letter', 'Upload TEST IMAGE 2 - vaccination appt.png to test appointment extraction.', null, 'TEST IMAGE 2 - vaccination appt.png', 'image/png', 593613, null, appointment_id, array['sample', 'vaccination']),
      ((
        substr(md5(u.id::text || ':sample:doc:injury'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:injury'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:injury'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:injury'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:injury'), 21, 12)
      )::uuid, u.id, member_id, 'Sample injury assessment', 'Medical Record', 'Upload TEST IMAGE 3 - Injury Assessment.png to test medical record extraction.', 'knee', 'TEST IMAGE 3 - Injury Assessment.png', 'image/png', 718036, record_id, null, array['sample', 'injury']),
      ((
        substr(md5(u.id::text || ':sample:doc:discharge'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:discharge'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:discharge'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:discharge'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:discharge'), 21, 12)
      )::uuid, u.id, member_id, 'Sample discharge summary', 'Discharge Summary', 'Upload TEST IMAGE 4 - Discharge summary.png to test summary extraction.', null, 'TEST IMAGE 4 - Discharge summary.png', 'image/png', 711155, record_id, null, array['sample', 'hospital']),
      ((
        substr(md5(u.id::text || ':sample:doc:prescription'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:prescription'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:prescription'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:prescription'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:prescription'), 21, 12)
      )::uuid, u.id, member_id, 'Sample prescription', 'Prescription', 'Upload TEST IMAGE 5 - Prescription.png to test medication extraction.', null, 'TEST IMAGE 5 - Prescription.png', 'image/png', 515465, record_id, null, array['sample', 'prescription']),
      ((
        substr(md5(u.id::text || ':sample:doc:repeat-prescription'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:repeat-prescription'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:repeat-prescription'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:repeat-prescription'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:repeat-prescription'), 21, 12)
      )::uuid, u.id, member_id, 'Sample repeat prescription', 'Prescription', 'Upload TEST IMAGE 6 - Repeat Prescription.png to test repeat medication extraction.', null, 'TEST IMAGE 6 - Repeat Prescription.png', 'image/png', 663029, record_id, null, array['sample', 'prescription']),
      ((
        substr(md5(u.id::text || ':sample:doc:bloodwork'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:bloodwork'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:bloodwork'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:bloodwork'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:bloodwork'), 21, 12)
      )::uuid, u.id, member_id, 'Sample bloodwork', 'Lab Result', 'Upload TEST IMAGE 7 - Bloodwork.png to test lab extraction.', null, 'TEST IMAGE 7 - Bloodwork.png', 'image/png', 747676, null, null, array['sample', 'lab']),
      ((
        substr(md5(u.id::text || ':sample:doc:blood-pressure'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:blood-pressure'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:blood-pressure'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:blood-pressure'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:blood-pressure'), 21, 12)
      )::uuid, u.id, member_id, 'Sample blood pressure reading', 'Blood Pressure', 'Upload TEST IMAGE 8 - Blood Pressur.png to test vital sign extraction.', null, 'TEST IMAGE 8 - Blood Pressur.png', 'image/png', 717476, null, null, array['sample', 'blood-pressure']),
      ((
        substr(md5(u.id::text || ':sample:doc:vaccination-record'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-record'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-record'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-record'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:vaccination-record'), 21, 12)
      )::uuid, u.id, member_id, 'Sample vaccination record', 'Vaccination Record', 'Upload TEST IMAGE 9 - Vaccination Record.png to test vaccination extraction.', null, 'TEST IMAGE 9 - Vaccination Record.png', 'image/png', 760765, null, null, array['sample', 'vaccination']),
      ((
        substr(md5(u.id::text || ':sample:doc:xray'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:xray'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:xray'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:xray'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:xray'), 21, 12)
      )::uuid, u.id, member_id, 'Sample X-ray report', 'Imaging Report', 'Upload TEST IMAGE 10 - X-Ray.png to test imaging document classification.', null, 'TEST IMAGE 10 - X-Ray.png', 'image/png', 755997, record_id, null, array['sample', 'imaging']),
      ((
        substr(md5(u.id::text || ':sample:doc:referral'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:referral'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:referral'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:referral'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:referral'), 21, 12)
      )::uuid, u.id, member_id, 'Sample referral letter', 'Referral', 'Upload TEST IMAGE 11 - Referral.png to test referral extraction.', null, 'TEST IMAGE 11 - Referral.png', 'image/png', 883399, record_id, appointment_id, array['sample', 'referral']),
      ((
        substr(md5(u.id::text || ':sample:doc:health-insurance'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:health-insurance'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:health-insurance'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:health-insurance'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:health-insurance'), 21, 12)
      )::uuid, u.id, member_id, 'Sample health insurance policy', 'Insurance', 'Upload TEST IMAGE 12 - Health Insurance Policy.png to test insurance extraction.', null, 'TEST IMAGE 12 - Health Insurance Policy.png', 'image/png', 776610, null, null, array['sample', 'insurance']),
      ((
        substr(md5(u.id::text || ':sample:doc:medical-cert'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:medical-cert'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:medical-cert'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:medical-cert'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:medical-cert'), 21, 12)
      )::uuid, u.id, member_id, 'Sample medical certificate', 'Medical Certificate', 'Upload TEST IMAGE 13 - Medical Cert.png to test certificate classification.', null, 'TEST IMAGE 13 - Medical Cert.png', 'image/png', 933343, record_id, null, array['sample', 'certificate']),
      ((
        substr(md5(u.id::text || ':sample:doc:dental'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:dental'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:dental'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:dental'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:dental'), 21, 12)
      )::uuid, u.id, member_id, 'Sample dental treatment plan', 'Treatment Plan', 'Upload TEST IMAGE 14 - Dental Treatment Plan.png to test treatment-plan extraction.', null, 'TEST IMAGE 14 - Dental Treatment Plan.png', 'image/png', 800718, record_id, null, array['sample', 'dental']),
      ((
        substr(md5(u.id::text || ':sample:doc:carer-note'), 1, 8) || '-' ||
        substr(md5(u.id::text || ':sample:doc:carer-note'), 9, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:carer-note'), 13, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:carer-note'), 17, 4) || '-' ||
        substr(md5(u.id::text || ':sample:doc:carer-note'), 21, 12)
      )::uuid, u.id, member_id, 'Sample parent/carer note', 'Care Note', 'Upload TEST IMAGE 15 - Parent Carer Note.png to test family-care note classification.', null, 'TEST IMAGE 15 - Parent Carer Note.png', 'image/png', 823900, record_id, null, array['sample', 'care'])
    on conflict (id) do update
      set title = excluded.title,
          document_type = excluded.document_type,
          note = excluded.note,
          body_region_id = excluded.body_region_id,
          file_name = excluded.file_name,
          mime_type = excluded.mime_type,
          file_size = excluded.file_size,
          linked_medical_record_id = excluded.linked_medical_record_id,
          linked_appointment_id = excluded.linked_appointment_id,
          tags = excluded.tags,
          updated_at = now();
  end loop;
end $$;
