# Relatorio de Validacao - Migracao Supabase

Data:
Origem:
Destino:

## Resumo
- Status geral:
- Data do cutover:
- Responsavel:

## Validacoes obrigatorias
### 1) Contagem de linhas
- [ ] Comparar contagem por tabela (origem vs destino).
- [ ] Divergencias registradas.

### 2) RLS e policies
- [ ] Usuario tenant A nao acessa dados do tenant B.
- [ ] Admin/roles especiais funcionam como esperado.

### 3) Funcoes e views
- [ ] RPCs criticas respondem.
- [ ] Views criticas retornam dados.

### 4) Storage
- [ ] Buckets recriados e com policies.
- [ ] Downloads assinados funcionando.

### 5) Edge Functions
- [ ] Deploy ok.
- [ ] Smoke tests ok (status 200 + payload esperado).

### 6) Aplicacao
- [ ] Login (novo Auth).
- [ ] Fluxos principais (financeiro, membros, cultos, etc.).

## Divergencias
- Tabela:
- Descricao:
- Impacto:
- Acao:

## Go/No-Go
- [ ] Aprovado para producao
- [ ] Nao aprovado (motivo):
