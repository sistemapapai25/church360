# Integração Church360 ↔ PreacherLAB

**Status:** Desenho fechado (exploração), implementação adiada para v2 pós-lançamento.
**Última atualização:** 2026-08-12

## Contexto

O PreacherLAB é um produto separado (produção de sermões em apresentações PPTX), desenvolvido em outro repositório, com outro agente. O roadmap dele tinha uma linha sem detalhe — "SSO, cupom automático, plano premium" — apontando para uma integração com o Church360. Este documento registra o desenho que os dois lados fecharam antes de qualquer implementação.

## Relação de produto

Church360 e PreacherLAB são **produtos separados, vendidos independentemente**. Nenhum é módulo do outro. Um cliente pode ter só um, só o outro, ou os dois — quando tem os dois, ganha desconto cruzado.

## Arquitetura do Church360 relevante para a integração

- Um único projeto Supabase, multi-tenant: tabela `tenant` central, `user_tenant_membership` liga um `auth.users` a múltiplas igrejas com nível de acesso por tenant. (Não é "um banco por igreja" — isso está desatualizado no `README.md` do repo.)
- `public.jwt_tenant_id()` / `public.current_tenant_id()` resolvem o tenant ativo a partir do JWT/RLS. Ver `supabase/migrations/20260105000000_tenant_membership_jwt_context.sql` e `20260105000001_z_user_tenant_membership.sql` (caminhos relativos à raiz do projeto `Church360-Papai/`, fora deste repositório `app/`).
- O PreacherLAB roda em Supabase também, mas em **projeto separado** — não há SSO nativo entre projetos Supabase distintos, por isso o desenho de bridge abaixo.

## Desenho da integração

### 1) Vínculo de identidade

Por e-mail verificado entre as duas contas. Sem isso, não dá pra saber que é a mesma pessoa nos dois sistemas.

### 2) Bridge de login (SSO sob demanda)

Quando o usuário navega de um produto pro outro:

- O backend de **origem** emite um JWT curto, assinado com **HS256** e segredo compartilhado entre os dois backends (não exposto no client).
- **Claims:** `iss` (church360|preacherlab), `aud` (destino), `sub` (user_id na origem), `email`, `email_verified`, `plan` (tier atual, opcional/cache), `jti` (nonce de uso único), `iat`, `exp`.
- **TTL:** 2–5 minutos.
- **Transporte:** fragmento da URL (`#token=...`), não query param — o fragmento não vai pro `Referer` nem fica em log de servidor. O destino tem um script client-side que extrai o fragmento e faz `POST` pra um endpoint de backend, que valida assinatura, `exp`, `aud` e consome o `jti`.
- **Replay/nonce:** só quem **consome** o token audita — tabela local no destino (`bridge_jti_used(jti pk, consumed_at, expires_at)`), sem store compartilhado entre os dois backends. Quem emite não precisa rastrear nada.
- No destino: casa/cria a conta por e-mail e loga automaticamente via Admin API do Supabase.

### 3) Endpoint service-to-service de leitura de plano

- Cada produto expõe um endpoint autenticado por **chave de serviço** (não é rota de usuário): recebe `{email}`, devolve `{active: bool, tier, since}`.
- **Rate limit:** por chave de serviço (ex.: 60 req/min), não allowlist de IP — infra serverless costuma ter IP de saída dinâmico, allowlist de IP tende a quebrar sozinho.
- Usado tanto no bridge de login (pra popular a claim `plan`) quanto isoladamente no checkout, pra decidir o cupom.

### 4) Cupom cruzado

Restrição confirmada: a Hotmart (processador usado pelos dois produtos) não tem API para trocar plano de assinante ativo nem pular a confirmação do cliente — isso é estrutural de qualquer processador de pagamento.

Dois casos:

- **Cliente novo** (ainda não assinante do produto B, mas já ativo no produto A): no checkout de B, consulta o endpoint de leitura de plano de A por aquele e-mail; se ativo, usa o link de checkout do Hotmart com o preço já descontado. 100% automático.
- **Cliente existente** (já assinante de B, acabou de virar assinante de A): o webhook de "nova assinatura ativa" (que cada produto já recebe da Hotmart) consulta o plano do outro lado; se ativo, dispara **e-mail automatizado próprio** (não da Hotmart) com o link direto de troca de plano, usando a opção da Hotmart "troca liberada para o cliente" (self-service, sem produtor precisar convidar pessoa por pessoa). Zero trabalho manual do time — a única etapa humana é a confirmação do próprio cliente, inerente a qualquer mudança de cobrança.
- **Pré-requisito:** os planos com desconto cruzado precisam estar marcados como "troca liberada para o cliente" na Hotmart, nos dois produtos.
- A tela interna vira **log de auditoria** (quem foi notificado, se já trocou), não uma fila de ação pendente.

## Em aberto para quando entrar em planejamento técnico formal

- Percentual final do desconto cruzado (ex.: 10%/20%) — decisão de negócio, não travada.
- Rotação do segredo compartilhado do JWT de bridge.
- Schema exato da tabela `bridge_jti_used` e job de limpeza por TTL.
