import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import OpenAI from "npm:openai";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const AGENT_PROMPT_V2 = `'use client';

/** 
 * UNIVERSAL SUPPORT CHAT COMPONENT v2.0 — Prompt do Agente 
 * Uso: colar no system/user do agente do webhook backend. 
 * 
 * Tom: PT-BR, curto (3-5 frases/bullets), Markdown. Reconheça anexos na 1ª linha. 
 * Contexto: use cabeçalho recebido (Sistema/Usuário/Email/Página/Dados) para personalizar. 
 * Escalonamento: se usuário pedir falar com alguém acima ou após 2 tentativas sem resolver, 
 * incluir contato do suporte avançado: “Para suporte avançado (Gerente de Operações), 
 * fale pelo +55 11 99999-0000 ou peça transferência agora.” 
 */ 

Agente de Suporte — Regras: 
- Respeite digitação (grace 6s), delay mínimo 2s com “digitando...”, idle 60s libera resposta pendente. 
- Se resposta pronta e usuário digita >6s, envie aviso “vi que você está digitando...”. 
- Não auto-rolar se usuário está lendo acima; mostrar botão de “ver nova mensagem” (já no componente). 
- Reconheça anexos: “Recebi seu áudio/foto/arquivo”; se não abrir, peça descrição. 
- Estrutura de resposta: 1) reconhecimento + contexto, 2) ação imediata ou pergunta específica, 3) próximo passo ou confirmação, 4) se aplicável, opção de escalonamento. 
- Nunca prometa o que não pode fazer; seja transparente. 

Transferência entre agentes (experiência “transferido”): 
- Você pode sugerir transferência para outro agente quando perceber que o tema é de outra área. 
- Sugira no máximo 1–3 opções e sempre peça confirmação antes. 
- Só sugira agentes que existam em [AgentesDisponíveis] (se houver no contexto). 
- Se o usuário pedir um agente que não está em [AgentesDisponíveis], explique que não está disponível para o perfil. 
- Não diga que a transferência já aconteceu (evite “Transferindo você…”, “Já te transferi…”, “Aguarde enquanto transfiro…”). 
- Se o usuário confirmar (“sim”, “pode”, “quero a Mônica”), responda curto e inclua novamente a linha [[TRANSFER_SUGGEST]] para a UI renderizar o botão.
- Padrão de frase (use variações curtas e naturais):
  - “Posso te transferir para {NOME} ({ÁREA}) para resolver isso. Quer que eu transfira?”
  - “Esse ponto é mais de {ÁREA}. Posso chamar {NOME} ({ÁREA}) aqui?”
  - “Se você preferir, te transfiro para {NOME} ({ÁREA}) agora.”
- Para permitir que a UI mostre botões de transferência, quando sugerir, adicione no FINAL da resposta uma linha separada, exatamente assim:
[[TRANSFER_SUGGEST]]{"candidates":[{"key":"kids","name":"Mônica","reason":"assunto é infantil"}]}
- Não coloque texto após essa linha. Não use Markdown nessa linha. 
- Se não houver sugestão de transferência, não inclua a linha [[TRANSFER_SUGGEST]]. 

Processos do Sistema (resumidos para respostas): 
- Autenticação: login/signup/forgot (Supabase Auth). 
- Membros: listar/buscar, criar/editar, perfil com QR, completar cadastro, converter visitante. 
- Visitantes: listagem, estatísticas, visita e follow-up. 
- Grupos/Reuniões: CRUD grupo/reunião; visitantes em reunião. 
- Ministérios/Escala: CRUD ministério; auto-scheduler e regras; escala global (gerar, prévia, histórico). Se falhar, revisar contexts (funções, categorias, preferências) e candidatos. 
- Cultos: criar/editar, presença, estatísticas. 
- Eventos: criar/editar, inscrição pública, QR de ingresso, check-in manual/scan; tipos. 
- Agenda da igreja: compromissos. 
- Financeiro/Contribuição: contribuições, despesas, metas; recorrência; relatórios. 
- Relatórios prontos/custom: gerar/exportar; validar filtros e permissão. 
- Permissões/Contexts: papéis, contexts, catálogo, auditoria, permissões por usuário. 
- Comunidade: feed, posts/comentários/likes; admin view. 
- Devocionais: lista/detalhe com player YouTube, selo HOJE/LIDO, copiar referência, marcar lido; criar/editar. 
- Cursos/Estudos: CRUD curso/aula, viewer, lições. 
- Materiais: catálogo, módulos, viewer, uploads. 
- Planos/Bíblia: lista e leitor. 
- Home content: banners, quick news, depoimentos, pedidos de oração (home) CRUD. 
- Notícias, notificações, kids, church info, tags, analytics, QR scanner. 
- Diagnóstico rápido: conferir permissão; campos obrigatórios e datas; 401/403 → roles/RLS; 400 → payload; QR → \`EVENT_TICKET:eventId:memberId:ticketId\`; escala → contexts/candidatos. 

Cenários especiais: 
- Se mensagem for vaga (“Áudio enviado”, “Arquivo(s) enviado(s)”): pedir descrição do problema e do conteúdo do anexo. 
- Se o usuário solicitar alguém acima ou insistir sem solução: oferecer contato do suporte avançado (Gerente de Operações) +55 11 99999-0000.`;

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const requestId = crypto.randomUUID();
  const log = (event: string, data?: unknown) => 
    console.info(`[support][${requestId}] ${event}`, data ?? '');

  try {
    // Moved OpenAI init after resolving key
    
    // Parse multipart/form-data
    // Note: req.formData() handles multipart parsing automatically in Deno/Web Standard
    const formData = await req.formData();
    
    const message = formData.get('message') as string;
    const threadId = formData.get('threadId') as string | null;
    const contextStr = formData.get('context') as string | null;
    const agentKey = formData.get('agentKey') as string | null;

    if (!message) {
      return new Response(JSON.stringify({ error: 'Message is required', requestId }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Determine Assistant ID
    // Priority: 
    // 1. DB (agent_config table)
    // 2. Env Var (OPENAI_ASSISTANT_ID_{KEY})
    // 3. Env Var Default (OPENAI_ASSISTANT_ID)

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    const targetKey = agentKey ? agentKey.toLowerCase() : 'default';
    
    // Fetch from DB
    const { data: config } = await supabase
      .from('agent_config')
      .select('assistant_id, openai_api_key, display_name')
      .eq('key', targetKey)
      .maybeSingle();

    let assistantId = config?.assistant_id;
    let dynamicApiKey = config?.openai_api_key;
    const displayNameFromDb = (config as any)?.display_name?.toString?.().trim?.() ?? '';

    const extractAgentNameFromContext = (raw: string | null) => {
      if (!raw || raw.trim().length === 0) return '';
      try {
        const obj = JSON.parse(raw);
        if (!obj || typeof obj !== 'object') return '';
        const top =
          (obj.agentName ?? obj.agent_name ?? obj.agentDisplayName ?? obj.agent_display_name ?? '')
            ?.toString?.()
            ?.trim?.() ?? '';
        if (top) return top;
        const nested = (obj.agent && typeof obj.agent === 'object')
          ? ((obj.agent.name ?? obj.agent.displayName ?? obj.agent.display_name ?? '')?.toString?.().trim?.() ?? '')
          : '';
        return nested;
      } catch (_) {
        return '';
      }
    };

    const agentNameFromContext = extractAgentNameFromContext(contextStr);
    const effectiveAgentName = displayNameFromDb || agentNameFromContext || targetKey;

    // Resolve API Key
    // 1. DB (specific agent)
    // 2. Env Var (OPENAI_API_KEY)
    if (!dynamicApiKey) {
      dynamicApiKey = Deno.env.get('OPENAI_API_KEY');
    }

    if (!dynamicApiKey) {
      throw new Error('OPENAI_API_KEY is missing');
    }

    const openai = new OpenAI({ apiKey: dynamicApiKey });

    // Fallback to Env Vars for Assistant ID
    if (!assistantId) {
      if (targetKey !== 'default') {
        const envKey = `OPENAI_ASSISTANT_ID_${targetKey.toUpperCase()}`;
        assistantId = Deno.env.get(envKey);
      }
      
      // Final fallback to default env var
      if (!assistantId) {
        assistantId = Deno.env.get('OPENAI_ASSISTANT_ID');
      }
      
      log('agent_resolution', { targetKey, source: assistantId ? 'env' : 'none', assistantId });
    } else {
      log('agent_resolution', { targetKey, source: 'db', assistantId });
    }

    if (!assistantId) {
      throw new Error('Assistant ID not configured');
    }

    const isAudioFile = (f: File) => {
      const type = (f.type ?? '').toLowerCase();
      if (type.startsWith('audio/')) return true;
      const parts = (f.name ?? '').toLowerCase().split('.');
      const ext = parts.length > 1 ? parts[parts.length - 1] : '';
      return ['m4a', 'mp3', 'wav', 'ogg', 'aac'].includes(ext);
    };

    const clip = (s: string, max = 2500) => s.length > max ? `${s.slice(0, max)}…` : s;

    const bucket = (Deno.env.get('SUPPORT_CHAT_UPLOAD_BUCKET') ?? 'support-material-files').trim() || 'support-material-files';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabaseStorage = createClient(supabaseUrl, serviceRoleKey || supabaseAnonKey);

    const safePathSegment = (s: string) =>
      (s || 'file')
        .replaceAll('\\', '/')
        .split('/')
        .filter(Boolean)
        .join('_')
        .replaceAll(/[^a-zA-Z0-9._-]/g, '_')
        .slice(0, 180);

    const uploadToStorage = async (f: File) => {
      const name = safePathSegment(f.name || 'file');
      const path = `support-chat/${targetKey}/${requestId}/${name}`;
      try {
        const res = await supabaseStorage.storage
          .from(bucket)
          .upload(path, f, { contentType: f.type || undefined, upsert: true });
        if (res.error) {
          log('storage_upload_error', { bucket, path, message: res.error.message });
          return '';
        }
        const pub = supabaseStorage.storage.from(bucket).getPublicUrl(path);
        return pub.data.publicUrl || '';
      } catch (e: any) {
        log('storage_upload_error', { bucket, path, message: e?.message || String(e) });
        return '';
      }
    };

    // Collect files
    const files: File[] = [];
    for (const [key, value] of formData.entries()) {
      if (value instanceof File) {
        // Only accept fields named 'files' or 'files[]' or just collect all files
        if (key === 'files' || key.startsWith('files[')) {
          files.push(value);
        }
      }
    }

    const audioFiles = files.filter(isAudioFile);
    const nonAudioFiles = files.filter(f => !isAudioFile(f));

    const audioSummaries: string[] = [];
    for (const f of audioFiles) {
      log('audio_received', { name: f.name, size: f.size, type: f.type });
      let url = '';
      if (serviceRoleKey || supabaseAnonKey) {
        url = await uploadToStorage(f);
      }

      let transcript = '';
      try {
        const tr = await openai.audio.transcriptions.create({
          file: f,
          model: 'whisper-1',
        });
        transcript = (tr as any)?.text?.toString?.() ?? '';
      } catch (e: any) {
        log('audio_transcription_error', { name: f.name, message: e?.message || String(e) });
      }

      const parts: string[] = [];
      parts.push(`[Áudio: ${f.name}]`);
      if (url) parts.push(`URL: ${url}`);
      if (transcript.trim().length > 0) parts.push(`Transcrição: ${clip(transcript.trim())}`);
      audioSummaries.push(parts.join('\n'));
    }

    // 1) Upload files
    const fileIds: string[] = [];
    for (const f of nonAudioFiles) {
      log('file_upload', { name: f.name, size: f.size, type: f.type });
      
      // OpenAI expects a File-like object. Deno's File is compatible.
      const uploaded = await openai.files.create({
        file: f,
        purpose: 'assistants',
      });
      fileIds.push(uploaded.id);
    }

    // 2) Thread
    // If threadId is provided, try to retrieve it. If it fails (e.g. deleted), create new.
    let thread;
    if (threadId) {
      try {
        thread = await openai.beta.threads.retrieve(threadId);
        log('thread_reuse', { threadId: thread.id });
      } catch (e) {
        log('thread_not_found', { threadId });
        thread = await openai.beta.threads.create();
        log('thread_new_fallback', { threadId: thread.id });
      }
    } else {
      thread = await openai.beta.threads.create();
      log('thread_new', { threadId: thread.id });
    }

    // 3) User Message
    const formatContextHeader = (raw: string | null) => {
      if (!raw || raw.trim().length === 0) return '';
      try {
        const obj = JSON.parse(raw);
        if (obj && typeof obj === 'object') {
          const systemId = (obj.systemId ?? obj.system_id ?? obj.system ?? '').toString().trim();
          const userId = (obj.userId ?? obj.user_id ?? '').toString().trim();
          const userEmail = (obj.userEmail ?? obj.user_email ?? obj.email ?? '').toString().trim();
          const currentPage = (obj.currentPage ?? obj.current_page ?? obj.page ?? '').toString().trim();
          const agentName = (obj.agentName ?? obj.agent_name ?? obj.agentDisplayName ?? obj.agent_display_name ?? '').toString().trim();
          const agentsAvailable = Array.isArray((obj as any).agentsAvailable) ? (obj as any).agentsAvailable : [];
          const customData = obj.customData ?? obj.custom_data ?? obj.data;
          const lines: string[] = [];
          lines.push(`[Sistema: ${systemId || 'N/A'}]`);
          if (userId) lines.push(`[Usuário: ${userId}]`);
          if (userEmail) lines.push(`[Email: ${userEmail}]`);
          if (currentPage) lines.push(`[Página: ${currentPage}]`);
          if (agentName) lines.push(`[Agente: ${agentName}]`);
          if (agentsAvailable.length > 0) {
            const compact = agentsAvailable
              .map((a: any) => {
                const key = (a?.key ?? '').toString().trim();
                const name = (a?.name ?? '').toString().trim();
                const role = (a?.subtitle ?? a?.role ?? '').toString().trim();
                const id = [key, name].filter(Boolean).join(':');
                return role ? `${id} (${role})` : id;
              })
              .filter((s: string) => s.trim().length > 0)
              .slice(0, 25)
              .join('; ');
            if (compact) lines.push(`[AgentesDisponíveis: ${compact}]`);
          }
          if (customData != null) lines.push(`[Dados: ${JSON.stringify(customData)}]`);
          return `${lines.join('\n')}\n\n---\n\n`;
        }
      } catch (_) {}
      return `[CTX] ${raw}\n\n---\n\n`;
    };

    const contextHeader = formatContextHeader(contextStr);
    const audioHeader = audioSummaries.length > 0
      ? `Anexos de áudio recebidos:\n\n${audioSummaries.join('\n\n')}\n\n---\n\n`
      : '';
    await openai.beta.threads.messages.create(thread.id, {
      role: 'user',
      content: `${contextHeader}${audioHeader}${message}`,
      attachments: fileIds.length > 0
        ? fileIds.map(id => ({ file_id: id, tools: [{ type: 'file_search' }] }))
        : undefined,
    });

    // 4) Run
    const instructions = `${AGENT_PROMPT_V2}

Identidade do agente:
- Nome: ${effectiveAgentName}
- Chave: ${targetKey}

Regra adicional:
- Se o usuário perguntar seu nome, responda usando exatamente o Nome acima.`;

    const run = await openai.beta.threads.runs.create(thread.id, {
      assistant_id: assistantId,
      instructions,
    });

    // Polling
    const POLL_MS = 1000;
    const MAX_MS = 120_000; // 2 minutes timeout
    const started = Date.now();
    let status = run;

    const isPending = (s: string) => ['queued', 'in_progress', 'cancelling'].includes(s);

    while (isPending(status.status) && Date.now() - started < MAX_MS) {
      await new Promise(r => setTimeout(r, POLL_MS));
      status = await openai.beta.threads.runs.retrieve(run.id, { thread_id: thread.id });
    }

    if (isPending(status.status) || status.status !== 'completed') {
      log('run_failed_or_timeout', { status: status.status });
      
      // If failed, try to get error details from the run
      if (status.status === 'failed') {
        throw new Error(`Run failed: ${status.last_error?.message || 'Unknown error'}`);
      }
      throw new Error(`Run did not complete (Status: ${status.status})`);
    }

    // 5) Get Response
    const msgs = await openai.beta.threads.messages.list(thread.id);
    // The list is in reverse chronological order (newest first) by default
    const assistantMsg = msgs.data.find(m => m.role === 'assistant');
    
    let reply = 'Não consegui processar sua solicitação.';
    if (assistantMsg && assistantMsg.content && assistantMsg.content.length > 0) {
      const content = assistantMsg.content[0];
      if (content.type === 'text') {
        reply = content.text.value;
      }
    }

    return new Response(JSON.stringify({
      reply,
      threadId: thread.id,
      requestId,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (err: any) {
    log('error', err);
    return new Response(JSON.stringify({
      error: err?.message || 'Erro inesperado',
      requestId,
      details: {
        name: err?.name,
        code: err?.code,
        status: err?.status,
        type: err?.type,
      }
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
