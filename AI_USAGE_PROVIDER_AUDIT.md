# AI Usage Provider Audit (CuraVault Control Site)

Date: 2026-07-17

Scope of this audit:
- Supabase schema/migrations in `supabase/migrations/*` related to AI usage, token usage, and cost.
- Flutter Control Site code paths that *render* AI usage and *write* usage events.
- Repo-wide search for any OpenAI / Google Document AI / OCR / Gemini instrumentation.

Privacy constraints respected in this audit:
- This report does **not** include prompts, AI responses, OCR text, extracted text, document names, file names/paths, medical content, or search query text.

---

## Executive conclusion

**No — Google AI / Google Document AI / OCR usage is not currently tracked separately** from token-based LLM usage in this Control Site repo.

What exists today is **token-centric** tracking:
- There is a dedicated table `public.ai_usage_events`, but it stores **tokens + model + estimated_cost** only (no provider/service, and no page/request units).
- The Flutter instrumentation that exists (`UsageEventService.trackAiUsage`) writes to **`public.usage_events`** and records token-ish fields under a `properties` JSON map.
- The Control Site admin RPC `public.admin_get_ai_usage_summary()` (current version) aggregates **`public.ai_usage_events`**, and therefore **cannot** see usage written only to `usage_events`.

There is **no evidence in this repo** of:
- OpenAI API calls
- Google Document AI calls
- OCR pipelines
- Gemini calls
- Edge Functions that emit AI usage events

---

## 1) Supabase schema / migrations audit

### 1.1 `public.ai_usage_events` (present)

Defined in:
- `supabase/migrations/20260616_add_privacy_safe_ai_usage_events.sql`

Columns (as created by migration):
- `id uuid`
- `owner_user_id uuid` (required)
- `feature_area text`
- `model text`
- `input_tokens integer`
- `output_tokens integer`
- `total_tokens integer`
- `estimated_cost numeric`
- `result text`
- `error_code text`
- `created_at timestamptz default now()`

Security model:
- RLS enabled.
- `authenticated` can **INSERT** rows where `auth.uid() = owner_user_id`.
- `authenticated` cannot SELECT/UPDATE/DELETE (`select none`, `update none`, `delete none`).

Provider/service support:
- **No `provider`, `service`, or `billing_unit` field exists.**
- The table is structurally optimized for **LLM token metering**, not for OCR/page-based metering.

### 1.2 `public.admin_get_ai_usage_summary()` (present)

Defined/updated in:
- `supabase/migrations/20260616_add_privacy_safe_ai_usage_events.sql` (new aggregate RPC)
- `supabase/migrations/20260706_fix_ai_usage_summary_ambiguous_columns.sql` (qualified column refs)

What it aggregates:
- Reads from `public.ai_usage_events` only (30-day rolling window).
- Returns:
  - `total_request_count`
  - token totals (`input_tokens`, `output_tokens`, `total_tokens`)
  - `estimated_cost`
  - JSON aggregates:
    - `failures_by_error_code`
    - `usage_by_feature_area`
    - `usage_by_model`

Provider/service support:
- **No provider dimension is returned or groupable**, because the base table has no provider/service fields.

Cost estimation:
- Cost is not computed server-side; it is aggregated from `ai_usage_events.estimated_cost`.
- This implies **the caller that inserts rows must estimate costs**.

### 1.3 `public.usage_events` (referenced, but not defined in this repo)

Observed:
- Multiple admin-safe reporting migrations reference `public.usage_events` and check for columns like:
  - `estimated_tokens_input`
  - `estimated_tokens_output`
  - `estimated_cost`

Examples:
- `supabase/migrations/20260614_create_admin_safe_reporting_functions.sql`
- `supabase/migrations/20260615_complete_control_site_live_data_rpcs.sql`

However:
- **This Control Site repo does not include a migration that creates `public.usage_events`.**
  - That table likely comes from the consumer app repo or an earlier migration set.

Implication:
- There are effectively **two potential “AI usage event” channels**:
  1) `usage_events` (general-purpose operational events)
  2) `ai_usage_events` (dedicated token-focused AI events)

But the **admin AI usage summary** currently targets only channel (2).

---

## 2) Flutter Control Site code audit

### 2.1 Admin UI: `lib/admin/pages/ai_usage_page.dart`

What it displays:
- “AI Usage” page: tokens, estimated cost, limits, errors.

How it loads data:
- Uses `AdminStore.refreshAiUsage()` → repository → `admin_get_ai_usage_summary` RPC.

Provider/service support in UI:
- UI assumes token-based metrics (tokens/day, tokens by feature, tokens by model).
- There are no panels/filters/fields for:
  - provider (OpenAI vs Google)
  - service (LLM vs OCR)
  - billing unit (tokens vs pages vs requests)

### 2.2 Models: `lib/admin/data/models/admin_models.dart`

AI-related models are token-centric:
- `AiUsageSnapshot` contains token totals and estimated costs.
- Breakdowns:
  - `usageByFeature` (feature_area)
  - charts/tables are driven by tokens and estimated cost

Notably missing from models:
- provider/service identifiers (e.g. `openai`, `google_document_ai`, `google_gemini`)
- OCR/page counters
- “requests” by provider/service (the only request count is total AI requests, implicitly token-backed)

### 2.3 Queries: `lib/admin/data/supabase/supabase_admin_queries.dart`

AI usage query:
- `getAIUsage()` calls `rpc('admin_get_ai_usage_summary')`.

Comment indicates expectation:
- The code explicitly references the *new* RPC as “ai_usage_events-based”.

Result parsing:
- Reads `total_request_count`, `input_tokens`, `output_tokens`, `estimated_cost`.
- Parses `usage_by_feature_area` list.

Provider/service support:
- No parsing for any provider/service fields (none returned).

### 2.4 Repository: `lib/admin/data/supabase/supabase_admin_repository.dart`

- Marks datasource live/mock/error for `AdminDataSourceKey.aiUsage`.
- No provider/service-specific logic.

### 2.5 Client-side instrumentation: `lib/services/usage_event_service.dart`

This service writes to:
- `public.usage_events` (table name constant: `usage_events`).

AI usage instrumentation method:
- `trackAiUsage(...)` writes an event with `event_name` like:
  - `ai_request_completed`
  - `ai_request_failed`
- It stores:
  - `model`
  - `input_tokens`, `output_tokens`, `total_tokens`
  - `estimated_cost`
  in the `properties` JSON.

Provider/service support:
- **No provider/service field exists** in the event payload.
- This instrumentation is best described as **LLM token usage**, even if it were used for non-LLM services.

Important mismatch:
- The Admin AI usage page is backed by `admin_get_ai_usage_summary()` which reads from **`ai_usage_events`**.
- The only AI event writer in this repo writes to **`usage_events`**.
- Therefore, unless something outside this repo writes to `ai_usage_events`, the AI Usage page can appear empty.

---

## 3) Edge Functions / backend instrumentation audit

Repo search results:
- No edge functions directory is present in this Control Site repo.
- No code references were found for:
  - `openai`
  - `ocr`
  - `document ai` / `DocumentAI`
  - `gemini`
  - `vertex`

Conclusion:
- This repo does not contain the runtime code that actually calls AI providers.
- Consequently, **there is no in-repo proof that any provider-specific usage events are emitted**.

---

## 4) What is currently tracked?

### OpenAI / LLM token usage
**Partially tracked (token-centric), but with a structural mismatch.**

Tracked fields available today (depending on which channel is used):
- `model`
- token counts (input/output/total)
- `estimated_cost`
- `feature_area`
- `result` + `error_code`

Where tracked:
- In the DB table `public.ai_usage_events` (schema supports this)
- In the general `public.usage_events` via `UsageEventService.trackAiUsage` (writes token-like fields into JSON properties)

Admin reporting:
- `admin_get_ai_usage_summary()` aggregates **only `ai_usage_events`**.

### Google Document AI / OCR usage
**Not tracked separately (and not modeled correctly for page-based billing).**

Missing elements:
- No `provider='google'` / `service='document_ai'` dimension.
- No `pages_processed`, `documents_processed`, or `requests` counters.
- No separate cost estimation model for page/request based billing.

### Google Gemini usage
**Not present in this repo and not tracked.**

### Other AI providers
**No extensible provider abstraction exists** in the schema or UI models.

---

## 5) Where costs are estimated

Today, cost is treated as a single numeric field:
- `ai_usage_events.estimated_cost` OR `usage_events.properties.estimated_cost`

There is no evidence of:
- a provider-aware cost model
- a billing-unit-aware cost model (tokens vs pages)
- server-side cost computation

---

## 6) Gaps vs your goal

Your goal requires distinguishing:
- OpenAI / LLM token usage
- Google Document AI / OCR usage (page/request based)
- Gemini usage (if present)
- and a future-proof ability to add providers

Current gaps:
1) **No provider/service fields** anywhere in `ai_usage_events` or in the admin summary RPC output.
2) The existing “AI usage” data model is **token-based only**.
3) **No OCR/page-based metrics** are stored or aggregated.
4) Instrumentation present in this repo writes to `usage_events`, while the “new” admin AI usage summary expects `ai_usage_events`.
5) No edge functions or backend provider-call sites exist in this repo, so provider-specific tracking likely needs to be added in:
   - the consumer app repo, and/or
   - backend functions/services that perform OCR/AI.

---

## 7) Safest fix (design recommendation — no changes applied)

This section describes the **safest** approach to meet the goal while preserving privacy and avoiding any weakening of auth/RLS/admin guards.

### Guiding principles
- Keep usage events **privacy-safe** (no prompts/outputs/OCR text/files).
- Keep Control Site reporting **aggregate-only**.
- Make the schema **provider- and billing-unit-aware**.
- Avoid breaking existing dashboards by introducing changes in an **additive** way.

### Recommended event model shape
Introduce a provider-aware usage event record with fields like:
- `provider` (e.g. `openai`, `google`)
- `service` (e.g. `llm`, `document_ai`, `ocr`)
- `model` (e.g. `gpt-4o`, `gemini-1.5-pro`, `document-ai-processor-x`)
- **billing units**:
  - `input_tokens`, `output_tokens`, `total_tokens` (for LLM)
  - `pages_processed` / `documents_processed` / `requests` (for OCR / Document AI)
- `estimated_cost`
- `feature_area` (existing)
- `result` + `error_code` (existing)

### Safest rollout sequence
1) **Additive schema**: extend `ai_usage_events` with nullable provider/service/unit columns (no drops).
2) Extend `admin_get_ai_usage_summary()` to return additional aggregates:
   - by provider
   - by service
   - by billing unit (tokens vs pages)
3) Update Flutter admin models/UI to show separate sections:
   - “LLM tokens”
   - “OCR / Document AI pages”
   - “Gemini usage” (if provider/service present)
4) Instrument actual AI call sites (likely outside this repo) to write usage events:
   - On OpenAI calls: write token counts + model + provider=openai
   - On Document AI/OCR: write pages/requests + provider=google + service=document_ai

### Important: privacy and logging
- Do not add any prompt/OCR/extracted-text fields.
- Ensure any logging is metadata-only (error codes, counts, coarse feature_area).

---

## 8) Direct answer to the question

**Is Google AI / Google Document AI / OCR usage being tracked separately from OpenAI/token-based usage?**

**No.** The current implementation:
- is token-focused
- has no provider/service dimension
- has no page/request counters
- and in this repo there is no Google AI / OCR instrumentation at all.
