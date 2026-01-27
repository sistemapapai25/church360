// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function sanitizeNumber(numero: string): string {
  const numeroLimpo = numero.replace(/\\D/g, "");
  return numeroLimpo.startsWith("55") ? numeroLimpo : `55${numeroLimpo}`;
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(value);
}

function ymdFromLocalNoon(ymd: string): Date {
  return new Date(`${ymd}T12:00:00`);
}

function toYmd(date: Date): string {
  return date.toISOString().split("T")[0];
}

function parseDiasLembrete(value: unknown): number[] {
  const fallback = [0, 1];
  if (!Array.isArray(value)) return fallback;
  const list = value
    .map((n) => (typeof n === "number" ? n : Number(n)))
    .filter((n) => Number.isFinite(n) && Number.isInteger(n) && n >= 0 && n <= 365) as number[];
  const unique = Array.from(new Set(list)).sort((a, b) => a - b);
  return unique.length > 0 ? unique : fallback;
}

async function getUazapiConfig(supabase: any) {
  let base = String(Deno.env.get("UAZAPI_BASE_URL") ?? "");
  let token = String(Deno.env.get("UAZAPI_TOKEN") ?? "");
  let path = String(Deno.env.get("UAZAPI_SEND_PATH") ?? "");
  if (!base || !token) {
    const { data: cfg } = await supabase
      .from("integration_settings")
      .select("base_url,instance_token,send_path")
      .eq("provider", "uazapi")
      .maybeSingle();
    base = String(cfg?.base_url ?? base ?? "");
    token = String(cfg?.instance_token ?? token ?? "");
    path = String(cfg?.send_path ?? path ?? "");
  }
  const cleanBase = base.replace(/\\/+$/, "");
  const cleanPath = path ? (path.startsWith("/") ? path : `/${path}`) : "/send/text";
  return { base: cleanBase, token, path: cleanPath };
}

async function enviarWhatsApp(supabase: any, numero: string, mensagem: string): Promise<boolean> {
  const { base, token, path } = await getUazapiConfig(supabase);
  if (!base || !token) {
    console.error("Uazapi credentials not configured");
    return false;
  }

  try {
    const numeroFormatado = sanitizeNumber(numero);
    const response = await fetch(`${base}${path}`, {
      method: "POST",
      headers: {
        token,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        number: numeroFormatado,
        text: mensagem,
      }),
    });
    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("Uazapi error:", response.status, errText);
      return false;
    }
    return true;
  } catch (error) {
    console.error("WhatsApp send error:", error);
    return false;
  }
}

function buildMessage(template: string, payload: Record<string, string>): string {
  let msg = template;
  for (const [key, value] of Object.entries(payload)) {
    msg = msg.replace(new RegExp(`\\{${key}\\}`, "g"), value);
  }
  return msg;
}

async function loadTemplates(supabase: any) {
  const templates: Record<string, { content: string; tenant_id?: string | null }> = {};
  const { data: msgTemplates, error: msgErr } = await supabase
    .from("message_template")
    .select("name,content,is_active,tenant_id")
    .eq("is_active", true);

  if (!msgErr && Array.isArray(msgTemplates)) {
    for (const t of msgTemplates) {
      const name = String(t.name || "").trim().toUpperCase();
      if (!name) continue;
      templates[name] = { content: String(t.content || ""), tenant_id: t.tenant_id ?? null };
    }
    return { templates, source: "message_template" };
  }

  const { data: cfgs, error: cfgErr } = await supabase
    .from("configuracao_mensagens")
    .select("*")
    .eq("ativo", true);

  if (!cfgErr && Array.isArray(cfgs)) {
    for (const c of cfgs) {
      const name = String(c.tipo || "").trim().toUpperCase();
      if (!name) continue;
      templates[name] = { content: String(c.template_mensagem || "") };
    }
  }

  return { templates, source: "configuracao_mensagens" };
}

function pickTemplate(
  templates: Record<string, { content: string; tenant_id?: string | null }>,
  key: string,
  tenantId?: string | null
) {
  const upper = key.toUpperCase();
  const direct = templates[upper];
  if (!direct) return null;
  if (!tenantId) return direct.content;
  if (direct.tenant_id == null || String(direct.tenant_id) === String(tenantId)) {
    return direct.content;
  }
  return direct.content;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!url || !serviceKey) {
      return new Response(JSON.stringify({ error: "Missing Supabase env vars" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(url, serviceKey);

    const agora = new Date();
    const dataHoje = toYmd(agora);
    const hojeNoon = ymdFromLocalNoon(dataHoje);

    let supportsLembreteDias = true;
    let desafiosCfg: any[] = [];

    const cfgWith = await supabase.from("desafios").select("id,lembrete_dias_antes").eq("ativo", true);
    if (!cfgWith.error) {
      desafiosCfg = (cfgWith.data as any[]) ?? [];
    } else if (
      String(cfgWith.error.message || "").includes("lembrete_dias_antes") &&
      String(cfgWith.error.message || "").includes("does not exist")
    ) {
      supportsLembreteDias = false;
      const cfgWithout = await supabase.from("desafios").select("id").eq("ativo", true);
      if (cfgWithout.error) {
        console.error("Error loading desafios:", cfgWithout.error);
        return new Response(JSON.stringify({ error: cfgWithout.error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      desafiosCfg = (cfgWithout.data as any[]) ?? [];
    } else {
      console.error("Error loading desafios config:", cfgWith.error);
      return new Response(JSON.stringify({ error: cfgWith.error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const offsetsAll = supportsLembreteDias
      ? (desafiosCfg || []).flatMap((d: any) => parseDiasLembrete(d?.lembrete_dias_antes))
      : [0, 1];
    const maxOffset = Math.min(Math.max(0, ...offsetsAll), 365);
    const datas = Array.from({ length: maxOffset + 1 }, (_, i) =>
      toYmd(new Date(hojeNoon.getTime() + i * 86400000))
    );

    const selectWith = `
      id,
      vencimento,
      valor,
      competencia,
      participante_id,
      desafio_participantes!inner (
        id,
        token_link,
        desafio_id,
        pessoa_id,
        pessoas!inner (
          id,
          nome,
          telefone
        ),
        desafios!inner (
          id,
          titulo,
          lembrete_dias_antes
        )
      )
    `;

    const selectWithout = `
      id,
      vencimento,
      valor,
      competencia,
      participante_id,
      desafio_participantes!inner (
        id,
        token_link,
        desafio_id,
        pessoa_id,
        pessoas!inner (
          id,
          nome,
          telefone
        ),
        desafios!inner (
          id,
          titulo
        )
      )
    `;

    const { data: parcelas, error: parcelasError } = await supabase
      .from("desafio_parcelas")
      .select(supportsLembreteDias ? selectWith : selectWithout)
      .in("vencimento", datas)
      .eq("status", "ABERTO")
      .is("pago_em", null);

    if (parcelasError) {
      console.error("Error loading parcelas:", parcelasError);
      return new Response(JSON.stringify({ error: parcelasError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { templates } = await loadTemplates(supabase);

    let enviados = 0;
    let falhas = 0;
    let pulados = 0;

    for (const parcela of parcelas || []) {
      const participante = parcela.desafio_participantes as any;
      const pessoa = participante?.pessoas;
      const desafio = participante?.desafios;

      if (!pessoa?.telefone) {
        pulados++;
        continue;
      }

      const diasLembrete = supportsLembreteDias ? parseDiasLembrete(desafio?.lembrete_dias_antes) : [0, 1];
      const vencNoon = ymdFromLocalNoon(parcela.vencimento);
      const diffDays = Math.round((vencNoon.getTime() - hojeNoon.getTime()) / 86400000);
      if (!diasLembrete.includes(diffDays)) {
        pulados++;
        continue;
      }

      const templateKey = diffDays === 0 ? "LEMBRETE_VENCIMENTO_HOJE" : "LEMBRETE_VENCIMENTO_AMANHA";
      const template = pickTemplate(templates, templateKey, participante?.tenant_id ?? desafio?.tenant_id);
      if (!template) {
        pulados++;
        continue;
      }

      const vencBr = vencNoon.toLocaleDateString("pt-BR");
      const payload = {
        nome: String(pessoa?.nome || "").split(" ")[0] || "",
        nome_completo: String(pessoa?.nome || ""),
        desafio: String(desafio?.titulo || ""),
        valor: formatCurrency(Number(parcela.valor || 0)),
        vencimento: vencBr,
        dias_restantes: String(diffDays),
      };

      const mensagem = buildMessage(template, payload);
      const enviado = await enviarWhatsApp(supabase, pessoa.telefone, mensagem);
      if (enviado) enviados++;
      else falhas++;

      await new Promise((resolve) => setTimeout(resolve, 300));
    }

    const resultado = {
      data_hoje: dataHoje,
      total_parcelas: parcelas?.length || 0,
      enviados,
      falhas,
      pulados,
      max_offset: maxOffset,
    };

    return new Response(JSON.stringify(resultado), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    console.error("desafio-lembrete-vencimento error:", error);
    const message = error instanceof Error ? error.message : "Internal error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
