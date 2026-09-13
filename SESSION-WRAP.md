# Session Wrap - Church360 Papai

Wrap timestamp: 2026-09-13 04:11:11 -03:00 (America/Sao_Paulo)

## Project

Main app repository:

`C:\Users\prber\projetos\AppsChurch360\Church360-Papai\app`

The shell session was opened from:

`C:\Users\prber\projetos\Church360 - Papai`

That outer directory is a separate repo. The Flutter app work happened in the app repo above.

## Summary

The approved web login redesign is deployed with Google Sign-In fully wired through Supabase Auth. After correcting the Google OAuth provider configuration, the user manually completed a real production login with a Google account, including the callback and final application access.

Production login URL:

`https://church360-app.vercel.app/login`

Depois do login Google, a intensidade visual dos itens não selecionados da
barra inferior foi ajustada para `1.0` para avaliação visual em produção.

Atualização desta sessão: a avaliação visual mostrou que o conjunto estava
infantilizado pelo uso de cores diferentes por item, glows intensos e pelo
efeito Pearl como linguagem principal. A interface foi migrada para a direção
“Soft Glass / Premium Blue / Aqua Tech”, com azul institucional, navy, aqua
discreto, slate neutro e superfícies claras.

## Changes Completed

- Kept the approved dark glass login design and existing email/password flows.
- Added a `Continuar com Google` button using Supabase OAuth.
- Added web redirect handling while preserving the optional destination route.
- Added native callback handling for Android and iOS:
  - Android scheme: `io.supabase.flutter://login-callback/`
  - iOS URL scheme: `io.supabase.flutter`
- Added auth-state handling for the native OAuth callback.
- Added post-login account synchronization for Google-created users:
  - tenant synchronization;
  - `ensure_my_account` RPC;
  - local account bootstrap.
- Updated the splash flow to prepare Google sessions before routing to the app.
- Kept the Google icon using the existing `font_awesome_flutter` dependency.
- Updated `SESSION-WRAP.md` with this final handoff state.
- Corrected the Supabase Google provider configuration: the saved Client Secret was an old value; it was replaced with the current secret belonging to the same Web OAuth Client ID.
- Ajustada a intensidade de repouso dos itens da barra inferior (Home, Bíblia, Igreja, Cursos e Mais) para `1.0`, temporariamente para avaliação visual.
- Publicada a alteração da barra inferior em produção pelo GitHub Actions/Vercel.
- Unificada a paleta global em azul premium: `#2563EB`, `#1E3A8A`,
  `#1F5E7A`, `#DBEAFE`, `#F8FAFC` e aqua `#7DD3FC` como detalhe.
- Substituído o item perolado da navegação inferior por um estado ativo em
  soft glass: item ativo azul, itens inativos slate e sem glow colorido.
- Alinhados os cinco itens da Home (Home, Bíblia, Igreja, Cursos e Mais) para
  a mesma cor ativa, preservando o ícone da logo e o avatar.
- Atualizados `PearlButton` e `PearlFab` para ações em azul com gradiente navy,
  sombra curta e discreta; cores específicas antigas dos FABs não competem
  mais com a identidade principal.
- Atualizados o CTA de contribuição da Home, os FABs da Comunidade e o botão
  flutuante de suporte para a mesma linguagem visual.
- Removido o violeta da atmosfera da tela de login e convertido o botão
  primário “Entrar” para azul institucional com texto branco.
- Commit local da alteração visual: `1db3f0e`.
- Deploy manual de produção concluído na Vercel: `dpl_52GzJ1HtcxWZSLJkssi2n4HCWUch`.

## OAuth Configuration

The Google OAuth client must be a Web application client. The following configuration was used:

Google Cloud authorized JavaScript origin:

`https://church360-app.vercel.app`

Google Cloud authorized redirect URI:

`https://heswheljavpcyspuicsi.supabase.co/auth/v1/callback`

Supabase Auth redirect URLs:

`https://church360-app.vercel.app/login`

`https://church360-app.vercel.app/login**`

`io.supabase.flutter://login-callback/`

The Supabase Google provider is enabled and the public Auth settings endpoint returned `external.google: true`. The current authorization endpoint also returns HTTP 302 to Google with the expected Web Client ID and Supabase callback.

## Problems And Resolutions

- The Google provider initially rejected `gl_readonly` because that is not an OAuth Client ID. The correct value is the Web Client ID ending in `.apps.googleusercontent.com`.
- Google initially returned `Error 400: redirect_uri_mismatch`. The fix was to register the Supabase Auth callback URL in Google Cloud, rather than the application login URL.
- The first real login reached the Google account selector but returned to the login screen with `AuthException: Unable to exchange external code`. The cause was the old Google Client Secret still saved in Supabase. Replacing it with the current secret for the same Web OAuth Client fixed the token exchange, and the user confirmed the login completed successfully.
- The local Vercel CLI was not authorized, so direct `vercel deploy` returned `Not authorized`. The repository GitHub Actions workflow was used instead and completed successfully.
- The local Flutter build first hit a sandbox permission issue writing to `build`. Running the repository deploy script with the required elevated access completed the local build. The authoritative production build/deploy ran successfully in GitHub Actions.
- The custom domain `https://app.church360.com.br/login` did not resolve from this environment during earlier validation. Production validation used `https://church360-app.vercel.app/login`.
- O primeiro deploy desta alteração retornou `Not authorized` porque a sessão
  local da Vercel havia perdido acesso ao time. O login por device foi
  repetido; após a liberação do usuário, o time `gabriels-projects-ec03504d`
  voltou a ficar acessível e o deploy foi concluído no projeto correto.
- A captura visual automatizada com `agent-browser` não pôde ser executada
  porque o executável não está instalado neste ambiente. O bundle local foi
  servido e capturado com Chrome headless; a tela permaneceu no splash durante
  a espera de bootstrap, mas todos os assets foram carregados com sucesso.

## Current State

Working:

- Email/password login and password reset.
- Approved glass login UI.
- Google Sign-In button on production.
- Google OAuth redirect through Supabase.
- Google account bootstrap and routing after authentication.
- Android and iOS deep-link callback configuration.
- Production deployment through GitHub Actions.
- Web Google Sign-In manually validated in production after the Client Secret correction.
- Barra inferior publicada em produção com intensidade de repouso `1.0` para avaliação visual.
- Tema, navegação inferior, FABs, CTA da Home, Comunidade e login atualizados
  para Soft Glass / Premium Blue.
- Deployment `dpl_52GzJ1HtcxWZSLJkssi2n4HCWUch` está `READY` e aliasado para
  `church360-app.vercel.app` e `app.church360.com.br`.

Known gaps:

- The custom domain DNS issue for `app.church360.com.br` remains unresolved from this environment.
- Native Android/iOS OAuth should still receive a device-level smoke test when those builds are available. The callback configuration is present and the Dart flow compiles.
- Automated browser validation was unavailable in this environment; the web OAuth flow was confirmed manually by the user in production.
- A validação manual da nova aparência pelo usuário ainda é necessária,
  especialmente Home em desktop/mobile, navegação inferior, Comunidade e
  telas com FAB estendido.
- `app.church360.com.br` continua sem resolução DNS neste ambiente; usar o
  alias `https://church360-app.vercel.app` para a validação imediata.

## Files Touched

Repository files in the Google Sign-In implementation:

- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/core/screens/splash_screen.dart`
- `lib/core/widgets/navigation/pearl_glass_dock.dart`
- `lib/core/widgets/navigation/custom_bottom_nav_bar.dart`
- `lib/core/widgets/pearl_button.dart`
- `lib/core/widgets/pearl_fab.dart`
- `lib/core/widgets/chat_fab.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/screens/home_screen.dart`
- `lib/features/community/presentation/screens/community_screen.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `SESSION-WRAP.md`

Earlier visual login work remains documented in the Git history and was not reverted.

## Verification Run

Commands and outcomes:

```powershell
flutter analyze
flutter test --no-pub --reporter compact
flutter test --no-pub test\widget_test.dart test\core\navigation\safe_redirect_test.dart
git diff --check
gh run list --branch main --limit 5 --json databaseId,name,status,conclusion,createdAt,headSha,url,displayTitle
curl.exe -L -s https://church360-app.vercel.app/main.dart.js?v=9e90922
curl.exe -L -s -D - https://church360-app.vercel.app/login -o NUL
```

Results:

- Changed-file analysis: no issues found.
- Full Flutter test suite: all tests passed, including the complete 333-test run.
- Targeted tests: all 11 tests passed.
- XML validation: Android manifest and iOS Info.plist valid.
- Git whitespace check: no errors.
- GitHub Actions deploy run `34738117986`: completed with `success`.
- Production bundle: contains `Abrindo Google` and `Continuar com Google`.
- Supabase public Auth settings: Google provider enabled.
- Local `flutter build web --release`: completed successfully; the Wasm dry run reported existing package incompatibilities, but the normal dart2js build succeeded.
- Production authorization endpoint check: HTTP 302 to Google with the expected Web Client ID and callback URL.
- Manual production smoke test after configuration correction: Google account selection completed, Supabase exchanged the external code, and the app opened successfully.
- Targeted tests after the navigation intensity change: all 11 tests passed.
- GitHub Actions deploy run `34742280757`: completed with `success` in 3m18s for commit `8a79a6b`.
- Production login endpoint after the navigation deploy: HTTP `200 OK`.

Verificações desta atualização visual:

```powershell
flutter analyze lib/core/theme/app_theme.dart lib/core/widgets/navigation/custom_bottom_nav_bar.dart lib/core/widgets/navigation/pearl_glass_dock.dart lib/core/widgets/pearl_button.dart lib/core/widgets/pearl_fab.dart lib/core/widgets/chat_fab.dart lib/core/screens/home_screen.dart lib/features/community/presentation/screens/community_screen.dart lib/features/auth/presentation/screens/login_screen.dart
flutter build web --release
curl.exe -I https://church360-app.vercel.app/login
vercel inspect https://church360-k0hxqbxfo-gabriels-projects-ec03504d.vercel.app --json
```

Resultados:

- `flutter analyze`: sem erros; apenas dois avisos informativos pré-existentes
  sobre chaves sem bloco em `home_screen.dart` e `pearl_fab.dart`.
- `flutter build web --release`: concluído; os avisos do dry-run Wasm são de
  dependências existentes (`audioplayers`/`image`) e não impedem o build dart2js.
- Alias de produção `/login`: HTTP `200 OK`.
- Deployment Vercel: `READY`, target `production`, com os aliases esperados.

The `agent-browser` executable was unavailable in this environment, so final production verification used the deployed bundle and the successful GitHub Actions result rather than an automated browser screenshot.

## Git State

Branch:

`main`

Current implementation commit:

`1db3f0e style: unifica interface em azul premium e soft glass`

Current branch before this wrap update:

`1db3f0e style: unifica interface em azul premium e soft glass`

Previous relevant commits:

- `7bf2987 docs: adiciona session wrap do login`
- `1c8f330 fix(auth): ajusta proporcao da logo no login`
- `3759636 feat(auth): redesenha tela de login web`

This wrap update is the next intentional documentation commit after `8a79a6b`.

Atualmente a branch `main` está `ahead 2` em relação a `origin/main`: os
commits locais `f872cfe` e `1db3f0e` ainda não foram enviados ao GitHub. O
deploy foi feito diretamente a partir do build local, portanto produção está
atualizada mesmo antes do push.

## Next Steps For The Next Chat

1. Start in `C:\Users\prber\projetos\AppsChurch360\Church360-Papai\app` and read this file completely before acting.
2. Run `git status -sb` and confirm the branch is clean after the wrap commit.
3. Reavaliar visualmente a nova linguagem em produção usando
   `https://church360-app.vercel.app`: Home desktop/mobile, navegação inferior,
   Comunidade, FABs e login.
4. Se o resultado visual for aprovado, enviar os commits locais para `origin`
   ou decidir conscientemente manter o deploy desacoplado do GitHub.
5. Keep the Google Cloud and Supabase redirect values documented above when adding new environments. Never replace the current Google Web Client Secret with an older credential.
6. For native release work, build and smoke-test the Android and iOS callback flow on physical or emulated devices.
7. Investigate `app.church360.com.br` DNS only if the custom domain is required.
8. Design backlog remains separate: PR #70 for CHU-356/M3 is still open and was not merged as part of this login work.
