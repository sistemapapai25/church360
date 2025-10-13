# ============================================
# Script PowerShell para executar SQL no Supabase
# ============================================

Write-Host "🚀 Church 360 - Executando Scripts SQL no Supabase" -ForegroundColor Cyan
Write-Host ""

# Carregar credenciais
$PROJECT_URL = "https://heswheljavpcyspuicsi.supabase.co"
$DB_URL = "postgresql://postgres.heswheljavpcyspuicsi:YOUR_PASSWORD@aws-0-sa-east-1.pooler.supabase.com:6543/postgres"

Write-Host "⚠️  IMPORTANTE: Você precisa da senha do banco de dados!" -ForegroundColor Yellow
Write-Host "Encontre em: Supabase Dashboard → Settings → Database → Connection String" -ForegroundColor Yellow
Write-Host ""

# Pedir senha
$DB_PASSWORD = Read-Host "Digite a senha do banco de dados" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DB_PASSWORD)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Construir connection string
$CONNECTION_STRING = "postgresql://postgres.heswheljavpcyspuicsi:$PlainPassword@aws-0-sa-east-1.pooler.supabase.com:6543/postgres"

Write-Host ""
Write-Host "📝 Executando 00_schema_base.sql..." -ForegroundColor Green

# Executar primeiro script
$env:PGPASSWORD = $PlainPassword
psql $CONNECTION_STRING -f "00_schema_base.sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Schema base criado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Executando 01_rls_policies.sql..." -ForegroundColor Green
    
    # Executar segundo script
    psql $CONNECTION_STRING -f "01_rls_policies.sql"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ RLS Policies criadas com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 BACKEND CONFIGURADO COM SUCESSO!" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Erro ao executar RLS policies" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Erro ao executar schema base" -ForegroundColor Red
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

