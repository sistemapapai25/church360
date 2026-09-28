# Rollout Google Play — com.papai.myapp

## Status atual (2026-09-28)

- Faixa **Teste fechado - Alpha** ativa no Play Console. Nome da faixa na Play Developer API: **`alpha`** (medido em 2026-09-28, não mais suposto — ver CI/CD abaixo).
- **versionCode 3** (1.0.0) construído e enviado em 2026-09-28, mas **NÃO publicado**: o commit da edição foi recusado pela Play Developer API (ver "Bloqueio: Advertising ID" abaixo). Ele é necessário pela CHU-374 — a partir da `app#178` os uploads de imagem gravam em `<tenant>/<auth uid>/`, e o versionCode 2 grava na raiz. O 2 passa a receber erro em todo upload assim que a migration `supabase#66` entrar, por isso o build novo tem que chegar à faixa **antes** dela.
- Faixas que existem hoje: `alpha` e `internal` (ambas tinham o versionCode 2), `beta` e `production` sem release.
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
- [ ] versionCode 3 na faixa `alpha` — build pronto, publicação bloqueada pela declaração de Advertising ID (2026-09-28, CHU-374)
- [ ] Declarar o uso de Advertising ID no Play Console (resposta correta: **não usa** — medido no bundle)
- [x] Lista de testadores criada e associada à faixa
- [x] Link de opt-in enviado
- [ ] Confirmar 12+ testadores com status "opted-in" no Play Console
- [ ] Aguardar 14 dias corridos mantendo os 12+
- [ ] Responder o questionário de teste fechado ("Visualizar perguntas")
- [ ] Solicitar acesso de produção

## Bloqueio: Advertising ID (2026-09-28)

A publicação do versionCode 3 falhou no **commit da edição** — o build e o upload do `.aab` passaram:

```
HttpError 400 ... edits/09095032070801028158:commit
"Your app targets Android 13 (API 33) or above.
 You must declare the use of advertising ID in Play Console."
```

É um formulário do Play Console, não um problema do app nem do CI: **Política → Conteúdo do app → ID de publicidade**.

**A resposta é "não usa", e isso está medido, não suposto.** Inspecionado o `AndroidManifest.xml` dentro do `.aab` que o CI gerou (`base/manifest/AndroidManifest.xml`): a permissão `com.google.android.gms.permission.AD_ID` **não está presente**. O manifest final declara só estas 10 permissões:

```
android.permission.ACCESS_NETWORK_STATE     android.permission.POST_NOTIFICATIONS
android.permission.BIND_JOB_SERVICE         android.permission.RECORD_AUDIO
android.permission.CAMERA                   android.permission.WAKE_LOCK
android.permission.DUMP                     com.google.android.c2dm.permission.RECEIVE
android.permission.INTERNET                 com.google.android.c2dm.permission.SEND
```

O `firebase_messaging` costuma arrastar a permissão pelo manifest merger, via `play-services-measurement`; nesta versão não arrastou.

Depois de declarar, basta rodar o workflow de novo com `publish_track=alpha`. O versionCode 3 **não foi consumido**: a edição não chegou a ser commitada, e a Play API descarta os bundles de uma edição abandonada. Se ainda assim vier erro de versionCode duplicado, suba para `+4`.

## Pendências relacionadas (fora do teste fechado)

- Ícone do app: já adicionado pelo usuário.
- Screenshots de loja: prontos em `app/store_assets/android/screenshots/` (phone + tablet), sem PII.
- Feature graphic (1024×500): pendente.
- Conta de teste real para o revisor da Apple: pendente.
- Build iOS (certificado + Mac/Xcode, ou acesso): pendente.

## CI/CD

`app/.github/workflows/android-release.yml` publica em `none | smoke_test | list_tracks | internal | alpha`. A promoção para a faixa de teste fechado **não é mais manual**: rode o workflow com `publish_track=alpha`.

**Antes de publicar, suba o versionCode.** O Play recusa versionCode repetido, e o erro só aparece no fim do build. É o `+N` do `version:` no `pubspec.yaml`.

**`list_tracks`**: lista as faixas que existem de verdade, com os releases de cada uma, e descarta a edição sem publicar nada. O nome de uma faixa de teste fechado não é adivinhável — o primeiro costuma ocupar `alpha`, mas faixas criadas depois têm nome próprio, e publicar na faixa errada é 404 no meio do commit da edição. Esta doc afirmava `alpha` como nome *provável*; em 2026-09-28 o `list_tracks` confirmou. Use-o sempre que a faixa mudar de nome ou uma nova for criada.

Cada execução leva ~10 min, quase tudo no build do .aab — inclusive no modo `list_tracks`, que só precisa do fim do job.
