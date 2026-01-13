param(
  [string]$DbPasswordEnv = $env:SUPABASE_DB_PASSWORD,
  [ValidateSet("both", "hebrew", "greek")]
  [string]$Languages = "both",
  [string]$OutDir = "",
  [switch]$SkipDb
)

Write-Host "Church 360 - Importando léxico Strong (STEPBible TBESH/TBESG)" -ForegroundColor Cyan

$PROJECT_HOST = "aws-0-sa-east-1.pooler.supabase.com"
$PROJECT_PORT = 6543
$PROJECT_DB   = "postgres"
$PROJECT_USER = "postgres.heswheljavpcyspuicsi"

$urls = @{
  greek  = "https://raw.githubusercontent.com/STEPBible/STEPBible-Data/master/Lexicons/TBESG%20-%20Translators%20Brief%20lexicon%20of%20Extended%20Strongs%20for%20Greek%20-%20STEPBible.org%20CC%20BY.txt"
  hebrew = "https://raw.githubusercontent.com/STEPBible/STEPBible-Data/master/Lexicons/TBESH%20-%20Translators%20Brief%20lexicon%20of%20Extended%20Strongs%20for%20Hebrew%20-%20STEPBible.org%20CC%20BY.txt"
}

$workDir = Join-Path $env:TEMP "church360_stepbible_lexicon"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

function Get-DataLines {
  param(
    [string]$FilePath,
    [string]$Prefix
  )

  return Get-Content -LiteralPath $FilePath -Encoding UTF8
}

function Parse-LexiconFile {
  param(
    [string]$FilePath,
    [string]$Language,
    [string]$Prefix
  )

  $records = New-Object 'System.Collections.Generic.Dictionary[string,object]'
  $dataLines = Get-DataLines -FilePath $FilePath -Prefix $Prefix

  foreach ($line in $dataLines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $clean = $line.TrimStart()
    if ($clean -notmatch "^$Prefix\d{4,5}") { continue }
    if ($clean -notmatch "`t") { continue }

    $cols = $clean -split "`t"
    if ($cols.Length -lt 5) { continue }

    $strongCode = [string]$cols[0]
    $strongCode = $strongCode.Trim()
    if ([string]::IsNullOrWhiteSpace($strongCode)) { continue }

    $lemma = [string]$cols[3]
    $transliteration = [string]$cols[4]

    $key = "$Language|$strongCode".ToUpperInvariant()
    if (-not $records.ContainsKey($key)) {
      $records[$key] = [PSCustomObject]@{
        strong_code      = $strongCode
        language         = $Language
        lemma            = $lemma.Trim()
        transliteration  = $transliteration.Trim()
      }
      continue
    }

    $existing = $records[$key]
    $newLemma = $lemma.Trim()
    $newTranslit = $transliteration.Trim()

    if ([string]::IsNullOrWhiteSpace($existing.lemma) -and -not [string]::IsNullOrWhiteSpace($newLemma)) {
      $existing.lemma = $newLemma
    }
    if ([string]::IsNullOrWhiteSpace($existing.transliteration) -and -not [string]::IsNullOrWhiteSpace($newTranslit)) {
      $existing.transliteration = $newTranslit
    }
  }

  return $records.Values
}

function Download-IfNeeded {
  param(
    [string]$Uri,
    [string]$OutFile
  )
  if (Test-Path -LiteralPath $OutFile) { return }
  Write-Host "Baixando: $Uri" -ForegroundColor Green
  Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing | Out-Null
}

$all = New-Object System.Collections.Generic.List[object]

if ($Languages -eq "both" -or $Languages -eq "greek") {
  $greekPath = Join-Path $workDir "TBESG.txt"
  Download-IfNeeded -Uri $urls.greek -OutFile $greekPath
  $greekRecords = Parse-LexiconFile -FilePath $greekPath -Language "greek" -Prefix "G"
  foreach ($r in $greekRecords) { $all.Add($r) }
  Write-Host ("Registros gregos: {0}" -f $greekRecords.Count) -ForegroundColor DarkCyan
}

if ($Languages -eq "both" -or $Languages -eq "hebrew") {
  $hebrewPath = Join-Path $workDir "TBESH.txt"
  Download-IfNeeded -Uri $urls.hebrew -OutFile $hebrewPath
  $hebrewRecords = Parse-LexiconFile -FilePath $hebrewPath -Language "hebrew" -Prefix "H"
  foreach ($r in $hebrewRecords) { $all.Add($r) }
  Write-Host ("Registros hebraicos: {0}" -f $hebrewRecords.Count) -ForegroundColor DarkCyan
}

$exportDir = $workDir
if (-not [string]::IsNullOrWhiteSpace($OutDir)) {
  $exportDir = $OutDir
}
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

$csvPath = Join-Path $exportDir "bible_lexeme_base_import.csv"
$all | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "CSV gerado: $csvPath" -ForegroundColor Green
Write-Host ("Total registros (deduplicados): {0}" -f $all.Count) -ForegroundColor Green

if ($SkipDb) {
  Write-Host "SkipDb ativo: não vou conectar no banco." -ForegroundColor Yellow
  exit 0
}

if ([string]::IsNullOrWhiteSpace($DbPasswordEnv)) {
  Write-Host "Senha não encontrada em SUPABASE_DB_PASSWORD. Será solicitada a seguir." -ForegroundColor Yellow
  $SecurePwd = Read-Host "Digite a senha do banco de dados" -AsSecureString
  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePwd)
  $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
} else {
  $PlainPassword = $DbPasswordEnv
}

$env:PGPASSWORD = $PlainPassword

$PSQL_PATH = $null
try {
  $PSQL_PATH = (Get-ChildItem 'C:\Program Files\PostgreSQL' -Recurse -Filter psql.exe | Select-Object -First 1 -ExpandProperty FullName)
} catch {}

function Invoke-Psql {
  param([string]$Command)
  if (-not $PSQL_PATH) {
    & psql -h $PROJECT_HOST -p $PROJECT_PORT -U $PROJECT_USER -d $PROJECT_DB -v ON_ERROR_STOP=1 -c $Command
  } else {
    & $PSQL_PATH -h $PROJECT_HOST -p $PROJECT_PORT -U $PROJECT_USER -d $PROJECT_DB -v ON_ERROR_STOP=1 -c $Command
  }
  if ($LASTEXITCODE -ne 0) { throw "psql falhou (exit code: $LASTEXITCODE)" }
}

Write-Host "Carregando staging e fazendo merge..." -ForegroundColor Cyan

Invoke-Psql "TRUNCATE TABLE public.bible_lexeme_base_import;"

$psqlCsvPath = $csvPath.Replace('\', '/').Replace("'", "''")
$copyCommand = "\copy public.bible_lexeme_base_import (strong_code, language, lemma, transliteration) FROM '$psqlCsvPath' WITH (FORMAT csv, HEADER true)"
Invoke-Psql $copyCommand

Invoke-Psql "SELECT count(*) AS base_import_rows FROM public.bible_lexeme_base_import;"
Invoke-Psql "SELECT public.merge_bible_lexeme_base_import(true) AS merged;"

Invoke-Psql "SELECT strong_code, language, lemma, transliteration FROM public.bible_lexeme WHERE strong_code IN ('H7225','G0002','G0001') ORDER BY strong_code;"

Write-Host "Importação concluída." -ForegroundColor Green
