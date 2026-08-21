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

$vercelJson = Join-Path $webDir "vercel.json"
@'
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
'@ | Set-Content -Path $vercelJson -Encoding UTF8

Write-Host "==> Deploy de producao na Vercel..." -ForegroundColor Cyan
Push-Location $webDir
try {
    vercel deploy --prod --yes
} finally {
    Pop-Location
}

Write-Host "==> Pronto: https://app.church360.com.br" -ForegroundColor Green
