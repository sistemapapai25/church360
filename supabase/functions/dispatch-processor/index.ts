// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
declare const Deno: any;
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function renderTemplate(template: string, job: any, supabase: any) {
  function escapeRegex(text: string): string {
    return String(text).replace(/[.*+?^${}()|[\]\\-]/g, '\\$&');
  }
  async function getEvent(id: string) {
    const { data } = await supabase.from("event").select("*").eq("id", id).maybeSingle();
    return data ?? null;
  }
  async function getUser(id: string) {
    const { data } = await supabase
      .from("user_account")
      .select("first_name,last_name,nickname,phone,birthdate")
      .eq("id", id)
      .maybeSingle();
    return data ?? null;
  }
  async function getMinistry(id: string) {
    const { data } = await supabase.from("ministry").select("name").eq("id", id).maybeSingle();
    return data ?? null;
  }
  async function getChurchInfo() {
    const { data } = await supabase.from("church_info").select("name,address").limit(1).maybeSingle();
    return data ?? null;
  }
  async function getFirstMinistryNameByEvent(eventId: string) {
    const { data: row } = await supabase
      .from("ministry_schedule")
      .select("ministry_id, ministry!fk_ministry_schedule_ministry (name)")
      .eq("event_id", eventId)
      .order("ministry_id")
      .limit(1)
      .maybeSingle();
    if (!row) return "";
    const m = row["ministry"];
    if (m && typeof m === "object") {
      const nm = String(m["name"] ?? "");
      if (nm) return nm;
    }
    const mid = String(row["ministry_id"] ?? "");
    if (!mid) return "";
    const mm = await getMinistry(mid);
    return String(mm?.name ?? "");
  }
  async function getEventLink(evId: string) {
    const { data: links } = await supabase
      .from("support_material_link")
      .select("material_id")
      .eq("link_type", "event")
      .eq("linked_entity_id", evId);
    const materialIds = (links ?? []).map((e: any) => String(e.material_id)).filter((s: string) => s.length > 0);
    if (materialIds.length === 0) return null;
    const { data: modules } = await supabase
      .from("support_material_module")
      .select("video_url,file_url")
      .in("material_id", materialIds)
      .order("order_index");
    for (const m of modules ?? []) {
      const v = String(m.video_url ?? "");
      if (v) return v;
      const f = String(m.file_url ?? "");
      if (f) return f;
    }
    return null;
  }

  async function resolve(name: string): Promise<string> {
    const payload = job.payload ?? {};
    const targetId = String(job.target_id ?? payload.event_id ?? "");
    const userId = String(payload.recipient_user_id ?? "");
    switch (name) {
      case "member_full_name": {
        const u = userId ? await getUser(userId) : null;
        const first = String(u?.first_name ?? "");
        const last = String(u?.last_name ?? "");
        const val = [first, last].filter(Boolean).join(" ");
        return val;
      }
      case "member_nickname": {
        const u = userId ? await getUser(userId) : null;
        return String(u?.nickname ?? "");
      }
      case "member_phone": {
        const fromPayload = String(payload.recipient_phone ?? "");
        if (fromPayload) return fromPayload;
        const u = userId ? await getUser(userId) : null;
        return String(u?.phone ?? "");
      }
      case "event_name": {
        const ev = targetId ? await getEvent(targetId) : null;
        return String(ev?.name ?? "");
      }
      case "event_date": {
        const ev = targetId ? await getEvent(targetId) : null;
        const iso = String(ev?.start_date ?? "");
        if (!iso) return "";
        const dt = new Date(iso);
        const dd = dt.toLocaleDateString("pt-BR");
        return dd;
      }
      case "event_time": {
        const ev = targetId ? await getEvent(targetId) : null;
        const iso = String(ev?.start_date ?? "");
        if (!iso) return "";
        const dt = new Date(iso);
        const hh = dt.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
        return hh;
      }
      case "event_location_address": {
        const ev = targetId ? await getEvent(targetId) : null;
        return String(ev?.location ?? "");
      }
      case "ministry_name": {
        const midPayload = String(payload.ministry_id ?? "");
        const midTarget =
          String(job.target_type ?? "") === "ministry" ? String(job.target_id ?? "") : "";
        const cfg = typeof payload.config === "object" ? payload.config : {};
        const midCfg = String(cfg?.group_ministry_id ?? "");
        const evId = String(job.target_id ?? payload.event_id ?? "");
        if (midPayload) {
          const m = await getMinistry(midPayload);
          return String(m?.name ?? "");
        }
        if (midTarget) {
          const m = await getMinistry(midTarget);
          return String(m?.name ?? "");
        }
        if (midCfg) {
          const m = await getMinistry(midCfg);
          return String(m?.name ?? "");
        }
        if (evId) {
          const nm = await getFirstMinistryNameByEvent(evId);
          return nm;
        }
        return "";
      }
      case "church_name": {
        const c = await getChurchInfo();
        return String(c?.name ?? "");
      }
      case "church_address": {
        const c = await getChurchInfo();
        return String(c?.address ?? "");
      }
      case "birthday_date": {
        const u = userId ? await getUser(userId) : null;
        const iso = String(u?.birthdate ?? "");
        if (!iso) return "";
        const datePart = iso.includes("T") ? iso.split("T")[0] : iso;
        const parts = datePart.split("-");
        if (parts.length < 3) return "";
        const dd = String(parts[2] ?? "").padStart(2, "0");
        const mm = String(parts[1] ?? "").padStart(2, "0");
        return `${dd}/${mm}`;
      }
      case "payment_date": {
        const iso = String(payload.payment_date ?? "");
        if (!iso) return "";
        const dt = new Date(iso);
        return dt.toLocaleDateString("pt-BR");
      }
      case "due_date": {
        const iso = String(payload.due_date ?? "");
        if (!iso) return "";
        const dt = new Date(iso);
        return dt.toLocaleDateString("pt-BR");
      }
      case "event_link": {
        const url = targetId ? await getEventLink(targetId) : null;
        return String(url ?? "");
      }
      default:
        return "";
    }
  }

  const regex = /\{([a-zA-Z0-9_]+)\}/g;
  const tokens = Array.from(template.matchAll(regex)).map((m) => m[1]);
  let out = template;
  for (const name of tokens) {
    const val = await resolve(name);
    const safe = escapeRegex(name);
    out = out.replace(new RegExp(`\\{${safe}\\}`, "g"), val);
  }
  return out;
}

async function processJobs(overrides?: { base?: string; token?: string }) {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(url, key);
  const now = new Date();
  const nowIso = now.toISOString();
  const { data: jobs } = await supabase
    .from("dispatch_job")
    .select("*")
    .in("status", ["pending", "failed"]) as any;

  let uazBase = String(overrides?.base ?? Deno.env.get("UAZAPI_BASE_URL") ?? "");
  let uazToken = String(overrides?.token ?? Deno.env.get("UAZAPI_TOKEN") ?? "");
  let sendPath = String(Deno.env.get("UAZAPI_SEND_PATH") ?? "");
  if (!uazBase || !uazToken) {
    const { data: cfg } = await supabase
      .from("integration_settings")
      .select("base_url,instance_token,send_path")
      .eq("provider", "uazapi")
      .maybeSingle();
    uazBase = String(cfg?.base_url ?? uazBase ?? "");
    uazToken = String(cfg?.instance_token ?? uazToken ?? "");
    sendPath = String(cfg?.send_path ?? sendPath ?? "");
  }
  const path = sendPath ? (sendPath.startsWith("/") ? sendPath : `/${sendPath}`) : "/send/text";

  let processed = 0;
  for (const job of jobs ?? []) {
    try {
      const scheduledAt = job.scheduled_at ? new Date(job.scheduled_at) : now;
      const retries = Number(job.retries ?? 0);
      const delayMinutes = Math.min(60, Math.pow(2, Math.max(0, retries)));
      const nextAllowed = new Date(scheduledAt.getTime() + delayMinutes * 60000);
      if (nextAllowed > now) continue;
      await supabase
        .from("dispatch_job")
        .update({ status: "processing" })
        .eq("id", job.id);
      const templateId = job.template_id ?? null;
      let text = "";
      if (templateId) {
        const { data: tmpl } = await supabase
          .from("message_template")
          .select("content")
          .eq("id", templateId)
          .single();
        text = await renderTemplate(String(tmpl?.content ?? ""), job, supabase);
      }
      const to = String(job.recipient_phone ?? "").trim();
      const number = to.includes("@g.us") ? to : to.replace(/[^0-9]/g, "");
      if (!number) {
        throw new Error("invalid_recipient_phone");
      }
      if (templateId && !String(text ?? "").trim()) {
        throw new Error("empty_rendered_template");
      }
      const resp = await fetch(`${uazBase}${path}`, {
        method: "POST",
        headers: {
          token: uazToken,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ number, text }),
      });
      if (!resp.ok) {
        let detail = `Uazapi ${resp.status}`;
        try {
          const errTxt = await resp.text();
          if (errTxt) detail = `${detail} · ${errTxt.substring(0, 300)}`;
        } catch (_) {}
        throw new Error(detail);
      }
      const body = await resp.json();
      const msgId = body?.id ?? body?.messageId ?? null;
      await supabase
        .from("dispatch_job")
        .update({ status: "sent", processed_at: nowIso, uazapi_message_id: msgId, last_error: null })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "sent", status: "sent", detail: "message_sent", payload: job.payload ?? {} });
      processed++;
    } catch (e) {
      const detail = e instanceof Error ? e.message : String(e);
      await supabase
        .from("dispatch_job")
        .update({ status: "failed", last_error: detail, retries: (job.retries ?? 0) + 1 })
        .eq("id", job.id);
      await supabase
        .from("dispatch_log")
        .insert({ job_id: job.id, action: "error", status: "failed", detail, payload: job.payload ?? {} });
    }
  }
  return { processed };
}

async function sendDirect(payload: any) {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(url, key);
  let uazBase = String(payload?.base ?? Deno.env.get("UAZAPI_BASE_URL") ?? "");
  let uazToken = String(payload?.token ?? Deno.env.get("UAZAPI_TOKEN") ?? "");
  let sendPath = String(payload?.path ?? Deno.env.get("UAZAPI_SEND_PATH") ?? "");
  if (!uazBase || !uazToken) {
    const { data: cfg } = await supabase
      .from("integration_settings")
      .select("base_url,instance_token,send_path")
      .eq("provider", "uazapi")
      .maybeSingle();
    uazBase = String(cfg?.base_url ?? uazBase ?? "");
    uazToken = String(cfg?.instance_token ?? uazToken ?? "");
    sendPath = String(cfg?.send_path ?? sendPath ?? "");
  }
  const base = String(uazBase ?? "").replace(/\/+$/, "");
  const raw = String(payload?.number ?? payload?.group ?? "").trim();
  const number = raw.includes("@g.us") ? raw : raw.replace(/[^0-9]/g, "");
  const text = String(payload?.text ?? "");
  const path = sendPath ? (sendPath.startsWith("/") ? sendPath : `/${sendPath}`) : "/send/text";
  if (!base || !uazToken || !number || !text) {
    return { ok: false, error: "missing_parameters" };
  }
  const resp = await fetch(`${base}${path}`, {
    method: "POST",
    headers: { token: uazToken, "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({ number, text }),
  });
  if (!resp.ok) {
    const errTxt = await resp.text();
    return { ok: false, error: `Uazapi ${resp.status} · ${errTxt.substring(0, 300)}` };
  }
  const body = await resp.json();
  const id = body?.id ?? body?.messageId ?? null;
  return { ok: true, id };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    if (req.method === "POST") {
      let payload: any = {};
      try {
        payload = await req.json();
      } catch (_) {}
      if (payload?.number || payload?.text) {
        const result = await sendDirect(payload);
        const status = result.ok ? 200 : 400;
        return new Response(JSON.stringify(result), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const result = await processJobs({ base: payload?.base, token: payload?.token });
      return new Response(JSON.stringify(result), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: detail }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
