-- Privacy-safe AI usage instrumentation table + admin aggregate RPC update.
-- This table MUST NOT store prompts, responses, document text, medical summaries, or user queries.

begin;

-- -----------------------------------------------------------------------------
-- 1) Table: public.ai_usage_events
-- -----------------------------------------------------------------------------

create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  feature_area text,
  model text,
  input_tokens integer,
  output_tokens integer,
  total_tokens integer,
  estimated_cost numeric,
  result text,
  error_code text,
  created_at timestamptz not null default now(),
  constraint ai_usage_events_tokens_nonneg check (
    (input_tokens is null or input_tokens >= 0)
    and (output_tokens is null or output_tokens >= 0)
    and (total_tokens is null or total_tokens >= 0)
  )
);

comment on table public.ai_usage_events is
  'Privacy-safe AI usage events. No prompts, outputs, document text, or health content.';

comment on column public.ai_usage_events.feature_area is
  'High-level feature category only (e.g., summarize, chat, extraction). No user text.';

comment on column public.ai_usage_events.model is
  'Model identifier only (e.g., gpt-4o, gpt-4o-mini).';

create index if not exists ai_usage_events_owner_created_at_idx on public.ai_usage_events (owner_user_id, created_at desc);
create index if not exists ai_usage_events_created_at_idx on public.ai_usage_events (created_at desc);
create index if not exists ai_usage_events_feature_area_idx on public.ai_usage_events (feature_area);
create index if not exists ai_usage_events_model_idx on public.ai_usage_events (model);
create index if not exists ai_usage_events_result_idx on public.ai_usage_events (result);

-- Note: We intentionally do NOT add a foreign key to auth.users to avoid coupling
-- and to keep this migration safe across environments.

alter table public.ai_usage_events enable row level security;

-- Lock down privileges explicitly.
revoke all on table public.ai_usage_events from public;
revoke all on table public.ai_usage_events from anon;

-- Authenticated clients can INSERT their own rows (no SELECT).
grant insert on table public.ai_usage_events to authenticated;

drop policy if exists "ai_usage_events_insert_own" on public.ai_usage_events;
create policy "ai_usage_events_insert_own"
  on public.ai_usage_events
  for insert
  to authenticated
  with check (auth.uid() = owner_user_id);

-- No read access from clients.
drop policy if exists "ai_usage_events_select_none" on public.ai_usage_events;
create policy "ai_usage_events_select_none"
  on public.ai_usage_events
  for select
  to authenticated
  using (false);

drop policy if exists "ai_usage_events_update_none" on public.ai_usage_events;
create policy "ai_usage_events_update_none"
  on public.ai_usage_events
  for update
  to authenticated
  using (false);

drop policy if exists "ai_usage_events_delete_none" on public.ai_usage_events;
create policy "ai_usage_events_delete_none"
  on public.ai_usage_events
  for delete
  to authenticated
  using (false);

-- -----------------------------------------------------------------------------
-- 2) RPC: admin_get_ai_usage_summary (aggregate-only)
-- -----------------------------------------------------------------------------

drop function if exists public.admin_get_ai_usage_summary();

create or replace function public.admin_get_ai_usage_summary()
returns table(
  total_request_count bigint,
  input_tokens bigint,
  output_tokens bigint,
  total_tokens bigint,
  estimated_cost numeric,
  failures_by_error_code jsonb,
  usage_by_feature_area jsonb,
  usage_by_model jsonb
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
    input_tokens := 0;
    output_tokens := 0;
    total_tokens := 0;
    estimated_cost := 0;
    failures_by_error_code := '[]'::jsonb;
    usage_by_feature_area := '[]'::jsonb;
    usage_by_model := '[]'::jsonb;
    return next;
    return;
  end if;

  return query
  with base as (
    select
      coalesce(feature_area, 'unknown') as feature_area,
      coalesce(model, 'unknown') as model,
      coalesce(input_tokens, 0)::bigint as input_tokens,
      coalesce(output_tokens, 0)::bigint as output_tokens,
      coalesce(total_tokens, coalesce(input_tokens, 0) + coalesce(output_tokens, 0))::bigint as total_tokens,
      coalesce(estimated_cost, 0)::numeric as estimated_cost,
      coalesce(result, 'unknown') as result,
      nullif(trim(coalesce(error_code, '')), '') as error_code
    from public.ai_usage_events
    -- Operational reporting window: rolling 30 days.
    where created_at > now() - interval '30 days'
  ),
  totals as (
    select
      count(*)::bigint as total_request_count,
      coalesce(sum(input_tokens), 0)::bigint as input_tokens,
      coalesce(sum(output_tokens), 0)::bigint as output_tokens,
      coalesce(sum(total_tokens), 0)::bigint as total_tokens,
      coalesce(sum(estimated_cost), 0)::numeric as estimated_cost
    from base
  ),
  failures as (
    select
      coalesce(error_code, 'unknown') as error_code,
      count(*)::bigint as failure_count
    from base
    where lower(result) in ('failure','failed','error')
    group by 1
    order by 2 desc
  ),
  by_feature as (
    select
      feature_area,
      count(*)::bigint as request_count,
      coalesce(sum(input_tokens), 0)::bigint as input_tokens,
      coalesce(sum(output_tokens), 0)::bigint as output_tokens,
      coalesce(sum(total_tokens), 0)::bigint as total_tokens,
      coalesce(sum(estimated_cost), 0)::numeric as estimated_cost,
      count(*) filter (where lower(result) in ('failure','failed','error'))::bigint as failed_request_count
    from base
    group by 1
    order by 2 desc
  ),
  by_model as (
    select
      model,
      count(*)::bigint as request_count,
      coalesce(sum(input_tokens), 0)::bigint as input_tokens,
      coalesce(sum(output_tokens), 0)::bigint as output_tokens,
      coalesce(sum(total_tokens), 0)::bigint as total_tokens,
      coalesce(sum(estimated_cost), 0)::numeric as estimated_cost,
      count(*) filter (where lower(result) in ('failure','failed','error'))::bigint as failed_request_count
    from base
    group by 1
    order by 2 desc
  )
  select
    t.total_request_count,
    t.input_tokens,
    t.output_tokens,
    t.total_tokens,
    t.estimated_cost,
    coalesce(
      (select jsonb_agg(jsonb_build_object('error_code', f.error_code, 'failure_count', f.failure_count)) from failures f),
      '[]'::jsonb
    ) as failures_by_error_code,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'feature_area', bf.feature_area,
        'request_count', bf.request_count,
        'input_tokens', bf.input_tokens,
        'output_tokens', bf.output_tokens,
        'total_tokens', bf.total_tokens,
        'estimated_cost', bf.estimated_cost,
        'failed_request_count', bf.failed_request_count
      )) from by_feature bf),
      '[]'::jsonb
    ) as usage_by_feature_area,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
        'model', bm.model,
        'request_count', bm.request_count,
        'input_tokens', bm.input_tokens,
        'output_tokens', bm.output_tokens,
        'total_tokens', bm.total_tokens,
        'estimated_cost', bm.estimated_cost,
        'failed_request_count', bm.failed_request_count
      )) from by_model bm),
      '[]'::jsonb
    ) as usage_by_model
  from totals t;
end;
$$;

revoke all on function public.admin_get_ai_usage_summary() from public;
revoke all on function public.admin_get_ai_usage_summary() from anon;
grant execute on function public.admin_get_ai_usage_summary() to authenticated;

commit;
