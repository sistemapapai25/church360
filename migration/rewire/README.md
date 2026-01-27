# Rewire Auth UIDs (Opcao B)

Arquivo: `migration/rewire/01_rewire_auth_uids.sql`

## Uso rapido
1) Preencha a tabela `public.migration_auth_uid_map` com o mapeamento old -> new.
2) Execute o script em modo preview (padrao, `p_apply := false`).
3) Consulte `public.migration_auth_uid_preview`.
4) Altere `p_apply` para `true` e rode novamente para aplicar.

## Observacoes
- Rodar como service_role/owner para bypass de RLS.
- Preview agora e persistente em `public.migration_auth_uid_preview` (tabela real).
- Fase 1 e Fase 2 sao controladas pelo mesmo `p_apply`.
- Fase 1 atualiza tabelas centrais (user_account/membership/roles) se existirem.
- Fase 2 faz update dinamico baseado em FKs + heuristica de colunas UUID.
- O script ignora schema `storage` por padrao (evita mexer em owner).
