# Session Wrap - Church360 Papai

Wrap timestamp: 2026-09-13 02:33:20 -03:00 (America/Sao_Paulo)

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

Known gaps:

- The custom domain DNS issue for `app.church360.com.br` remains unresolved from this environment.
- Native Android/iOS OAuth should still receive a device-level smoke test when those builds are available. The callback configuration is present and the Dart flow compiles.
- Automated browser validation was unavailable in this environment; the web OAuth flow was confirmed manually by the user in production.

## Files Touched

Repository files in the Google Sign-In implementation:

- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/core/screens/splash_screen.dart`
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

The `agent-browser` executable was unavailable in this environment, so final production verification used the deployed bundle and the successful GitHub Actions result rather than an automated browser screenshot.

## Git State

Branch:

`main`

Current implementation commit:

`9e90922 feat: adiciona login com Google`

Current branch before this wrap update:

`b648d93 docs: atualiza wrap do Google Sign-In`

Previous relevant commits:

- `7bf2987 docs: adiciona session wrap do login`
- `1c8f330 fix(auth): ajusta proporcao da logo no login`
- `3759636 feat(auth): redesenha tela de login web`

This wrap update is the next intentional documentation commit after `b648d93`.

## Next Steps For The Next Chat

1. Start in `C:\Users\prber\projetos\AppsChurch360\Church360-Papai\app` and read this file completely before acting.
2. Run `git status -sb` and confirm the branch is clean after the wrap commit.
3. Keep the Google Cloud and Supabase redirect values documented above when adding new environments. Never replace the current Google Web Client Secret with an older credential.
4. For native release work, build and smoke-test the Android and iOS callback flow on physical or emulated devices.
5. Investigate `app.church360.com.br` DNS only if the custom domain is required.
6. Design backlog remains separate: PR #70 for CHU-356/M3 is still open and was not merged as part of this login work.
