# Rollout Google Play — com.papai.myapp

## Status atual (2026-09-04)

- Faixa **Teste fechado - Alpha** ativa no Play Console, versão 2 (1.0.0).
- Link de opt-in enviado para os testadores em **2026-09-04**.
- Testadores opt-in no momento: acompanhar no Play Console (Testar e lançar → Teste → Teste fechado - Alpha → Testadores).

## Requisito de acesso à produção

Política do Google Play para contas novas de desenvolvedor: antes de solicitar acesso de produção é obrigatório manter o teste fechado com:

- **Mínimo 12 testadores** opt-in (aceitaram o convite e instalaram pela Play Store).
- Por **14 dias corridos** contínuos.

**Data de início do relógio**: 2026-09-04 (dia do envio do link).
**Data mínima pra solicitar produção**: 2026-09-18 (14 dias depois), desde que os 12 testadores continuem opt-in nessa data.

## Checklist

- [x] Faixa de teste fechado criada e publicada (versionCode 2)
- [x] Lista de testadores criada e associada à faixa
- [x] Link de opt-in enviado
- [ ] Confirmar 12+ testadores com status "opted-in" no Play Console
- [ ] Aguardar 14 dias corridos mantendo os 12+
- [ ] Responder o questionário de teste fechado ("Visualizar perguntas")
- [ ] Solicitar acesso de produção

## Pendências relacionadas (fora do teste fechado)

- Ícone do app: já adicionado pelo usuário.
- Screenshots de loja: prontos em `app/store_assets/android/screenshots/` (phone + tablet), sem PII.
- Feature graphic (1024×500): pendente.
- Conta de teste real para o revisor da Apple: pendente.
- Build iOS (certificado + Mac/Xcode, ou acesso): pendente.

## CI/CD

`app/.github/workflows/android-release.yml` hoje só publica em `none | smoke_test | internal`. Para publicar direto nessa faixa de teste fechado pelo CI, falta adicionar a opção `alpha` (nome de faixa provável para o primeiro teste fechado criado no Play Console — confirmar no Console antes de usar). Até lá, promoção de versão pra essa faixa é manual pelo Play Console.
