-- Fix admin_get_ai_usage_summary runtime ambiguity.
--
-- In PL/pgSQL, OUT parameters such as input_tokens/output_tokens are visible as
-- variables inside the function body. Qualify ai_usage_events columns through a
-- table alias so Postgres does not confuse them with return-column variables.

begin;

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
      coalesce(aue.feature_area, 'unknown') as feature_area,
      coalesce(aue.model, 'unknown') as model,
      coalesce(aue.input_tokens, 0)::bigint as input_token_count,
      coalesce(aue.output_tokens, 0)::bigint as output_token_count,
      coalesce(
        aue.total_tokens,
        coalesce(aue.input_tokens, 0) + coalesce(aue.output_tokens, 0)
      )::bigint as total_token_count,
      coalesce(aue.estimated_cost, 0)::numeric as estimated_cost_amount,
      coalesce(aue.result, 'unknown') as result,
      nullif(trim(coalesce(aue.error_code, '')), '') as error_code
    from public.ai_usage_events aue
    where aue.created_at > now() - interval '30 days'
  ),
  totals as (
    select
      count(*)::bigint as total_request_count,
      coalesce(sum(b.input_token_count), 0)::bigint as input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as estimated_cost
    from base b
  ),
  failures as (
    select
      coalesce(b.error_code, 'unknown') as error_code,
      count(*)::bigint as failure_count
    from base b
    where lower(b.result) in ('failure', 'failed', 'error')
    group by 1
    order by 2 desc
  ),
  by_feature as (
    select
      b.feature_area,
      count(*)::bigint as request_count,
      coalesce(sum(b.input_token_count), 0)::bigint as input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as estimated_cost,
      count(*) filter (
        where lower(b.result) in ('failure', 'failed', 'error')
      )::bigint as failed_request_count
    from base b
    group by 1
    order by 2 desc
  ),
  by_model as (
    select
      b.model,
      count(*)::bigint as request_count,
      coalesce(sum(b.input_token_count), 0)::bigint as input_tokens,
      coalesce(sum(b.output_token_count), 0)::bigint as output_tokens,
      coalesce(sum(b.total_token_count), 0)::bigint as total_tokens,
      coalesce(sum(b.estimated_cost_amount), 0)::numeric as estimated_cost,
      count(*) filter (
        where lower(b.result) in ('failure', 'failed', 'error')
      )::bigint as failed_request_count
    from base b
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
      (
        select jsonb_agg(jsonb_build_object(
          'error_code', f.error_code,
          'failure_count', f.failure_count
        ))
        from failures f
      ),
      '[]'::jsonb
    ) as failures_by_error_code,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'feature_area', bf.feature_area,
          'request_count', bf.request_count,
          'input_tokens', bf.input_tokens,
          'output_tokens', bf.output_tokens,
          'total_tokens', bf.total_tokens,
          'estimated_cost', bf.estimated_cost,
          'failed_request_count', bf.failed_request_count
        ))
        from by_feature bf
      ),
      '[]'::jsonb
    ) as usage_by_feature_area,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'model', bm.model,
          'request_count', bm.request_count,
          'input_tokens', bm.input_tokens,
          'output_tokens', bm.output_tokens,
          'total_tokens', bm.total_tokens,
          'estimated_cost', bm.estimated_cost,
          'failed_request_count', bm.failed_request_count
        ))
        from by_model bm
      ),
      '[]'::jsonb
    ) as usage_by_model
  from totals t;
end;
$$;

revoke all on function public.admin_get_ai_usage_summary() from public;
revoke all on function public.admin_get_ai_usage_summary() from anon;
grant execute on function public.admin_get_ai_usage_summary() to authenticated;

commit;
