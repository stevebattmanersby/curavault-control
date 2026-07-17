-- AI usage provider/service tracking (privacy-safe) + v2 admin aggregate RPC.
--
-- Goals:
-- - Distinguish OpenAI/LLM token usage vs Google Document AI/OCR usage.
-- - Keep events privacy-safe: NO prompts, responses, OCR text, document text,
--   filenames, or file paths.
-- - Preserve existing table + existing admin_get_ai_usage_summary() for backwards
--   compatibility.
-- - Add a new aggregate-only RPC: admin_get_ai_usage_summary_v2().
--
-- IMPORTANT: This migration is idempotent and does not drop/truncate/recreate.

begin;

-- -----------------------------------------------------------------------------
-- 1) Extend public.ai_usage_events (non-destructive)
-- -----------------------------------------------------------------------------

-- Provider + service identify the external system and usage class.
alter table if exists public.ai_usage_events
  add column if not exists provider text not null default 'unknown';

alter table if exists public.ai_usage_events
  add column if not exists service text not null default 'llm';

-- Optional operational metadata.
alter table if exists public.ai_usage_events
  add column if not exists source text;

alter table if exists public.ai_usage_events
  add column if not exists edge_function_name text;

-- Request and processing counters for non-token services.
alter table if exists public.ai_usage_events
  add column if not exists request_count integer not null default 1;

alter table if exists public.ai_usage_events
  add column if not exists pages_processed integer;

alter table if exists public.ai_usage_events
  add column if not exists files_processed integer;

alter table if exists public.ai_usage_events
  add column if not exists images_processed integer;

alter table if exists public.ai_usage_events
  add column if not exists characters_processed integer;

-- Cost: prefer the USD-suffixed column, but keep the legacy estimated_cost.
alter table if exists public.ai_usage_events
  add column if not exists estimated_cost_usd numeric;

-- Basic indexes to keep aggregates fast.
create index if not exists ai_usage_events_provider_idx on public.ai_usage_events (provider);
create index if not exists ai_usage_events_service_idx on public.ai_usage_events (service);
create index if not exists ai_usage_events_provider_service_idx on public.ai_usage_events (provider, service);

-- Privacy + integrity constraints.
-- NOTE: We add new constraints without touching the existing tokens constraint.
alter table if exists public.ai_usage_events
  drop constraint if exists ai_usage_events_request_count_positive;
alter table if exists public.ai_usage_events
  add constraint ai_usage_events_request_count_positive check (request_count >= 0);

alter table if exists public.ai_usage_events
  drop constraint if exists ai_usage_events_counts_nonneg;
alter table if exists public.ai_usage_events
  add constraint ai_usage_events_counts_nonneg check (
    (pages_processed is null or pages_processed >= 0)
    and (files_processed is null or files_processed >= 0)
    and (images_processed is null or images_processed >= 0)
    and (characters_processed is null or characters_processed >= 0)
  );

alter table if exists public.ai_usage_events
  drop constraint if exists ai_usage_events_cost_nonneg;
alter table if exists public.ai_usage_events
  add constraint ai_usage_events_cost_nonneg check (
    (estimated_cost is null or estimated_cost >= 0)
    and (estimated_cost_usd is null or estimated_cost_usd >= 0)
  );

comment on column public.ai_usage_events.provider is
  'Provider name only (e.g., openai, google). No user content.';
comment on column public.ai_usage_events.service is
  'Service class (e.g., llm, document_ai, ocr). No user content.';
comment on column public.ai_usage_events.pages_processed is
  'For OCR / Document AI: pages processed. No text content stored.';
comment on column public.ai_usage_events.files_processed is
  'For OCR / Document AI: number of files processed. No filenames stored.';

-- -----------------------------------------------------------------------------
-- 2) RPC: admin_get_ai_usage_summary_v2 (aggregate-only)
-- -----------------------------------------------------------------------------

drop function if exists public.admin_get_ai_usage_summary_v2();

create or replace function public.admin_get_ai_usage_summary_v2()
returns table(
  total_request_count bigint,
  total_cost_usd numeric,
  total_input_tokens bigint,
  total_output_tokens bigint,
  total_tokens bigint,
  total_pages_processed bigint,
  total_files_processed bigint,
  total_images_processed bigint,
  total_failures bigint,
  usage_by_provider jsonb,
  usage_by_service jsonb,
  usage_by_provider_service jsonb,
  usage_by_model jsonb,
  usage_by_feature_area jsonb,
  failures_by_provider jsonb,
  failures_by_error_code jsonb,
  daily_usage jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_table boolean;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_table := public._admin_safe_table_exists('public.ai_usage_events');
  if not v_has_table then
    total_request_count := 0;
    total_cost_usd := 0;
    total_input_tokens := 0;
    total_output_tokens := 0;
    total_tokens := 0;
    total_pages_processed := 0;
    total_files_processed := 0;
    total_images_processed := 0;
    total_failures := 0;
    usage_by_provider := '[]'::jsonb;
    usage_by_service := '[]'::jsonb;
    usage_by_provider_service := '[]'::jsonb;
    usage_by_model := '[]'::jsonb;
    usage_by_feature_area := '[]'::jsonb;
    failures_by_provider := '[]'::jsonb;
    failures_by_error_code := '[]'::jsonb;
    daily_usage := '[]'::jsonb;
    return next;
    return;
  end if;

  return query
  with base as (
    select
      coalesce(nullif(trim(aue.provider), ''), 'unknown') as provider,
      coalesce(nullif(trim(aue.service), ''), 'unknown') as service,
      coalesce(nullif(trim(aue.feature_area), ''), 'unknown') as feature_area,
      coalesce(nullif(trim(aue.model), ''), 'unknown') as model,
      greatest(coalesce(aue.request_count, 1), 0)::bigint as request_count,
      greatest(coalesce(aue.input_tokens, 0), 0)::bigint as input_token_count,
      greatest(coalesce(aue.output_tokens, 0), 0)::bigint as output_token_count,
      greatest(
        coalesce(aue.total_tokens, coalesce(aue.input_tokens, 0) + coalesce(aue.output_tokens, 0)),
        0
      )::bigint as total_token_count,
      greatest(coalesce(aue.pages_processed, 0), 0)::bigint as pages_processed_count,
      greatest(coalesce(aue.files_processed, 0), 0)::bigint as files_processed_count,
      greatest(coalesce(aue.images_processed, 0), 0)::bigint as images_processed_count,
      greatest(coalesce(aue.characters_processed, 0), 0)::bigint as characters_processed_count,
      greatest(coalesce(aue.estimated_cost_usd, aue.estimated_cost, 0), 0)::numeric as estimated_cost_amount,
      coalesce(nullif(trim(aue.result), ''), 'unknown') as result,
      nullif(trim(coalesce(aue.error_code, '')), '') as error_code,
      aue.created_at
    from public.ai_usage_events aue
    where aue.created_at > now() - interval '30 days'
  ),
  totals as (
    select
      coalesce(sum(b.request_count), 0)::bigint as total_request_count,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as total_cost_usd,
      coalesce(sum(b.input_token_count), 0)::bigint as total_input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as total_output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.pages_processed_count), 0)::bigint as total_pages_processed,
      coalesce(sum(b.files_processed_count), 0)::bigint as total_files_processed,
      coalesce(sum(b.images_processed_count), 0)::bigint as total_images_processed,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as total_failures
    from base b
  ),
  by_provider as (
    select
      b.provider,
      coalesce(sum(b.request_count), 0)::bigint as request_count,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as cost_usd,
      coalesce(sum(b.input_token_count), 0)::bigint as input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.pages_processed_count), 0)::bigint as pages_processed,
      coalesce(sum(b.files_processed_count), 0)::bigint as files_processed,
      coalesce(sum(b.images_processed_count), 0)::bigint as images_processed,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as failed_request_count
    from base b
    group by 1
    order by 2 desc
  ),
  by_service as (
    select
      b.service,
      coalesce(sum(b.request_count), 0)::bigint as request_count,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as cost_usd,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.pages_processed_count), 0)::bigint as pages_processed,
      coalesce(sum(b.files_processed_count), 0)::bigint as files_processed,
      coalesce(sum(b.images_processed_count), 0)::bigint as images_processed,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as failed_request_count
    from base b
    group by 1
    order by 2 desc
  ),
  by_provider_service as (
    select
      b.provider,
      b.service,
      coalesce(sum(b.request_count), 0)::bigint as request_count,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as cost_usd,
      coalesce(sum(b.input_token_count), 0)::bigint as input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.pages_processed_count), 0)::bigint as pages_processed,
      coalesce(sum(b.files_processed_count), 0)::bigint as files_processed,
      coalesce(sum(b.images_processed_count), 0)::bigint as images_processed,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as failed_request_count
    from base b
    group by 1,2
    order by 3 desc
  ),
  by_model as (
    select
      b.provider,
      b.service,
      b.model,
      coalesce(sum(b.request_count), 0)::bigint as request_count,
      coalesce(sum(b.input_token_count), 0)::bigint as input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as cost_usd,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as failed_request_count
    from base b
    group by 1,2,3
    order by 4 desc
  ),
  by_feature as (
    select
      b.feature_area,
      coalesce(sum(b.request_count), 0)::bigint as request_count,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.pages_processed_count), 0)::bigint as pages_processed,
      coalesce(sum(b.files_processed_count), 0)::bigint as files_processed,
      coalesce(sum(b.images_processed_count), 0)::bigint as images_processed,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as cost_usd,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as failed_request_count
    from base b
    group by 1
    order by 2 desc
  ),
  failures_by_provider as (
    select
      b.provider,
      b.service,
      coalesce(sum(b.request_count), 0)::bigint as failure_count
    from base b
    where lower(b.result) in ('failure','failed','error')
    group by 1,2
    order by 3 desc
  ),
  failures_by_error_code as (
    select
      b.provider,
      b.service,
      coalesce(b.error_code, 'unknown') as error_code,
      coalesce(sum(b.request_count), 0)::bigint as failure_count
    from base b
    where lower(b.result) in ('failure','failed','error')
    group by 1,2,3
    order by 4 desc
  ),
  daily as (
    select
      date_trunc('day', b.created_at)::date as day,
      coalesce(sum(b.request_count), 0)::bigint as request_count,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as cost_usd,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.pages_processed_count), 0)::bigint as pages_processed,
      coalesce(sum(b.files_processed_count), 0)::bigint as files_processed,
      coalesce(sum(b.images_processed_count), 0)::bigint as images_processed,
      coalesce(sum(case when lower(b.result) in ('failure','failed','error') then b.request_count else 0 end), 0)::bigint as failures
    from base b
    group by 1
    order by 1 asc
  )
  select
    t.total_request_count,
    t.total_cost_usd,
    t.total_input_tokens,
    t.total_output_tokens,
    t.total_tokens,
    t.total_pages_processed,
    t.total_files_processed,
    t.total_images_processed,
    t.total_failures,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'provider', p.provider,
        'request_count', p.request_count,
        'estimated_cost_usd', p.cost_usd,
        'input_tokens', p.input_tokens,
        'output_tokens', p.output_tokens,
        'total_tokens', p.total_tokens,
        'pages_processed', p.pages_processed,
        'files_processed', p.files_processed,
        'images_processed', p.images_processed,
        'failed_request_count', p.failed_request_count
      )) from by_provider p),
      '[]'::jsonb
    ) as usage_by_provider,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'service', s.service,
        'request_count', s.request_count,
        'estimated_cost_usd', s.cost_usd,
        'total_tokens', s.total_tokens,
        'pages_processed', s.pages_processed,
        'files_processed', s.files_processed,
        'images_processed', s.images_processed,
        'failed_request_count', s.failed_request_count
      )) from by_service s),
      '[]'::jsonb
    ) as usage_by_service,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'provider', ps.provider,
        'service', ps.service,
        'request_count', ps.request_count,
        'estimated_cost_usd', ps.cost_usd,
        'input_tokens', ps.input_tokens,
        'output_tokens', ps.output_tokens,
        'total_tokens', ps.total_tokens,
        'pages_processed', ps.pages_processed,
        'files_processed', ps.files_processed,
        'images_processed', ps.images_processed,
        'failed_request_count', ps.failed_request_count
      )) from by_provider_service ps),
      '[]'::jsonb
    ) as usage_by_provider_service,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'provider', m.provider,
        'service', m.service,
        'model', m.model,
        'request_count', m.request_count,
        'input_tokens', m.input_tokens,
        'output_tokens', m.output_tokens,
        'total_tokens', m.total_tokens,
        'estimated_cost_usd', m.cost_usd,
        'failed_request_count', m.failed_request_count
      )) from by_model m),
      '[]'::jsonb
    ) as usage_by_model,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'feature_area', f.feature_area,
        'request_count', f.request_count,
        'total_tokens', f.total_tokens,
        'pages_processed', f.pages_processed,
        'files_processed', f.files_processed,
        'images_processed', f.images_processed,
        'estimated_cost_usd', f.cost_usd,
        'failed_request_count', f.failed_request_count
      )) from by_feature f),
      '[]'::jsonb
    ) as usage_by_feature_area,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'provider', fp.provider,
        'service', fp.service,
        'failure_count', fp.failure_count
      )) from failures_by_provider fp),
      '[]'::jsonb
    ) as failures_by_provider,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'provider', fe.provider,
        'service', fe.service,
        'error_code', fe.error_code,
        'failure_count', fe.failure_count
      )) from failures_by_error_code fe),
      '[]'::jsonb
    ) as failures_by_error_code,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'day', d.day::text,
        'request_count', d.request_count,
        'estimated_cost_usd', d.cost_usd,
        'total_tokens', d.total_tokens,
        'pages_processed', d.pages_processed,
        'files_processed', d.files_processed,
        'images_processed', d.images_processed,
        'failures', d.failures
      )) from daily d),
      '[]'::jsonb
    ) as daily_usage
  from totals t;
end;
$$;

revoke all on function public.admin_get_ai_usage_summary_v2() from public;
revoke all on function public.admin_get_ai_usage_summary_v2() from anon;
grant execute on function public.admin_get_ai_usage_summary_v2() to authenticated;

commit;
