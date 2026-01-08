// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
declare const Deno: any;
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function sanitizeNumber(raw: string): string {
  const to = String(raw ?? "").trim();
  if (!to) return "";
  return to.includes("@g.us") ? to : to.replace(/[^0-9]/g, "");
}

function computeNextRun(sendTime: string, tz: string): string {
  try {
    const now = new Date();
    const fmt = (n: number) => (n < 10 ? `0${n}` : `${n}`);
    const y = now.getUTCFullYear();
    const m = fmt(now.getUTCMonth() + 1);
    const d = fmt(now.getUTCDate());
    const localIso = `${y}-${m}-${d}T${sendTime}:00`;
    const target = new Date(localIso);
    // Se já passou hoje, vai para amanhã
    if (target.getTime() <= now.getTime()) {
      target.setUTCDate(target.getUTCDate() + 1);
    }
    return target.toISOString();
  } catch (_) {
    return new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  }
}

async function getRecipientsFromEvents(eventIds: string[], supabase: any): Promise<Array<{ userId: string; phone?: string }>> {
  if (!eventIds.length) return [];
  const { data: regs } = await supabase.from("event_registration").select("user_id").in("event_id", eventIds);
  const ids = (regs ?? []).map((r: any) => String(r.user_id ?? "")).filter((s: string) => s).filter((v, i, a) => a.indexOf(v) === i);
  if (!ids.length) return [];
  const { data: accounts } = await supabase.from("user_account").select("id,phone").in("id", ids);
  const byId: Record<string, string | undefined> = {};
  for (const a of accounts ?? []) byId[String(a.id)] = a.phone ? String(a.phone) : undefined;
  return ids.map((uid: string) => ({ userId: uid, phone: byId[uid] }));
}

async function getRecipientsFromMinistries(ministryIds: string[], supabase: any): Promise<Array<{ userId: string; phone?: string }>> {
  if (!ministryIds.length) return [];
  const { data: rows } = await supabase.from("ministry_member").select("user_id").in("ministry_id", ministryIds);
  const ids = (rows ?? []).map((r: any) => String(r.user_id ?? "")).filter((s: string) => s).filter((v, i, a) => a.indexOf(v) === i);
  if (!ids.length) return [];
  const { data: accounts } = await supabase.from("user_account").select("id,phone").in("id", ids);
  const byId: Record<string, string | undefined> = {};
  for (const a of accounts ?? []) byId[String(a.id)] = a.phone ? String(a.phone) : undefined;
  return ids.map((uid: string) => ({ userId: uid, phone: byId[uid] }));
}

async function createJobs(rule: any, targetType: string, targetId: string | null, recipients: Array<{ userId: string; phone?: string }>, supabase: any) {
  const sanitized: Array<{ userId: string; phone: string }> = [];
  for (const r of recipients) {
    const phone = sanitizeNumber(String(r.phone ?? ""));
    if (phone) sanitized.push({ userId: r.userId, phone });
  }
  if (!sanitized.length) return 0;
  const rows = sanitized.map((r) => ({
    rule_id: rule.id,
    template_id: rule.template_id,
    target_type: targetType,
    target_id: targetId,
    recipient_phone: r.phone,
    payload: {
      rule_type: String(rule.type ?? ""),
      config: rule.config ?? {},
      recipient_user_id: r.userId,
      recipient_phone: r.phone,
      event_id: targetType === "event" ? targetId : null,
    },
    attachments: [],
    status: "pending",
    requires_ack: false,
    ack_received: false,
    scheduled_at: new Date().toISOString(),
    retries: 0,
  }));
  const { error } = await supabase.from("dispatch_job").insert(rows);
  if (error) throw error;
  return rows.length;
}

async function processConfig(cfgRow: any, supabase: any): Promise<{ jobs: number }> {
  const { data: rule } = await supabase.from("dispatch_rule").select("*").eq("id", cfgRow.dispatch_rule_id).maybeSingle();
  if (!rule || !rule.template_id) return { jobs: 0 };
  const cfg = rule.config ?? {};
  const scope = String(cfg.target_scope ?? "all");
  const targetIds = Array.isArray(cfg.target_ids) ? cfg.target_ids.map(String) : [];
  const eventTypes = Array.isArray(cfg.event_types) ? cfg.event_types.map(String) : [];
  const recipientMode = String(cfg.recipient_mode ?? "multi");
  const singlePhone = String(cfg.single_phone ?? "");
  let groupPhone = String(cfg.group_phone ?? "");
  const groupMinistryId = String(cfg.group_ministry_id ?? "");
  const manualNumbers = Array.isArray(cfg.manual_numbers) ? cfg.manual_numbers.map(String) : [];

  let total = 0;
  if (scope === "event_type") {
    const { data: events } = await supabase.from("event").select("id,start_date").in("event_type", eventTypes);
    const evIds = (events ?? []).map((e: any) => String(e.id ?? "")).filter((s: string) => s);
    const recipients = await getRecipientsFromEvents(evIds, supabase);
    total += await createJobs(rule, "event", null, recipients, supabase);
  } else if (scope === "event") {
    const recipients = await getRecipientsFromEvents(targetIds, supabase);
    for (const evId of targetIds) {
      total += await createJobs(rule, "event", evId, recipients, supabase);
    }
  } else if (scope === "ministry") {
    const recipients = await getRecipientsFromMinistries(targetIds, supabase);
    total += await createJobs(rule, "ministry", null, recipients, supabase);
    if (recipientMode === "group") {
      if (!groupPhone && groupMinistryId) {
        const { data: m } = await supabase.from("ministry").select("whatsapp_group_number").eq("id", groupMinistryId).maybeSingle();
        groupPhone = String(m?.whatsapp_group_number ?? "");
      }
      const groupNum = sanitizeNumber(groupPhone);
      if (groupNum) {
        total += await createJobs(rule, "ministry", groupMinistryId || null, [{ userId: "group", phone: groupNum }], supabase);
      }
    }
  } else {
    if (recipientMode === "single") {
      const phone = sanitizeNumber(singlePhone);
      if (phone) total += await createJobs(rule, "all", null, [{ userId: "single", phone }], supabase);
    } else if (recipientMode === "group") {
      const phone = sanitizeNumber(groupPhone);
      if (phone) total += await createJobs(rule, "all", null, [{ userId: "group", phone }], supabase);
    } else if (recipientMode === "multi") {
      const rec = manualNumbers.map((n) => ({ userId: "manual", phone: sanitizeNumber(n) })).filter((r) => r.phone);
      total += await createJobs(rule, "all", null, rec, supabase);
    }
  }

  const next = computeNextRun(String(cfgRow.send_time ?? "08:00"), String(cfgRow.timezone ?? "America/Sao_Paulo"));
  await supabase
    .from("whatsapp_relatorios_automaticos")
    .update({ last_run: new Date().toISOString(), next_run: next })
    .eq("id", cfgRow.id);
  return { jobs: total };
}

async function runScheduler() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(url, key);

  const nowIso = new Date().toISOString();
  const { data: pending } = await supabase
    .from("whatsapp_relatorios_automaticos")
    .select("*")
    .eq("active", true)
    .lte("next_run", nowIso);

  let totalJobs = 0;
  for (const cfg of pending ?? []) {
    try {
      const { jobs } = await processConfig(cfg, supabase);
      totalJobs += jobs;
    } catch (e) {
      // Apenas avança o next_run para evitar loop
      const next = computeNextRun(String(cfg.send_time ?? "08:00"), String(cfg.timezone ?? "America/Sao_Paulo"));
      await supabase
        .from("whatsapp_relatorios_automaticos")
        .update({ last_run: new Date().toISOString(), next_run: next })
        .eq("id", cfg.id);
    }
  }
  return { ok: true, totalJobs, checked: (pending ?? []).length };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method === "POST") {
    const result = await runScheduler();
    return new Response(JSON.stringify(result), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
