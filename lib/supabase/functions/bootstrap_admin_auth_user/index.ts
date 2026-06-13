// supabase/functions/bootstrap_admin_auth_user/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type BootstrapRequest = {
  bootstrap_secret?: string;
  email?: string;
  password?: string;
  display_name?: string;
  role?: string;
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
}

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") return json(405, { success: false, error: "method_not_allowed" });

  try {
    const expectedSecret = Deno.env.get("BOOTSTRAP_SECRET") ?? "";
    if (!expectedSecret) return json(500, { success: false, error: "bootstrap_secret_not_configured" });

    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("application/json")) {
      return json(400, { success: false, error: "invalid_content_type" });
    }

    const payload = (await req.json()) as BootstrapRequest;

    const providedSecret = (payload.bootstrap_secret ?? "").trim();
    if (!providedSecret || providedSecret !== expectedSecret) {
      // Do not leak which part is wrong.
      return json(401, { success: false, error: "unauthorized" });
    }

    const email = normalizeEmail(payload.email ?? "");
    const password = payload.password ?? "";
    const displayName = (payload.display_name ?? "").trim();
    // Input role is accepted but we always persist owner per requirements.

    if (!email) return json(400, { success: false, error: "missing_email" });
    if (!password || password.length < 8) return json(400, { success: false, error: "weak_password" });
    if (!displayName) return json(400, { success: false, error: "missing_display_name" });

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) return json(500, { success: false, error: "server_not_configured" });

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });

    // 1) Create or update Auth user
    let authUserId: string | null = null;

    // Prefer getUserByEmail if available in your supabase-js build.
    let existingUserId: string | null = null;

    // @ts-ignore - method exists in supabase-js v2+ Admin API
    const getByEmail = adminClient.auth.admin.getUserByEmail?.bind(adminClient.auth.admin);
    if (getByEmail) {
      const { data, error } = await getByEmail(email);
      if (error) {
        return json(500, { success: false, error: "get_user_by_email_failed" });
      }
      existingUserId = data?.user?.id ?? null;
    } else {
      // Fallback: list users and search (works but less efficient). Keep for compatibility.
      const { data, error } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if (error) return json(500, { success: false, error: "list_users_failed" });
      const found = (data?.users ?? []).find((u: any) => (u?.email ?? "").toLowerCase() === email);
      existingUserId = found?.id ?? null;
    }

    if (existingUserId) {
      const { data, error } = await adminClient.auth.admin.updateUserById(existingUserId, {
        email,
        password,
        email_confirm: true,
        user_metadata: { display_name: displayName },
      });
      if (error) return json(500, { success: false, error: "update_user_failed" });
      authUserId = data.user.id;
    } else {
      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { display_name: displayName },
      });
      if (error) return json(500, { success: false, error: "create_user_failed" });
      authUserId = data.user.id;
    }

    if (!authUserId) return json(500, { success: false, error: "auth_user_id_missing" });

    // 4) Upsert public.admin_users (role ALWAYS owner)
    const { error: upsertError } = await adminClient
      .from("admin_users")
      .upsert(
        {
          admin_user_id: authUserId,
          email,
          display_name: displayName,
          role: "owner",
          is_active: true,
          require_step_up: false,
        },
        { onConflict: "admin_user_id" },
      );

    if (upsertError) {
      return json(500, { success: false, error: "admin_users_upsert_failed" });
    }

    // 5) Return minimal safe payload (no password, no tokens)
    return json(200, {
      success: true,
      auth_user_id: authUserId,
      role: "owner",
    });
  } catch (_e) {
    return json(500, { success: false, error: "unexpected_error" });
  }
});
