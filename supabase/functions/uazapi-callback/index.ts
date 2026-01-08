/// <reference lib="dom" />
/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function getHeader(req: Request, name: string) {
  return req.headers.get(name) ?? req.headers.get(name.toLowerCase()) ?? "";
}

async function getExpectedSecret(supabase: any) {
  const env = Deno.env.get("UAZAPI_WEBHOOK_SECRET") || Deno.env.get("UAZAPI_WEBHOOK_TOKEN") || "";
  if (env) return env;
  try {
    const { data } = await supabase
      .from("integration_settings")
      .select("webhook_secret,api_token")
      .eq("provider", "uazapi")
      .maybeSingle();
    return String(data?.webhook_secret ?? data?.api_token ?? "");
  } catch (_) {
    return "";
  }
}

function extractMessageId(body: any): string {
  const candidates = [
    body?.messageId,
    body?.id,
    body?.message_id,
    body?.data?.id,
  ];
  for (const c of candidates) {
    if (c && String(c)) return String(c);
  }
  return "";
}

function normalize(body: any) {
  const status = String(body?.status ?? body?.event ?? "").toLowerCase();
  const delivered = status.includes("deliver") || Boolean(body?.delivered) || Boolean(body?.isDelivered);
  const ack = status.includes("read") || status.includes("ack") || Boolean(body?.read) || Boolean(body?.ack) || Boolean(body?.isRead);
  const failed = status.includes("fail") || status.includes("error") || Boolean(body?.error);
  const detail = body?.detail || body?.error || status || "";
  return { delivered, ack, failed, detail: String(detail) };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(url, key);

  let payload: any;
  try {
    payload = await req.json();
  } catch (_) {
    return new Response(JSON.stringify({ error: "invalid_json" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  const bearer = getHeader(req, "Authorization");
  const tokenHeader = getHeader(req, "X-Webhook-Token");
  const received = bearer.startsWith("Bearer ") ? bearer.substring(7) : tokenHeader;
  const expected = await getExpectedSecret(supabase);
  if (!expected || !received || received !== expected) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  const msgId = extractMessageId(payload);
  if (!msgId) {
    return new Response(JSON.stringify({ error: "missing_message_id" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  const { data: job } = await supabase
    .from("dispatch_job")
    .select("id,status,ack_received")
    .eq("uazapi_message_id", msgId)
    .maybeSingle();
  if (!job) {
    return new Response(JSON.stringify({ error: "job_not_found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  const norm = normalize(payload);
  const nowIso = new Date().toISOString();

  try {
    if (norm.failed) {
      await supabase
        .from("dispatch_job")
        .update({ status: "failed", last_error: norm.detail })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "error", status: "failed", detail: norm.detail, payload });
    }
    if (norm.delivered && String(job.status) !== "delivered") {
      await supabase
        .from("dispatch_job")
        .update({ status: "delivered" })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "delivered", status: "delivered", detail: "message_delivered", payload });
    }
    if (norm.ack && !Boolean(job.ack_received)) {
      await supabase
        .from("dispatch_job")
        .update({ ack_received: true, ack_received_at: nowIso })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "ack", status: "delivered", detail: "message_ack", payload });
    }
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: detail }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
