param(
  [string]$DbPasswordEnv = $env:SUPABASE_DB_PASSWORD
)

Write-Host "Church 360 - Corrigindo FK de ministry_member.user_id" -ForegroundColor Cyan

# Configuracoes do projeto
$PROJECT_HOST = "aws-0-sa-east-1.pooler.supabase.com"
$PROJECT_PORT = 6543
$PROJECT_DB   = "postgres"
$PROJECT_USER = "postgres.heswheljavpcyspuicsi"

# Obter senha
if ([string]::IsNullOrWhiteSpace($DbPasswordEnv)) {
  Write-Host "Senha nao encontrada em SUPABASE_DB_PASSWORD. Sera solicitada a seguir." -ForegroundColor Yellow
  $SecurePwd = Read-Host "Digite a senha do banco de dados" -AsSecureString
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePwd)
  $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
} else {
  $PlainPassword = $DbPasswordEnv
}

$CONNECTION_STRING = "postgresql://${PROJECT_USER}:${PlainPassword}@${PROJECT_HOST}:${PROJECT_PORT}/${PROJECT_DB}"

Write-Host "Executando 22_fix_user_account_fk.sql..." -ForegroundColor Green

$env:PGPASSWORD = $PlainPassword

# Localizar psql.exe instalado
$PSQL_PATH = $null
try {
  $PSQL_PATH = (Get-ChildItem 'C:\Program Files\PostgreSQL' -Recurse -Filter psql.exe | Select-Object -First 1 -ExpandProperty FullName)
} catch {}

if (-not $PSQL_PATH) {
  Write-Host "psql.exe não encontrado automaticamente. Tentando comando 'psql' do PATH..." -ForegroundColor Yellow
  & psql -h $PROJECT_HOST -p $PROJECT_PORT -U $PROJECT_USER -d $PROJECT_DB -f "22_fix_user_account_fk.sql"
} else {
  & $PSQL_PATH -h $PROJECT_HOST -p $PROJECT_PORT -U $PROJECT_USER -d $PROJECT_DB -f "22_fix_user_account_fk.sql"
}

if ($LASTEXITCODE -eq 0) {
  Write-Host "Correcao aplicada com sucesso!" -ForegroundColor Green
} else {
  Write-Host "Erro ao aplicar correcao (exit code: $LASTEXITCODE)" -ForegroundColor Red
}
