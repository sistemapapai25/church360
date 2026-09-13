# Session Wrap - Church360 Papai

Wrap timestamp: 2026-09-13 04:34:56 -03:00 (America/Sao_Paulo)

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

Atualização final desta sessão: a primeira onda da revisão de ícones foi
aplicada na navegação inferior. A barra agora usa uma linguagem outline única
nos quatro itens com glifo (`home_outlined`, `menu_book_outlined`,
`church_outlined` e `school_outlined`), com tamanho uniforme de 23px. A aba
Mais continua usando o avatar real do usuário e seu fallback de pessoa, pois
isso é mais semântico que substituir a personalização por um glifo genérico.
Essa alteração ainda não foi publicada em produção; o próximo agente deve
seguir o fluxo de branch → PR → merge em `main` → deploy → validação visual.

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
- Padronizada a primeira onda dos ícones da navegação inferior em estilo
  outline: Home (`home_outlined`), Bíblia (`menu_book_outlined`), Igreja
  (`church_outlined`) e Cursos (`school_outlined`).
- Removida a logo customizada como ícone da aba Igreja; a logo continua
  reservada para identidade visual em cabeçalhos e áreas de marca.
- Uniformizado o tamanho dos ícones simples da barra inferior para 23px;
  mantidos o azul ativo `#2563EB`, o slate inativo `#64748B` e o avatar da aba
  Mais.
- A alteração está na branch `feat/icon-navigation-outline-premium-blue` e
  precisa ser commitada, enviada para o GitHub, mesclada em `main` e
  publicada antes de ser considerada concluída.
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
- A primeira onda de ícones outline está implementada localmente na navegação
  inferior, mas ainda não está em produção.
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
- O deploy da nova navegação outline está pendente. Não anunciar a alteração
  como disponível em produção até confirmar PR mergeado, GitHub Actions/Vercel
  concluído e HTTP 200 no alias de produção.
- Após o deploy, validar visualmente Home em desktop e mobile, especialmente a
  espessura percebida dos glifos, o estado ativo azul, o estado inativo slate,
  o ícone Igreja e o avatar da aba Mais.

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

Verificações desta primeira onda de ícones:

```powershell
dart format lib/core/screens/home_screen.dart lib/core/widgets/navigation/custom_bottom_nav_bar.dart
flutter analyze lib/core/screens/home_screen.dart lib/core/widgets/navigation/custom_bottom_nav_bar.dart lib/core/widgets/navigation/pearl_glass_dock.dart
flutter test --no-pub test\\widget_test.dart test\\core\\navigation\\safe_redirect_test.dart
git diff --check
```

Resultados:

- `dart format`: 2 arquivos formatados; nenhuma alteração funcional adicional.
- `flutter analyze`: sem erros novos; permaneceu apenas o aviso pré-existente
  `curly_braces_in_flow_control_structures` em `home_screen.dart`.
- Testes direcionados: 11 testes passaram.
- `git diff --check`: sem erros de whitespace.
- Não foi executado deploy nem validação visual em produção desta onda.

## Git State

Branch:

`feat/icon-navigation-outline-premium-blue`

Current implementation commit:

`1db3f0e style: unifica interface em azul premium e soft glass`

Current branch before this wrap update:

`main` em `0bb2217`; a branch desta sessão foi criada a partir desse estado e
contém duas alterações de código ainda não commitadas no momento deste wrap.

Previous relevant commits:

- `7bf2987 docs: adiciona session wrap do login`
- `1c8f330 fix(auth): ajusta proporcao da logo no login`
- `3759636 feat(auth): redesenha tela de login web`

Este wrap será commitado junto com a primeira onda de ícones. Depois do commit,
atualizar esta seção com o hash final do commit e enviar a branch para o remoto.

Os commits `f872cfe`, `1db3f0e` e `9b656e7` foram enviados ao GitHub; a branch
`main` está sincronizada com `origin/main`. O deploy foi feito diretamente a
partir do build local, portanto produção foi atualizada antes do push.

## Next Steps For The Next Chat

1. Start in `C:\Users\prber\projetos\AppsChurch360\Church360-Papai\app` and read this file completely before acting.
2. Run `git status -sb` and confirm the branch/PR containing the outline icon
   change is available; do not push directly to `main`.
3. Finish the commit/push if still pending, open or inspect the PR, merge it into
   `main` according to the project rule, and wait for GitHub Actions/Vercel.
4. Confirm the production deployment succeeded and check
   `https://church360-app.vercel.app/login` (HTTP 200) plus the deployed bundle.
5. Reavaliar visualmente em produção Home desktop/mobile, principalmente a
   navegação inferior: Home, Bíblia, Igreja, Cursos e Mais.
6. Só depois do deploy considerar esta primeira onda concluída; então seguir
   para a próxima cascata de ícones inline (`edit_outlined`, `delete_outline`,
   `save_outlined`, `error_outline`, `chevron_right` etc.) conforme o inventário.
7. Keep the Google Cloud and Supabase redirect values documented above when adding new environments. Never replace the current Google Web Client Secret with an older credential.
8. For native release work, build and smoke-test the Android and iOS callback flow on physical or emulated devices.
9. Investigate `app.church360.com.br` DNS only if the custom domain is required.
10. Design backlog remains separate: PR #70 for CHU-356/M3 is still open and was not merged as part of this login work.
