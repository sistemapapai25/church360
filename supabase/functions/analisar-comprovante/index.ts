// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.2";
declare const Deno: { env: { get(name: string): string | undefined }; serve: (handler: (req: Request) => Response | Promise<Response>) => void };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function stripDiacritics(input: string): string {
  return input.normalize("NFD").replace(/[\\u0300-\\u036f]/g, "");
}

async function selectBeneficiaries(supabase: any, tenantId: string | null, userId: string | null) {
  if (tenantId) {
    const res = await supabase.from("beneficiaries").select("id,name").eq("tenant_id", tenantId);
    if (!res.error) return res.data ?? [];
    if (!String(res.error.message || "").includes("tenant_id")) throw res.error;
  }
  if (userId) {
    const resCreatedBy = await supabase.from("beneficiaries").select("id,name").eq("created_by", userId);
    if (!resCreatedBy.error) return resCreatedBy.data ?? [];
    if (!String(resCreatedBy.error.message || "").includes("created_by")) {
      throw resCreatedBy.error;
    }
    const resUserId = await supabase.from("beneficiaries").select("id,name").eq("user_id", userId);
    if (!resUserId.error) return resUserId.data ?? [];
  }
  const resAll = await supabase.from("beneficiaries").select("id,name").limit(200);
  if (resAll.error) throw resAll.error;
  return resAll.data ?? [];
}

async function selectRules(supabase: any, tenantId: string | null, userId: string | null) {
  if (tenantId) {
    const res = await supabase
      .from("classification_rules")
      .select("term,category_id,beneficiary_id")
      .eq("tenant_id", tenantId);
    if (!res.error) return res.data ?? [];
    if (!String(res.error.message || "").includes("tenant_id")) throw res.error;
  }
  if (userId) {
    const resCreatedBy = await supabase
      .from("classification_rules")
      .select("term,category_id,beneficiary_id")
      .eq("created_by", userId);
    if (!resCreatedBy.error) return resCreatedBy.data ?? [];
    if (!String(resCreatedBy.error.message || "").includes("created_by")) {
      throw resCreatedBy.error;
    }
    const resUserId = await supabase
      .from("classification_rules")
      .select("term,category_id,beneficiary_id")
      .eq("user_id", userId);
    if (!resUserId.error) return resUserId.data ?? [];
  }
  const resAll = await supabase.from("classification_rules").select("term,category_id,beneficiary_id").limit(200);
  if (resAll.error) throw resAll.error;
  return resAll.data ?? [];
}

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers: corsHeaders });
    }
    const { url, file_url, user_id, descricao, tenant_id } = await req.json();
    const srcUrl: string | undefined =
      (typeof file_url === "string" && file_url) || (typeof url === "string" && url) || undefined;
    const userId = typeof user_id === "string" ? user_id : null;
    if (!srcUrl || !userId) {
      return new Response(
        JSON.stringify({ success: false, error: "missing url/file_url or user_id" }),
        { status: 400, headers: { "content-type": "application/json", ...corsHeaders } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const lovableApiKey = Deno.env.get("LOVABLE_API_KEY");
    const supabase = createClient(supabaseUrl, serviceKey);

    let tenantId = typeof tenant_id === "string" && tenant_id ? tenant_id : null;
    if (!tenantId) {
      const headerTenant = req.headers.get("x-tenant-id");
      if (headerTenant) tenantId = headerTenant;
    }
    if (!tenantId) {
      const { data: ua } = await supabase.from("user_account").select("tenant_id").eq("id", userId).maybeSingle();
      if (ua?.tenant_id) tenantId = ua.tenant_id;
    }

    console.log("Analyzing comprovante:", srcUrl.substring(0, 100));

    const bens = await selectBeneficiaries(supabase, tenantId, userId);

    let aiResult: { recebedor_nome?: string; valor?: string; data?: string } | null = null;

    if (lovableApiKey) {
      try {
        const fileResponse = await fetch(srcUrl);
        if (fileResponse.ok) {
          const contentType = fileResponse.headers.get("content-type") || "";
          const arrayBuffer = await fileResponse.arrayBuffer();
          const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));

          let mediaType = "image/png";
          if (contentType.includes("pdf")) {
            mediaType = "application/pdf";
          } else if (contentType.includes("jpeg") || contentType.includes("jpg")) {
            mediaType = "image/jpeg";
          } else if (contentType.includes("png")) {
            mediaType = "image/png";
          } else if (contentType.includes("webp")) {
            mediaType = "image/webp";
          }

          const aiResponse = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${lovableApiKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "google/gemini-2.5-flash",
              messages: [
                {
                  role: "system",
                  content:
                    "You are an assistant that extracts payment receipt data (PIX, transfer, boleto). Return JSON only: {\"recebedor_nome\":\"...\",\"valor\":\"R$ 100,00\",\"data\":\"01/01/2025\"}. Use null if missing. If invalid, return {\"error\":\"not_valid_receipt\"}.",
                },
                {
                  role: "user",
                  content: [
                    { type: "image_url", image_url: { url: `data:${mediaType};base64,${base64}` } },
                    { type: "text", text: "Extract receiver name, amount, and date from this receipt." },
                  ],
                },
              ],
            }),
          });

          if (aiResponse.ok) {
            const aiData = await aiResponse.json();
            const content = aiData.choices?.[0]?.message?.content || "";
            const jsonMatch = content.match(/\\{[\\s\\S]*\\}/);
            if (jsonMatch) {
              try {
                aiResult = JSON.parse(jsonMatch[0]);
              } catch (parseErr) {
                console.error("Failed to parse AI JSON:", parseErr);
              }
            }
          } else {
            const errorText = await aiResponse.text();
            console.error("AI API error:", aiResponse.status, errorText);
          }
        }
      } catch (aiErr) {
        console.error("AI analysis error:", aiErr);
      }
    }

    let recebedor_id: string | undefined;
    let recebedor_nome = aiResult?.recebedor_nome;

    if (recebedor_nome && bens && bens.length > 0) {
      const normRecebedor = stripDiacritics(recebedor_nome).toLowerCase();
      const candidates = (bens as { id: string; name: string }[]).map((b) => ({
        id: b.id,
        name: b.name,
        n: stripDiacritics(b.name || "").toLowerCase(),
      }));

      let best: { id: string; name: string; n: string } | undefined;
      for (const c of candidates) {
        if (!c.n) continue;
        if (normRecebedor.includes(c.n) || c.n.includes(normRecebedor)) {
          if (!best || c.n.length > best.n.length) best = c;
        }
      }

      if (best) {
        recebedor_id = best.id;
        recebedor_nome = best.name;
      }
    }

    let sugestao: { categoria_id?: string | null; beneficiario_id?: string | null; motivo?: string } | null = null;

    const rules = await selectRules(supabase, tenantId, userId);
    const desc = (typeof descricao === "string" ? descricao : "").toLowerCase();
    const norm = stripDiacritics(`${recebedor_nome || ""} ${desc}`).toLowerCase();

    if (rules && norm) {
      type Rule = { term: string | null; category_id?: string | null; beneficiary_id?: string | null };
      const rs: Rule[] = Array.isArray(rules) ? (rules as Rule[]) : [];
      for (const r of rs) {
        const term = stripDiacritics(String(r.term || "")).toLowerCase();
        if (!term) continue;
        if (norm.includes(term)) {
          sugestao = {
            categoria_id: r.category_id || null,
            beneficiario_id: r.beneficiary_id || null,
            motivo: `term_match:${r.term}`,
          };
          break;
        }
      }
    }

    const result = {
      success: true,
      sugestao,
      recebedor_nome: recebedor_nome || null,
      beneficiario_id: recebedor_id ?? sugestao?.beneficiario_id ?? null,
      valor: aiResult?.valor || null,
      data: aiResult?.data || null,
      tenant_id: tenantId,
    };

    return new Response(JSON.stringify(result), {
      headers: { "content-type": "application/json", ...corsHeaders },
    });
  } catch (e) {
    console.error("Error in analisar-comprovante:", e);
    return new Response(
      JSON.stringify({ success: false, error: e instanceof Error ? e.message : String(e) }),
      { status: 500, headers: { "content-type": "application/json", ...corsHeaders } }
    );
  }
});
