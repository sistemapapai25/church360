// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
declare const Deno: any;
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function getUazapiCredentials(supabase: any) {
  let base = Deno.env.get("UAZAPI_BASE_URL") ?? "";
  let token = Deno.env.get("UAZAPI_TOKEN") ?? "";
  let statusPath = Deno.env.get("UAZAPI_STATUS_PATH") ?? "";
  if (!base || !token) {
    const { data: cfg } = await supabase
      .from("integration_settings")
      .select("base_url,instance_token,status_path")
      .eq("provider", "uazapi")
      .maybeSingle();
    base = String(cfg?.base_url ?? base ?? "");
    token = String(cfg?.instance_token ?? token ?? "");
    statusPath = String(cfg?.status_path ?? statusPath ?? "");
  }
  return { base, token, statusPath };
}

async function fetchStatus(uazBase: string, uazToken: string, statusPath: string) {
  try {
    const path = statusPath.startsWith("/") ? statusPath : `/${statusPath}`;
    const resp = await fetch(`${uazBase}${path}`, {
      method: "GET",
      headers: { token: uazToken, "Content-Type": "application/json" },
    });
    if (resp.ok) return await resp.json();
  } catch (_) {}
  return null;
}

function normalizeStatus(body: any) {
  const s = String(body?.status ?? "").toLowerCase();
  const delivered = s.includes("deliv") || Boolean(body?.delivered) || Boolean(body?.isDelivered);
  const ack = s.includes("ack") || s.includes("read") || Boolean(body?.ack) || Boolean(body?.isRead) || Boolean(body?.read);
  return { delivered, ack };
}

async function pollStatuses(override?: { statusPath?: string }) {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(url, key);
  const { base: uazBase, token: uazToken, statusPath } = await getUazapiCredentials(supabase);
  if (!uazBase || !uazToken) return { checked: 0, delivered: 0, acked: 0 };
  const path = String(override?.statusPath ?? statusPath ?? Deno.env.get("UAZAPI_STATUS_PATH") ?? "/instance/status");

  const { data: jobs } = await supabase
    .from("dispatch_job")
    .select("id,uazapi_message_id,status,processed_at,ack_received")
    .in("status", ["sent", "delivered"]) as any;

  let checked = 0;
  let delivered = 0;
  let acked = 0;
  for (const job of jobs ?? []) {
    const msgId = String(job.uazapi_message_id ?? "");
    if (!msgId) continue;
    const body = await fetchStatus(uazBase, uazToken, path);
    if (!body) continue;
    checked++;
    const st = normalizeStatus(body);
    const nowIso = new Date().toISOString();
    if (st.delivered && String(job.status) !== "delivered") {
      await supabase
        .from("dispatch_job")
        .update({ status: "delivered" })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "delivered", status: "delivered", detail: "message_delivered", payload: {} });
      delivered++;
    }
    if (st.ack && !Boolean(job.ack_received)) {
      await supabase
        .from("dispatch_job")
        .update({ ack_received: true, ack_received_at: nowIso })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "ack", status: "delivered", detail: "message_ack", payload: {} });
      acked++;
    }
  }
  return { checked, delivered, acked };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method === "POST") {
    let payload: any = {};
    try {
      payload = await req.json();
    } catch (_) {}
    const result = await pollStatuses({ statusPath: payload?.path ?? payload?.statusPath });
    return new Response(JSON.stringify(result), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
