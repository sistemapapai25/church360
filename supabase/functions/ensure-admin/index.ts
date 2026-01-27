// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function getBearerToken(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\\s+/i, "").trim();
  return token || null;
}

function normalizeEmails(raw: string | null | undefined): string[] {
  return String(raw || "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0);
}

async function upsertAdminAccess(supabaseAdmin: any, userId: string, tenantId: string | null) {
  if (!tenantId) return;
  await supabaseAdmin.from("user_access_level").upsert(
    {
      tenant_id: tenantId,
      user_id: userId,
      access_level: "admin",
      access_level_number: 5,
    },
    { onConflict: "tenant_id,user_id" }
  );
  await supabaseAdmin.from("user_tenant_membership").upsert(
    {
      tenant_id: tenantId,
      user_id: userId,
      access_level: "admin",
      access_level_number: 5,
      is_active: true,
    },
    { onConflict: "tenant_id,user_id" }
  );
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
    const tenantId =
      String(body.tenant_id || req.headers.get("x-tenant-id") || "").trim() ||
      null;
    if (!tenantId) {
      return new Response(JSON.stringify({ error: "Missing tenant_id" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const email = String(authData.user.email || "").toLowerCase();
    const allowedEmails = [
      ...normalizeEmails(Deno.env.get("ADMIN_EMAILS")),
      ...normalizeEmails(Deno.env.get("ADMIN_EMAIL")),
    ];
    const isWhitelisted = allowedEmails.length > 0 && allowedEmails.includes(email);

    const { data: account } = await supabaseAdmin
      .from("user_account")
      .select("role_global")
      .eq("id", authData.user.id)
      .maybeSingle();
    const roleGlobal = String(account?.role_global || "").toLowerCase();
    const isAlreadyAdmin = roleGlobal === "owner" || roleGlobal === "admin";

    if (!isAlreadyAdmin && !isWhitelisted) {
      return new Response(JSON.stringify({ error: "Access denied" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 403,
      });
    }

    await supabaseAdmin
      .from("user_account")
      .update({ role_global: roleGlobal === "owner" ? "owner" : "admin" })
      .eq("id", authData.user.id);

    try {
      await upsertAdminAccess(supabaseAdmin, authData.user.id, tenantId);
    } catch (e) {
      const msg = String((e as any)?.message || "");
      if (!msg.toLowerCase().includes("does not exist")) {
        console.error("ensure-admin upsert error:", e);
      }
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Failed";
    console.error("ensure-admin error:", error);
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
