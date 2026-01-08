# ============================================
# Script PowerShell para executar SQL no Supabase
# ============================================

Write-Host "🚀 Church 360 - Executando Scripts SQL no Supabase" -ForegroundColor Cyan
Write-Host ""

# Carregar credenciais
$PROJECT_URL = "https://heswheljavpcyspuicsi.supabase.co"
$PROJECT_HOST = "aws-0-sa-east-1.pooler.supabase.com"
$PROJECT_PORT = 6543
$PROJECT_DB   = "postgres"
$PROJECT_USER = "postgres.heswheljavpcyspuicsi"

Write-Host "⚠️  IMPORTANTE: Você precisa da senha do banco de dados!" -ForegroundColor Yellow
Write-Host "Encontre em: Supabase Dashboard → Settings → Database → Connection String" -ForegroundColor Yellow
Write-Host ""

# Obter senha (SUPABASE_DB_PASSWORD se definido; senão, solicitar)
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
  $DB_PASSWORD = Read-Host "Digite a senha do banco de dados" -AsSecureString
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DB_PASSWORD)
  $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
} else {
  $PlainPassword = $env:SUPABASE_DB_PASSWORD
}

# Construir connection string
$CONNECTION_STRING = "postgresql://${PROJECT_USER}:${PlainPassword}@${PROJECT_HOST}:${PROJECT_PORT}/${PROJECT_DB}"

Write-Host ""
Write-Host "📝 Executando 00_schema_base.sql..." -ForegroundColor Green

# Executar primeiro script
$env:PGPASSWORD = $PlainPassword
psql -v ON_ERROR_STOP=1 $CONNECTION_STRING -f "00_schema_base.sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Schema base criado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Executando 03_worship_services.sql..." -ForegroundColor Green
    
    # Executar worship services
    psql -v ON_ERROR_STOP=1 $CONNECTION_STRING -f "03_worship_services.sql"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Worship services criados com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 Executando 09_financial.sql..." -ForegroundColor Green
        
        # Executar financeiro
        psql -v ON_ERROR_STOP=1 $CONNECTION_STRING -f "09_financial.sql"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Módulo financeiro criado com sucesso!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📝 Executando 20260101_add_tenant_columns_remaining.sql..." -ForegroundColor Green
            
            # Executar migração de tenant_id restante
            psql -v ON_ERROR_STOP=1 $CONNECTION_STRING -f "..\\supabase\\migrations\\20260101_add_tenant_columns_remaining.sql"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "🎉 BACKEND CONFIGURADO COM SUCESSO!" -ForegroundColor Cyan
            } else {
                Write-Host "❌ Erro ao executar 20260101_add_tenant_columns_remaining.sql" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Erro ao executar 09_financial.sql" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Erro ao executar 03_worship_services.sql" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Erro ao executar schema base" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Processo finalizado." -ForegroundColor Green
