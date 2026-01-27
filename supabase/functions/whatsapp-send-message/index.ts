// @ts-nocheck
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface RequestBody {
  numero?: string;
  mensagem?: string;
  number?: string;
  text?: string;
}

function sanitizeNumber(numero: string): string {
  const numeroLimpo = numero.replace(/\\D/g, "");
  return numeroLimpo.startsWith("55") ? numeroLimpo : `55${numeroLimpo}`;
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
  const cleanPath = path
    ? path.startsWith("/") ? path : `/${path}`
    : "/send/text";
  return { base: cleanBase, token, path: cleanPath };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!url || !serviceKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase env vars" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const supabase = createClient(url, serviceKey);

    const body: RequestBody = await req.json();
    const numero = String(body.numero || body.number || "").trim();
    const mensagem = String(body.mensagem || body.text || "").trim();

    if (!numero || !mensagem) {
      return new Response(
        JSON.stringify({ error: "Missing numero/number or mensagem/text" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { base, token, path } = await getUazapiConfig(supabase);
    if (!base || !token) {
      return new Response(
        JSON.stringify({ error: "WhatsApp config not found" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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

    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      return new Response(
        JSON.stringify({ error: "Failed to send message", details: result }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ ok: true, result }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
