$ErrorActionPreference = "Stop"

$HOST_NAME = "aws-0-sa-east-1.pooler.supabase.com"
$PORT = 6543
$USER = "postgres.heswheljavpcyspuicsi"
$DB = "postgres"

Write-Host "🔒 Digite a senha do banco de dados para aplicar as correções:" -ForegroundColor Yellow
$PASSWORD = Read-Host -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PASSWORD)
$PLAIN_PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$env:PGPASSWORD = $PLAIN_PASSWORD

Write-Host "🔄 Executando correções de avós/netos (37_sync_grandparents.sql)..." -ForegroundColor Cyan
psql -h $HOST_NAME -p $PORT -U $USER -d $DB -f "backend-scripts/37_sync_grandparents.sql"

Write-Host "🛡️ Executando correções de segurança (38_fix_security_advisor_issues.sql)..." -ForegroundColor Cyan
psql -h $HOST_NAME -p $PORT -U $USER -d $DB -f "backend-scripts/38_fix_security_advisor_issues.sql"

Write-Host "✅ Tudo pronto! O banco de dados foi atualizado." -ForegroundColor Green
