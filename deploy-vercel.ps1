# Deploy do Church360 (Flutter Web) para a Vercel — app.church360.com.br
# Uso: pwsh .\deploy-vercel.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "==> Buildando Flutter web (release)..." -ForegroundColor Cyan
flutter build web --release

$webDir = Join-Path $root "build\web"
$vercelDir = Join-Path $webDir ".vercel"

if (-not (Test-Path $vercelDir)) {
    New-Item -ItemType Directory -Path $vercelDir | Out-Null
}

Write-Host "==> Restaurando link do projeto Vercel (apagado a cada build)..." -ForegroundColor Cyan
Copy-Item -Path (Join-Path $root ".vercel\project.json") -Destination (Join-Path $vercelDir "project.json") -Force

# LINK-02: NAO gerar vercel.json aqui. A config e versionada em `web\vercel.json` e o
# `flutter build web` a copia para `build\web\vercel.json`. Reescrever o arquivo aqui
# apaga os headers de Content-Type de `.well-known\` e quebra a verificacao de dominio.
#
# A copia abaixo NAO e uma segunda fonte de verdade — e uma garantia de entrega da unica
# fonte (`web\`). Motivo verificado em 2026-09-01: o cache incremental do build system do
# Flutter nao detecta ARQUIVOS NOVOS em `web\`. Num `build\` quente, `web\vercel.json` e
# `web\.well-known\` recem-criados NAO sao copiados e o arquivo antigo sobrevive. Na CI o
# checkout e limpo e o problema nao existe; aqui, na maquina do dev, existe.
Write-Host "==> Garantindo a config versionada e o .well-known em build\web..." -ForegroundColor Cyan
Copy-Item -Path (Join-Path $root "web\vercel.json") -Destination (Join-Path $webDir "vercel.json") -Force

$wellKnownDst = Join-Path $webDir ".well-known"
$wellKnownSrc = Join-Path $root "web\.well-known"
if (Test-Path $wellKnownDst) {
    Remove-Item -Path $wellKnownDst -Recurse -Force
}
if (Test-Path $wellKnownSrc) {
    Copy-Item -Path $wellKnownSrc -Destination $wellKnownDst -Recurse -Force
}

Write-Host "==> Deploy de producao na Vercel..." -ForegroundColor Cyan
Push-Location $webDir
try {
    vercel deploy --prod --yes
} finally {
    Pop-Location
}

Write-Host "==> Pronto: https://app.church360.com.br" -ForegroundColor Green
