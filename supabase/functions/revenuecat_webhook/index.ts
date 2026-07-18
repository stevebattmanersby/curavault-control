// Supabase Edge Function: revenuecat_webhook
//
// NOTE:
// This file mirrors `lib/supabase/functions/revenuecat_webhook/index.ts` so the
// function is deployable via the standard Supabase CLI path:
//   supabase/functions/<name>/index.ts
//
// Privacy/Security:
// - Never log PHI.
// - Never store raw payload unredacted.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-max-age": "86400",
};

function json(data: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS_HEADERS, ...headers },
  });
}

function getEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v || v.trim().length === 0) throw new Error(`Missing env var: ${name}`);
  return v;
}

function isUuidLike(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function safeStr(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length == 0 ? null : s;
}

function safeTs(v: unknown): string | null {
  const s = safeStr(v);
  if (!s) return null;
  const dt = new Date(s);
  if (Number.isNaN(dt.getTime())) return null;
  return dt.toISOString();
}

type AnyJson = Record<string, unknown>;

function redactPayload(payload: AnyJson): AnyJson {
  const e = (payload.event && typeof payload.event === "object") ? (payload.event as AnyJson) : payload;
  const out: AnyJson = {};
  const allowKeys = [
    "id",
    "event_id",
    "type",
    "event_type",
    "app_user_id",
    "original_app_user_id",
    "product_id",
    "entitlement_id",
    "entitlement_ids",
    "store",
    "environment",
    "period_type",
    "purchased_at_ms",
    "expiration_at_ms",
    "cancellation_at_ms",
    "purchased_at",
    "expiration_at",
    "cancellation_at",
    "is_trial_conversion",
  ];

  for (const k of allowKeys) {
    if (k in e) out[k] = e[k];
  }

  if (!("entitlement_ids" in out)) {
    const ids = (e.entitlement_ids as unknown);
    if (Array.isArray(ids)) out.entitlement_ids = ids.map((x) => String(x));
  }

  return { event: out };
}

function parseEvent(payload: AnyJson) {
  const e = (payload.event && typeof payload.event === "object") ? (payload.event as AnyJson) : payload;

  const revenuecatEventId = safeStr(e.id ?? e.event_id ?? payload.id ?? payload.event_id);
  const eventType = safeStr(e.type ?? e.event_type) ?? "UNKNOWN";

  const appUserIdRaw = safeStr(e.app_user_id ?? payload.app_user_id);
  const originalAppUserId = safeStr(e.original_app_user_id ?? payload.original_app_user_id);

  const productId = safeStr(e.product_id ?? payload.product_id);
  const entitlementId = safeStr(e.entitlement_id ?? payload.entitlement_id);

  const store = safeStr(e.store ?? payload.store);
  const environment = safeStr(e.environment ?? payload.environment);
  const periodType = safeStr(e.period_type ?? payload.period_type);

  const purchasedAt = safeTs(e.purchased_at ?? payload.purchased_at) ??
    (typeof e.purchased_at_ms === "number" ? new Date(e.purchased_at_ms).toISOString() : null);
  const expirationAt = safeTs(e.expiration_at ?? payload.expiration_at) ??
    (typeof e.expiration_at_ms === "number" ? new Date(e.expiration_at_ms).toISOString() : null);
  const cancellationAt = safeTs(e.cancellation_at ?? payload.cancellation_at) ??
    (typeof e.cancellation_at_ms === "number" ? new Date(e.cancellation_at_ms).toISOString() : null);

  const isTrialConversion = (e.is_trial_conversion === true) ? true : (e.is_trial_conversion === false ? false : null);

  const entitlementIds = (() => {
    const ids = e.entitlement_ids;
    if (Array.isArray(ids)) return ids.map((x) => String(x));
    if (entitlementId) return [entitlementId];
    return [];
  })();

  return {
    revenuecatEventId,
    eventType,
    appUserIdRaw,
    originalAppUserId,
    productId,
    entitlementId,
    entitlementIds,
    store,
    environment,
    periodType,
    purchasedAt,
    expirationAt,
    cancellationAt,
    isTrialConversion,
  };
}

function deriveStatus(eventType: string, expirationAt: string | null): string {
  const t = eventType.toUpperCase();
  if (t.includes("BILLING_ISSUE")) return "billing_issue";
  if (t.includes("CANCELLATION")) return "canceled";
  if (t.includes("EXPIRATION")) return "expired";
  if (t.includes("PAUSED")) return "paused";
  if (expirationAt) {
    const exp = new Date(expirationAt).getTime();
    if (!Number.isNaN(exp) && exp < Date.now()) return "expired";
  }
  if (
    t.includes("INITIAL_PURCHASE") || t.includes("RENEWAL") || t.includes("UNCANCELLATION") ||
    t.includes("PRODUCT_CHANGE") || t.includes("NON_RENEWING_PURCHASE")
  ) {
    return "active";
  }
  return "unknown";
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });

  if (req.method === "GET") {
    return json({ ok: true, name: "revenuecat_webhook", version: 1, time: new Date().toISOString() });
  }

  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  const secret = getEnv("REVENUECAT_WEBHOOK_SECRET");
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.toLowerCase().startsWith("bearer ") ? auth.substring(7).trim() : auth.trim();
  if (!token || token !== secret) return json({ ok: false, error: "unauthorized" }, 401);

  let payload: AnyJson;
  try {
    payload = await req.json();
    if (!payload || typeof payload !== "object") throw new Error("Payload is not an object");
  } catch (_e) {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const parsed = parseEvent(payload);
  if (!parsed.revenuecatEventId) return json({ ok: false, error: "missing_event_id" }, 400);

  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  try {
    const { data: existing, error: existingErr } = await supabase
      .from("revenuecat_webhook_events")
      .select("id, revenuecat_event_id, processed_at, processing_result")
      .eq("revenuecat_event_id", parsed.revenuecatEventId)
      .maybeSingle();
    if (existingErr) throw existingErr;
    if (existing) {
      return json({ ok: true, duplicate: true, revenuecat_event_id: parsed.revenuecatEventId, processed_at: existing.processed_at, processing_result: existing.processing_result });
    }
  } catch (_e) {
    return json({ ok: false, error: "backend_not_ready" }, 503);
  }

  const appUserId = (parsed.appUserIdRaw && isUuidLike(parsed.appUserIdRaw)) ? parsed.appUserIdRaw : null;
  const redacted = redactPayload(payload);

  const insertRow = {
    revenuecat_event_id: parsed.revenuecatEventId,
    app_user_id: appUserId,
    original_app_user_id: parsed.originalAppUserId,
    event_type: parsed.eventType,
    product_id: parsed.productId,
    entitlement_id: parsed.entitlementId,
    store: parsed.store,
    environment: parsed.environment,
    period_type: parsed.periodType,
    purchased_at: parsed.purchasedAt,
    expiration_at: parsed.expirationAt,
    cancellation_at: parsed.cancellationAt,
    is_trial_conversion: parsed.isTrialConversion,
    raw_event_redacted: redacted,
    created_at: new Date().toISOString(),
  };

  try {
    const { error: insErr } = await supabase.from("revenuecat_webhook_events").insert(insertRow);
    if (insErr) throw insErr;
  } catch (_e) {
    return json({ ok: true, duplicate: true, revenuecat_event_id: parsed.revenuecatEventId });
  }

  let processingResult = "ok";
  const processedAt = new Date().toISOString();

  try {
    try {
      await supabase.from("subscription_events").insert({
        user_id: appUserId,
        provider: "revenuecat",
        store: parsed.store,
        event_key: parsed.eventType,
        product_id: parsed.productId,
        entitlement_id: parsed.entitlementId,
        environment: parsed.environment,
        period_type: parsed.periodType,
        purchased_at: parsed.purchasedAt,
        expiration_at: parsed.expirationAt,
        created_at: processedAt,
      });
    } catch (_e) {
      processingResult = "warning:subscription_events_insert_failed";
    }

    if (appUserId) {
      const status = deriveStatus(parsed.eventType, parsed.expirationAt);
      const trialStart = parsed.periodType?.toLowerCase() === "trial" ? parsed.purchasedAt : null;
      const trialEnd = parsed.periodType?.toLowerCase() === "trial" ? parsed.expirationAt : null;
      const planKey = parsed.entitlementId ?? parsed.productId ?? "unknown";

      await supabase.from("user_entitlements").upsert({
        user_id: appUserId,
        plan_key: planKey,
        plan: planKey,
        status,
        subscription_status: status,
        provider: "revenuecat",
        source_platform: "revenuecat",
        store: parsed.store,
        revenuecat_app_user_id: parsed.appUserIdRaw,
        revenuecat_original_app_user_id: parsed.originalAppUserId,
        active_entitlement_ids: parsed.entitlementIds,
        product_id: parsed.productId,
        current_period_start: parsed.purchasedAt,
        current_period_end: parsed.expirationAt,
        trial_start: trialStart,
        trial_end: trialEnd,
        cancel_at_period_end: parsed.eventType.toUpperCase().includes("CANCELLATION"),
        latest_revenuecat_event_id: parsed.revenuecatEventId,
        updated_at: processedAt,
      }, { onConflict: "user_id" });
    } else {
      processingResult = "warning:unmapped_app_user_id";
    }
  } catch (_e) {
    processingResult = "error:processing_failed";
  }

  try {
    await supabase
      .from("revenuecat_webhook_events")
      .update({ processed_at: processedAt, processing_result: processingResult })
      .eq("revenuecat_event_id", parsed.revenuecatEventId);
  } catch (_e) {
    // Swallow: returning 200 prevents infinite RC retries.
  }

  return json({
    ok: processingResult === "ok" || processingResult.startsWith("warning:"),
    revenuecat_event_id: parsed.revenuecatEventId,
    app_user_id: appUserId,
    processing_result: processingResult,
  });
});
