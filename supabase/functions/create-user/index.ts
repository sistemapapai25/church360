// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ADMIN_PERMISSIONS = ["settings.manage_roles", "settings.manage_permissions"];

function normalizeRole(input: string | null | undefined): string {
  const raw = String(input || "").trim().toLowerCase();
  if (!raw) return "member";
  if (["owner", "admin", "leader", "member", "viewer"].includes(raw)) return raw;
  if (raw === "coordinator") return "leader";
  if (raw === "attendee" || raw === "visitor") return "viewer";
  return "member";
}

function mapAccessLevel(role: string, override?: string, overrideNumber?: number) {
  const roleMap: Record<string, { level: string; number: number }> = {
    owner: { level: "admin", number: 5 },
    admin: { level: "admin", number: 5 },
    coordinator: { level: "coordinator", number: 4 },
    leader: { level: "leader", number: 3 },
    member: { level: "member", number: 2 },
    attendee: { level: "attendee", number: 1 },
    visitor: { level: "visitor", number: 0 },
    viewer: { level: "visitor", number: 0 },
  };
  if (override && typeof override === "string") {
    const norm = override.trim().toLowerCase();
    const mapped = roleMap[norm];
    if (mapped) return mapped;
  }
  if (typeof overrideNumber === "number" && Number.isFinite(overrideNumber)) {
    const num = Math.max(0, Math.min(5, Math.floor(overrideNumber)));
    const byNum = {
      0: "visitor",
      1: "attendee",
      2: "member",
      3: "leader",
      4: "coordinator",
      5: "admin",
    } as const;
    return { level: byNum[num] || "visitor", number: num };
  }
  return roleMap[role] || roleMap.member;
}

function getBearerToken(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\\s+/i, "").trim();
  return token || null;
}

function isMissingRelation(err: any): boolean {
  const msg = String(err?.message || "");
  return msg.toLowerCase().includes("does not exist");
}

async function hasPermission(supabaseAdmin: any, userId: string, code: string): Promise<boolean | null> {
  const { data, error } = await supabaseAdmin.rpc("check_user_permission", {
    p_user_id: userId,
    p_permission_code: code,
  });
  if (error) {
    if (isMissingRelation(error)) return null;
    return null;
  }
  return Boolean(data);
}

async function hasAdminAccess(supabaseAdmin: any, userId: string, tenantId: string | null): Promise<boolean> {
  for (const code of ADMIN_PERMISSIONS) {
    const allowed = await hasPermission(supabaseAdmin, userId, code);
    if (allowed === true) return true;
  }

  if (tenantId) {
    const { data: utm, error: utmErr } = await supabaseAdmin
      .from("user_tenant_membership")
      .select("access_level_number,is_active")
      .eq("user_id", userId)
      .eq("tenant_id", tenantId)
      .maybeSingle();
    if (!utmErr && utm) {
      return Boolean(utm.is_active) && Number(utm.access_level_number || 0) >= 5;
    }
    if (utmErr && !isMissingRelation(utmErr)) {
      console.error("user_tenant_membership check error:", utmErr);
    }
  }

  if (tenantId) {
    const { data: ual, error: ualErr } = await supabaseAdmin
      .from("user_access_level")
      .select("access_level_number,tenant_id")
      .eq("user_id", userId)
      .eq("tenant_id", tenantId)
      .maybeSingle();
    if (!ualErr && ual) {
      return Number(ual.access_level_number || 0) >= 5;
    }
    if (ualErr && !String(ualErr.message || "").includes("tenant_id")) {
      if (!isMissingRelation(ualErr)) console.error("user_access_level check error:", ualErr);
    }
  }

  const { data: ualFallback, error: ualFallbackErr } = await supabaseAdmin
    .from("user_access_level")
    .select("access_level_number")
    .eq("user_id", userId)
    .maybeSingle();
  if (!ualFallbackErr && ualFallback) {
    return Number(ualFallback.access_level_number || 0) >= 5;
  }

  const { data: account, error: accountErr } = await supabaseAdmin
    .from("user_account")
    .select("role_global")
    .eq("id", userId)
    .maybeSingle();
  if (!accountErr && account) {
    const role = String(account.role_global || "").toLowerCase();
    return role === "owner" || role === "admin";
  }

  return false;
}

async function upsertUserAccount(supabaseAdmin: any, payload: Record<string, unknown>) {
  let attempt = { ...payload };
  let { error } = await supabaseAdmin.from("user_account").upsert(attempt, { onConflict: "id" });
  if (!error) return null;

  const msg = String(error?.message || "");
  if (msg.includes("tenant_id")) {
    delete attempt.tenant_id;
    ({ error } = await supabaseAdmin.from("user_account").upsert(attempt, { onConflict: "id" }));
  }
  if (!error && msg.includes("role_global")) {
    delete attempt.role_global;
    ({ error } = await supabaseAdmin.from("user_account").upsert(attempt, { onConflict: "id" }));
  }
  return error;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    const token = getBearerToken(authHeader);
    if (!token) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!url || !anonKey || !serviceKey) {
      return new Response(JSON.stringify({ error: "Missing Supabase env vars" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      });
    }

    const supabaseAuth = createClient(url, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const supabaseAdmin = createClient(url, serviceKey);

    const { data: authData, error: authErr } = await supabaseAuth.auth.getUser();
    if (authErr || !authData?.user) {
      return new Response(JSON.stringify({ error: "Invalid authentication" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const body = await req.json().catch(() => ({}));
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const fullName = String(body.full_name || body.name || "").trim() || email.split("@")[0];
    const tenantId =
      String(body.tenant_id || req.headers.get("x-tenant-id") || "").trim() ||
      null;

    if (!email || !password) {
      return new Response(JSON.stringify({ error: "Missing email or password" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }
    if (!tenantId) {
      return new Response(JSON.stringify({ error: "Missing tenant_id" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const requesterId = authData.user.id;
    const allowed = await hasAdminAccess(supabaseAdmin, requesterId, tenantId);
    if (!allowed) {
      return new Response(JSON.stringify({ error: "Access denied" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 403,
      });
    }

    const roleGlobal = normalizeRole(body.role || body.role_global || "member");
    const accessLevel = mapAccessLevel(roleGlobal, body.access_level, body.access_level_number);

    const { data: newAuth, error: newAuthErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (newAuthErr || !newAuth?.user) {
      return new Response(JSON.stringify({ error: newAuthErr?.message || "Failed to create user" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const userId = newAuth.user.id;
    const accountPayload = {
      id: userId,
      email,
      full_name: fullName,
      role_global: roleGlobal,
      is_active: true,
      tenant_id: tenantId,
    };
    const accountErr = await upsertUserAccount(supabaseAdmin, accountPayload);
    if (accountErr) {
      await supabaseAdmin.auth.admin.deleteUser(userId);
      return new Response(JSON.stringify({ error: accountErr.message || "Failed to create user_account" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    try {
      await supabaseAdmin
        .from("user_tenant_membership")
        .upsert(
          {
            tenant_id: tenantId,
            user_id: userId,
            access_level: accessLevel.level,
            access_level_number: accessLevel.number,
            is_active: true,
          },
          { onConflict: "tenant_id,user_id" }
        );
    } catch (e) {
      const msg = String((e as any)?.message || "");
      if (!msg.toLowerCase().includes("does not exist")) {
        console.error("user_tenant_membership upsert error:", e);
      }
    }

    try {
      await supabaseAdmin
        .from("user_access_level")
        .upsert(
          {
            tenant_id: tenantId,
            user_id: userId,
            access_level: accessLevel.level,
            access_level_number: accessLevel.number,
          },
          { onConflict: "tenant_id,user_id" }
        );
    } catch (e) {
      const msg = String((e as any)?.message || "");
      if (!msg.toLowerCase().includes("does not exist")) {
        console.error("user_access_level upsert error:", e);
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        user: {
          id: userId,
          email,
          full_name: fullName,
          role_global: roleGlobal,
          tenant_id: tenantId,
          access_level: accessLevel.level,
          access_level_number: accessLevel.number,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Failed";
    console.error("create-user error:", error);
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
