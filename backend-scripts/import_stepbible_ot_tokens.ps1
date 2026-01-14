param(
  [int]$BookId = 1,
  [string]$DbPasswordEnv = $env:SUPABASE_DB_PASSWORD,
  [ValidateSet('auto', 'pooler', 'direct')]
  [string]$DbMode = 'auto',
  [string]$OutDir = "",
  [switch]$SkipDb,
  [switch]$EnsureStepBibleOriginalSchema,
  [switch]$ImportTahotOriginalTokens,
  [switch]$ImportTahotOriginalTokensDryRun,
  [switch]$ImportTagntOriginalTokens,
  [switch]$ImportTagntOriginalTokensDryRun,
  [switch]$OnlyAutoLink,
  [switch]$AutoLinkFromGloss,
  [switch]$AutoLinkFromStepBibleCandidates,
  [switch]$AutoLinkDryRun,
  [switch]$BuildAlignmentFromLexemes,
  [switch]$LinkSingleToken,
  [string]$LinkSurface = "",
  [string]$LinkStrongCode = "",
  [int]$LinkChapter = 0,
  [int]$LinkVerse = 0,
  [switch]$LinkDryRun,
  [switch]$DownloadTahotForBook,
  [switch]$DownloadTagntForBook,
  [switch]$SurveyMissingLexemeLinks,
  [ValidateSet('book', 'ot')]
  [string]$SurveyScope = 'book'
)

Write-Host "Church 360 - Tokenização AT (ARC) por livro" -ForegroundColor Cyan

$PROJECT_HOST = "aws-0-sa-east-1.pooler.supabase.com"
$PROJECT_PORT = 6543
$PROJECT_DB   = "postgres"
$PROJECT_USER = "postgres.heswheljavpcyspuicsi"

$PROJECT_HOST_DIRECT = "db.heswheljavpcyspuicsi.supabase.co"
$PROJECT_PORT_DIRECT = 5432
$PROJECT_USER_DIRECT = "postgres"

function Get-DefaultWorkDir {
  return (Join-Path $env:TEMP "church360_arc_tokens")
}

function Tokenize-ArcVerse {
  param([string]$Text)

  if ($Text -eq $null) { return @() }

  $pattern = "([\p{L}\p{Mn}]+(?:[-'’][\p{L}\p{Mn}]+)*)|(\d+(?:[.,]\d+)*)"
  $matches = [regex]::Matches($Text, $pattern)
  $tokens = New-Object System.Collections.Generic.List[object]

  foreach ($m in $matches) {
    $tokens.Add([PSCustomObject]@{
      start = $m.Index
      end = $m.Index + $m.Length
      surface = $m.Value
    })
  }

  return $tokens
}

$stepBibleRepo = "https://raw.githubusercontent.com/STEPBible/STEPBible-Data/master"

function Get-TahotSegmentForBookId {
  param([int]$BookId)

  if ($BookId -ge 1 -and $BookId -le 5) { return "Gen-Deu" }
  if ($BookId -ge 6 -and $BookId -le 17) { return "Jos-Est" }
  if ($BookId -ge 18 -and $BookId -le 22) { return "Job-Sng" }
  if ($BookId -ge 23 -and $BookId -le 39) { return "Isa-Mal" }
  return $null
}

function Get-TahotUrlForBookId {
  param([int]$BookId)

  $segment = Get-TahotSegmentForBookId -BookId $BookId
  if (-not $segment) { return $null }

  $fileName = "TAHOT $segment - Translators Amalgamated Hebrew OT - STEPBible.org CC BY.txt"
  $encoded = [System.Uri]::EscapeDataString($fileName) -replace "%2F","/"
  $folder = "Translators%20Amalgamated%20OT%2BNT"
  return "$stepBibleRepo/$folder/$encoded"
}

function Get-TagntSegmentForBookId {
  param([int]$BookId)

  if ($BookId -ge 40 -and $BookId -le 43) { return "Mat-Jhn" }
  if ($BookId -ge 44 -and $BookId -le 66) { return "Act-Rev" }
  return $null
}

function Get-TagntUrlForBookId {
  param([int]$BookId)

  $segment = Get-TagntSegmentForBookId -BookId $BookId
  if (-not $segment) { return $null }

  $fileName = "TAGNT $segment - Translators Amalgamated Greek NT - STEPBible.org CC-BY.txt"
  $encoded = [System.Uri]::EscapeDataString($fileName) -replace "%2F","/"
  $folder = "Translators%20Amalgamated%20OT%2BNT"
  return "$stepBibleRepo/$folder/$encoded"
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

function Get-StepBibleOtBookCodeForBookId {
  param([int]$BookId)

  switch ($BookId) {
    1  { return "Gen" }
    2  { return "Exo" }
    3  { return "Lev" }
    4  { return "Num" }
    5  { return "Deu" }
    6  { return "Jos" }
    7  { return "Jdg" }
    8  { return "Rut" }
    9  { return "1Sa" }
    10 { return "2Sa" }
    11 { return "1Ki" }
    12 { return "2Ki" }
    13 { return "1Ch" }
    14 { return "2Ch" }
    15 { return "Ezr" }
    16 { return "Neh" }
    17 { return "Est" }
    18 { return "Job" }
    19 { return "Psa" }
    20 { return "Pro" }
    21 { return "Ecc" }
    22 { return "Sng" }
    23 { return "Isa" }
    24 { return "Jer" }
    25 { return "Lam" }
    26 { return "Eze" }
    27 { return "Dan" }
    28 { return "Hos" }
    29 { return "Joe" }
    30 { return "Amo" }
    31 { return "Oba" }
    32 { return "Jon" }
    33 { return "Mic" }
    34 { return "Nah" }
    35 { return "Hab" }
    36 { return "Zep" }
    37 { return "Hag" }
    38 { return "Zec" }
    39 { return "Mal" }
    default { return $null }
  }
}

function Get-RootStrongCode {
  param([string]$StrongTag)

  if ([string]::IsNullOrWhiteSpace($StrongTag)) { return $null }
  $matches = [regex]::Matches($StrongTag.ToUpperInvariant(), "([HG]\d{4,5}[A-Z]*)")
  if (-not $matches -or $matches.Count -eq 0) { return $null }
  return $matches[$matches.Count - 1].Groups[1].Value
}

function Extract-StepBibleSurfaceFromCell {
  param([string]$Cell)

  if ($Cell -eq $null) { return "" }
  $t = $Cell.Trim()
  if ([string]::IsNullOrWhiteSpace($t)) { return "" }
  $m = [regex]::Match($t, "\(([^)]*)\)")
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return $t
}

function Parse-TahotBookTokens {
  param(
    [string]$FilePath,
    [int]$BookId
  )

  $bookCode = Get-StepBibleOtBookCodeForBookId -BookId $BookId
  if (-not $bookCode) { throw ("BookId {0} não é OT suportado para TAHOT." -f $BookId) }

  $rows = New-Object System.Collections.Generic.List[object]
  $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8

  $current = $null

  foreach ($lineRaw in $lines) {
    if ([string]::IsNullOrWhiteSpace($lineRaw)) { continue }

    $line = $lineRaw.TrimStart()

    if ($line -match "^#_" ) { 
      if ($line -like "#_Word+Grammar*" -or $line -like "#_Word=Grammar*") {
        if ($null -eq $current) { continue }

        $cols = $line -split "`t"
        if ($cols.Length -lt 2) { continue }
        $wgCells = @($cols | Select-Object -Skip 1)
        $tokenCells = $current.tokenCells
        $count = [math]::Min($wgCells.Count, $tokenCells.Count)
        for ($i = 0; $i -lt $count; $i++) {
          $tokenCell = [string]$tokenCells[$i]
          $wgCell = [string]$wgCells[$i]

          $surface = Extract-StepBibleSurfaceFromCell -Cell $tokenCell
          $strongTag = $null
          $morph = $null

          if (-not [string]::IsNullOrWhiteSpace($wgCell)) {
            $parts = $wgCell.Split("=", 2)
            $strongTag = $parts[0].Trim()
            if ($parts.Length -gt 1) { $morph = $parts[1].Trim() }
          }

          $strongCode = Get-RootStrongCode -StrongTag $strongTag

          $rows.Add([PSCustomObject]@{
            testament  = "OT"
            book_id    = $BookId
            chapter    = $current.chapter
            verse      = $current.verse
            token_index = $i
            surface    = $surface
            strong_tag = $strongTag
            strong_code = $strongCode
            morphology = $morph
            source     = "STEPBible TAHOT"
          })
        }

        $current = $null
      }
      continue
    }

    if ($line -match "^\#\s*([0-9A-Za-z])") {
      $cols = $line -split "`t"
      if ($cols.Length -lt 2) { continue }

      $ref = $cols[0].Trim()
      $ref = $ref.TrimStart("#").Trim()

      if ($ref -notmatch ("^{0}\." -f [regex]::Escape($bookCode))) { 
        $current = $null
        continue 
      }

      $m = [regex]::Match($ref, "^(?<book>[1-3]?[A-Za-z]{2,3})\.(?<chap>\d+)\.(?<verse>\d+)")
      if (-not $m.Success) { 
        $current = $null
        continue 
      }

      $chapter = [int]$m.Groups["chap"].Value
      $verse = [int]$m.Groups["verse"].Value

      $tokenCells = @($cols | Select-Object -Skip 1)

      $current = [PSCustomObject]@{
        chapter = $chapter
        verse = $verse
        tokenCells = $tokenCells
      }
    }
  }

  return $rows
}

$workDir = Get-DefaultWorkDir
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$exportDir = $workDir
if (-not [string]::IsNullOrWhiteSpace($OutDir)) {
  $exportDir = $OutDir
}
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

if ($DownloadTahotForBook) {
  $url = Get-TahotUrlForBookId -BookId $BookId
  if (-not $url) {
    throw ("BookId {0} não é OT (TAHOT cobre 1..39)." -f $BookId)
  }
  $segment = Get-TahotSegmentForBookId -BookId $BookId
  $outFile = Join-Path $workDir ("TAHOT_{0}.txt" -f $segment)
  Download-IfNeeded -Uri $url -OutFile $outFile
  Write-Host ("Arquivo TAHOT disponível em: {0}" -f $outFile) -ForegroundColor Green
  exit 0
}

if ($DownloadTagntForBook) {
  $url = Get-TagntUrlForBookId -BookId $BookId
  if (-not $url) {
    throw ("BookId {0} não é NT (TAGNT cobre 40..66)." -f $BookId)
  }
  $segment = Get-TagntSegmentForBookId -BookId $BookId
  $outFile = Join-Path $workDir ("TAGNT_{0}.txt" -f $segment)
  Download-IfNeeded -Uri $url -OutFile $outFile
  Write-Host ("Arquivo TAGNT disponível em: {0}" -f $outFile) -ForegroundColor Green
  exit 0
}

if ($SkipDb) {
  if (-not ($ImportTahotOriginalTokens -or $ImportTagntOriginalTokens)) {
    Write-Host "SkipDb ativo: nada a fazer sem acesso ao banco." -ForegroundColor Yellow
    exit 0
  }
}

$needsDbAuth = $true
if ($SkipDb) { $needsDbAuth = $false }
if ($ImportTahotOriginalTokens -and ($SkipDb -or $ImportTahotOriginalTokensDryRun)) { $needsDbAuth = $false }
if ($ImportTagntOriginalTokens -and ($SkipDb -or $ImportTagntOriginalTokensDryRun)) { $needsDbAuth = $false }

if ($needsDbAuth) {
  if ([string]::IsNullOrWhiteSpace($DbPasswordEnv)) {
    Write-Host "Senha não encontrada em SUPABASE_DB_PASSWORD. Será solicitada a seguir." -ForegroundColor Yellow
    $SecurePwd = Read-Host "Digite a senha do banco de dados" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePwd)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  } else {
    $PlainPassword = $DbPasswordEnv
  }
}

if ($needsDbAuth) {
  $env:PGPASSWORD = $PlainPassword
  $env:PGSSLMODE = "require"
}

$PSQL_PATH = $null
try {
  $cmd = Get-Command psql -ErrorAction SilentlyContinue
  if ($cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
    $PSQL_PATH = $cmd.Source
  }
} catch {}

if (-not $PSQL_PATH) {
  try {
    $candidates = Get-ChildItem 'C:\Program Files\PostgreSQL' -Recurse -Filter psql.exe -ErrorAction SilentlyContinue
    if ($candidates) {
      $best = $candidates | ForEach-Object {
        $v = $null
        try { $v = [version]$_.VersionInfo.ProductVersion } catch {}
        [PSCustomObject]@{ Path = $_.FullName; Version = $v }
      } | Sort-Object @{ Expression = { $_.Version -as [version] }; Descending = $true }, @{ Expression = { $_.Path }; Descending = $false } | Select-Object -First 1

      if ($best -and -not [string]::IsNullOrWhiteSpace($best.Path)) {
        $PSQL_PATH = $best.Path
      }
    }
  } catch {}
}

function Invoke-Psql {
  param([string]$Command)
  $psqlExe = "psql"
  if ($PSQL_PATH) { $psqlExe = $PSQL_PATH }

  $attempts = @()
  if ($DbMode -eq 'direct') {
    $attempts += [PSCustomObject]@{ host = $PROJECT_HOST_DIRECT; port = $PROJECT_PORT_DIRECT; user = $PROJECT_USER_DIRECT; label = "direct" }
  } elseif ($DbMode -eq 'pooler') {
    $attempts += [PSCustomObject]@{ host = $PROJECT_HOST; port = $PROJECT_PORT; user = $PROJECT_USER; label = "pooler" }
  } else {
    $attempts += [PSCustomObject]@{ host = $PROJECT_HOST; port = $PROJECT_PORT; user = $PROJECT_USER; label = "pooler" }
    $attempts += [PSCustomObject]@{ host = $PROJECT_HOST_DIRECT; port = $PROJECT_PORT_DIRECT; user = $PROJECT_USER_DIRECT; label = "direct" }
  }

  $lastErr = $null
  foreach ($a in $attempts) {
    try {
      Write-Host ("Conectando via {0} ({1}:{2}, user {3})..." -f $a.label, $a.host, $a.port, $a.user) -ForegroundColor DarkCyan
      & $psqlExe -h $a.host -p $a.port -U $a.user -d $PROJECT_DB -v ON_ERROR_STOP=1 -c $Command
      if ($LASTEXITCODE -eq 0) { return }
      $lastErr = "psql falhou (exit code: $LASTEXITCODE) em modo $($a.label)"
    } catch {
      $lastErr = $_.Exception.Message
    }
  }

  if (-not $lastErr) { $lastErr = "psql falhou" }
  throw $lastErr
}

$ensureStepBibleOriginalSql = @"
CREATE TABLE IF NOT EXISTS public.stepbible_original_token (
  id BIGSERIAL PRIMARY KEY,
  testament TEXT NOT NULL CHECK (testament IN ('OT', 'NT')),
  book_id INTEGER NOT NULL REFERENCES public.bible_book(id) ON DELETE CASCADE,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  token_index INTEGER NOT NULL,
  surface TEXT NOT NULL,
  strong_tag TEXT,
  strong_code TEXT,
  lexeme_id BIGINT REFERENCES public.bible_lexeme(id) ON DELETE SET NULL,
  morphology TEXT,
  source TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(testament, book_id, chapter, verse, token_index)
);
ALTER TABLE public.stepbible_original_token ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Todos podem visualizar tokens originais STEPBible" ON public.stepbible_original_token;
CREATE POLICY "Todos podem visualizar tokens originais STEPBible"
  ON public.stepbible_original_token
  FOR SELECT
  USING (true);
CREATE INDEX IF NOT EXISTS idx_stepbible_original_token_book_ref
  ON public.stepbible_original_token(book_id, chapter, verse);
CREATE INDEX IF NOT EXISTS idx_stepbible_original_token_lexeme_id
  ON public.stepbible_original_token(lexeme_id);
CREATE INDEX IF NOT EXISTS idx_stepbible_original_token_strong_code
  ON public.stepbible_original_token(strong_code);

CREATE TABLE IF NOT EXISTS public.stepbible_original_token_base_import (
  testament TEXT NOT NULL CHECK (testament IN ('OT', 'NT')),
  book_id INTEGER NOT NULL REFERENCES public.bible_book(id) ON DELETE CASCADE,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  token_index INTEGER NOT NULL,
  surface TEXT NOT NULL,
  strong_tag TEXT,
  strong_code TEXT,
  morphology TEXT,
  source TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(testament, book_id, chapter, verse, token_index)
);
ALTER TABLE public.stepbible_original_token_base_import ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_stepbible_original_token_base_import_ref
  ON public.stepbible_original_token_base_import(book_id, chapter, verse);
CREATE INDEX IF NOT EXISTS idx_stepbible_original_token_base_import_strong_code
  ON public.stepbible_original_token_base_import(strong_code);

CREATE OR REPLACE FUNCTION public.merge_stepbible_original_token_base_import(
  p_truncate_after boolean DEFAULT true
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO off
AS \$function\$
DECLARE
  v_merged bigint := 0;
BEGIN
  IF to_regclass('public.stepbible_original_token_base_import') IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.stepbible_original_token') IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_lexeme') IS NULL THEN
    RETURN 0;
  END IF;

  WITH src AS (
    SELECT DISTINCT
      upper(trim(strong_code)) AS strong_code
    FROM public.stepbible_original_token_base_import
    WHERE NULLIF(trim(strong_code), '') IS NOT NULL
  ),
  computed AS (
    SELECT
      strong_code,
      CASE
        WHEN strong_code LIKE 'H%' THEN 'hebrew'
        WHEN strong_code LIKE 'G%' THEN 'greek'
        ELSE NULL
      END AS language
    FROM src
  ),
  upserted AS (
    INSERT INTO public.bible_lexeme (strong_code, language, updated_at)
    SELECT
      c.strong_code,
      c.language,
      now()
    FROM computed c
    WHERE c.language IS NOT NULL
    ON CONFLICT (strong_code) DO UPDATE SET
      language = EXCLUDED.language,
      updated_at = now()
    RETURNING 1
  )
  SELECT count(*) INTO v_merged FROM upserted;

  WITH src AS (
    SELECT
      bi.testament,
      bi.book_id,
      bi.chapter,
      bi.verse,
      bi.token_index,
      bi.surface,
      NULLIF(trim(bi.strong_tag), '') AS strong_tag,
      NULLIF(upper(trim(bi.strong_code)), '') AS strong_code,
      NULLIF(trim(bi.morphology), '') AS morphology,
      bi.source
    FROM public.stepbible_original_token_base_import bi
  ),
  joined AS (
    SELECT
      s.*,
      l.id AS lexeme_id
    FROM src s
    LEFT JOIN public.bible_lexeme l
      ON l.strong_code = s.strong_code
  ),
  upserted AS (
    INSERT INTO public.stepbible_original_token (
      testament,
      book_id,
      chapter,
      verse,
      token_index,
      surface,
      strong_tag,
      strong_code,
      lexeme_id,
      morphology,
      source
    )
    SELECT
      j.testament,
      j.book_id,
      j.chapter,
      j.verse,
      j.token_index,
      j.surface,
      j.strong_tag,
      j.strong_code,
      j.lexeme_id,
      j.morphology,
      j.source
    FROM joined j
    ON CONFLICT (testament, book_id, chapter, verse, token_index) DO UPDATE SET
      surface = EXCLUDED.surface,
      strong_tag = EXCLUDED.strong_tag,
      strong_code = EXCLUDED.strong_code,
      lexeme_id = EXCLUDED.lexeme_id,
      morphology = EXCLUDED.morphology,
      source = EXCLUDED.source
    RETURNING 1
  )
  SELECT v_merged + count(*) INTO v_merged FROM upserted;

  IF p_truncate_after THEN
    TRUNCATE TABLE public.stepbible_original_token_base_import;
  END IF;

  RETURN v_merged;
END
\$function\$;
"@

if ($EnsureStepBibleOriginalSchema -and -not $SkipDb) {
  Write-Host "Garantindo schema para tokens originais STEPBible..." -ForegroundColor Cyan
  Invoke-Psql $ensureStepBibleOriginalSql
}

if ($ImportTahotOriginalTokens) {
  $url = Get-TahotUrlForBookId -BookId $BookId
  if (-not $url) {
    throw ("BookId {0} não é OT (TAHOT cobre 1..39)." -f $BookId)
  }
  $segment = Get-TahotSegmentForBookId -BookId $BookId
  $tahotFile = Join-Path $workDir ("TAHOT_{0}.txt" -f $segment)
  Download-IfNeeded -Uri $url -OutFile $tahotFile

  Write-Host ("Parseando TAHOT para BookId {0}..." -f $BookId) -ForegroundColor Cyan
  $parsed = Parse-TahotBookTokens -FilePath $tahotFile -BookId $BookId
  Write-Host ("Tokens originais (linhas): {0}" -f $parsed.Count) -ForegroundColor DarkCyan

  $csvPath = Join-Path $exportDir ("stepbible_original_token_base_import.book_{0}.csv" -f $BookId)
  $parsed | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
  Write-Host ("CSV gerado: {0}" -f $csvPath) -ForegroundColor Green

  if ($SkipDb -or $ImportTahotOriginalTokensDryRun) {
    Write-Host "Dry-run/SkipDb ativo: não vou inserir no banco." -ForegroundColor Yellow
    $sample = $parsed | Select-Object -First 5
    if ($sample) { $sample | Format-Table -AutoSize | Out-Host }
    exit 0
  }

  if (-not $EnsureStepBibleOriginalSchema) {
    Write-Host "Garantindo schema para tokens originais STEPBible..." -ForegroundColor Cyan
    Invoke-Psql $ensureStepBibleOriginalSql
  }

  Write-Host "Carregando staging e fazendo merge (tokens originais STEPBible)..." -ForegroundColor Cyan
  Invoke-Psql "TRUNCATE TABLE public.stepbible_original_token_base_import;"

  $psqlCsvPath = $csvPath.Replace('\', '/').Replace("'", "''")
  $copyCommand = "\copy public.stepbible_original_token_base_import (testament, book_id, chapter, verse, token_index, surface, strong_tag, strong_code, morphology, source) FROM '$psqlCsvPath' WITH (FORMAT csv, HEADER true)"
  Invoke-Psql $copyCommand

  Invoke-Psql "SELECT count(*) AS base_import_rows FROM public.stepbible_original_token_base_import;"
  Invoke-Psql "SELECT public.merge_stepbible_original_token_base_import(true) AS merged;"
  Invoke-Psql "SELECT count(*) AS tokens_originais_book FROM public.stepbible_original_token WHERE book_id = $BookId AND testament='OT';"
  Invoke-Psql "SELECT token_index, surface, strong_tag, strong_code FROM public.stepbible_original_token WHERE book_id=$BookId AND chapter=1 AND verse=1 ORDER BY token_index ASC LIMIT 15;"
  exit 0
}

function Get-StepBibleNtBookCodeForBookId {
  param([int]$BookId)

  switch ($BookId) {
    40 { return "Mat" }
    41 { return "Mar" }
    42 { return "Luk" }
    43 { return "Jhn" }
    44 { return "Act" }
    45 { return "Rom" }
    46 { return "1Co" }
    47 { return "2Co" }
    48 { return "Gal" }
    49 { return "Eph" }
    50 { return "Phi" }
    51 { return "Col" }
    52 { return "1Th" }
    53 { return "2Th" }
    54 { return "1Ti" }
    55 { return "2Ti" }
    56 { return "Tit" }
    57 { return "Phm" }
    58 { return "Heb" }
    59 { return "Jas" }
    60 { return "1Pe" }
    61 { return "2Pe" }
    62 { return "1Jn" }
    63 { return "2Jn" }
    64 { return "3Jn" }
    65 { return "Jud" }
    66 { return "Rev" }
    default { return $null }
  }
}

function Parse-TagntBookTokens {
  param(
    [string]$FilePath,
    [int]$BookId
  )

  $bookCode = Get-StepBibleNtBookCodeForBookId -BookId $BookId
  if (-not $bookCode) { throw ("BookId {0} não é NT suportado para TAGNT." -f $BookId) }

  $rows = New-Object System.Collections.Generic.List[object]
  $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8

  $current = $null

  foreach ($lineRaw in $lines) {
    if ([string]::IsNullOrWhiteSpace($lineRaw)) { continue }

    $line = $lineRaw.TrimStart()

    if ($line -match "^#_" ) { 
      if ($line -like "#_Word+Grammar*" -or $line -like "#_Word=Grammar*") {
        if ($null -eq $current) { continue }

        $cols = $line -split "`t"
        if ($cols.Length -lt 2) { continue }
        $wgCells = @($cols | Select-Object -Skip 1)
        $tokenCells = $current.tokenCells
        $count = [math]::Min($wgCells.Count, $tokenCells.Count)
        for ($i = 0; $i -lt $count; $i++) {
          $tokenCell = [string]$tokenCells[$i]
          $wgCell = [string]$wgCells[$i]

          $surface = Extract-StepBibleSurfaceFromCell -Cell $tokenCell
          $strongTag = $null
          $morph = $null

          if (-not [string]::IsNullOrWhiteSpace($wgCell)) {
            $parts = $wgCell.Split("=", 2)
            $strongTag = $parts[0].Trim()
            if ($parts.Length -gt 1) { $morph = $parts[1].Trim() }
          }

          $strongCode = Get-RootStrongCode -StrongTag $strongTag

          $rows.Add([PSCustomObject]@{
            testament  = "NT"
            book_id    = $BookId
            chapter    = $current.chapter
            verse      = $current.verse
            token_index = $i
            surface    = $surface
            strong_tag = $strongTag
            strong_code = $strongCode
            morphology = $morph
            source     = "STEPBible TAGNT"
          })
        }

        $current = $null
      }
      continue
    }

    if ($line -match "^\#\s*([0-9A-Za-z])") {
      $cols = $line -split "`t"
      if ($cols.Length -lt 2) { continue }

      $ref = $cols[0].Trim()
      $ref = $ref.TrimStart("#").Trim()

      if ($ref -notmatch ("^{0}\." -f [regex]::Escape($bookCode))) { 
        $current = $null
        continue 
      }

      $m = [regex]::Match($ref, "^(?<book>[1-3]?[A-Za-z]{2,3})\.(?<chap>\d+)\.(?<verse>\d+)")
      if (-not $m.Success) { 
        $current = $null
        continue 
      }

      $chapter = [int]$m.Groups["chap"].Value
      $verse = [int]$m.Groups["verse"].Value

      $tokenCells = @($cols | Select-Object -Skip 1)

      $current = [PSCustomObject]@{
        chapter = $chapter
        verse = $verse
        tokenCells = $tokenCells
      }
    }
  }

  return $rows
}

if ($ImportTagntOriginalTokens) {
  $url = Get-TagntUrlForBookId -BookId $BookId
  if (-not $url) {
    throw ("BookId {0} não é NT (TAGNT cobre 40..66)." -f $BookId)
  }
  $segment = Get-TagntSegmentForBookId -BookId $BookId
  $tagntFile = Join-Path $workDir ("TAGNT_{0}.txt" -f $segment)
  Download-IfNeeded -Uri $url -OutFile $tagntFile

  Write-Host ("Parseando TAGNT para BookId {0}..." -f $BookId) -ForegroundColor Cyan
  $parsed = Parse-TagntBookTokens -FilePath $tagntFile -BookId $BookId
  Write-Host ("Tokens originais (linhas): {0}" -f $parsed.Count) -ForegroundColor DarkCyan

  $csvPath = Join-Path $exportDir ("stepbible_original_token_base_import.book_{0}.csv" -f $BookId)
  $parsed | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
  Write-Host ("CSV gerado: {0}" -f $csvPath) -ForegroundColor Green

  if ($SkipDb -or $ImportTagntOriginalTokensDryRun) {
    Write-Host "Dry-run/SkipDb ativo: não vou inserir no banco." -ForegroundColor Yellow
    $sample = $parsed | Select-Object -First 5
    if ($sample) { $sample | Format-Table -AutoSize | Out-Host }
    exit 0
  }

  if (-not $EnsureStepBibleOriginalSchema) {
    Write-Host "Garantindo schema para tokens originais STEPBible..." -ForegroundColor Cyan
    Invoke-Psql $ensureStepBibleOriginalSql
  }

  Write-Host "Carregando staging e fazendo merge (tokens originais STEPBible)..." -ForegroundColor Cyan
  Invoke-Psql "TRUNCATE TABLE public.stepbible_original_token_base_import;"

  $psqlCsvPath = $csvPath.Replace('\', '/').Replace("'", "''")
  $copyCommand = "\copy public.stepbible_original_token_base_import (testament, book_id, chapter, verse, token_index, surface, strong_tag, strong_code, morphology, source) FROM '$psqlCsvPath' WITH (FORMAT csv, HEADER true)"
  Invoke-Psql $copyCommand

  Invoke-Psql "SELECT count(*) AS base_import_rows FROM public.stepbible_original_token_base_import;"
  Invoke-Psql "SELECT public.merge_stepbible_original_token_base_import(true) AS merged;"
  Invoke-Psql "SELECT count(*) AS tokens_originais_book FROM public.stepbible_original_token WHERE book_id = $BookId AND testament='NT';"
  Invoke-Psql "SELECT token_index, surface, strong_tag, strong_code FROM public.stepbible_original_token WHERE book_id=$BookId AND chapter=1 AND verse=1 ORDER BY token_index ASC LIMIT 15;"
  exit 0
}

$LinkSurfaceSql = ""
if (-not [string]::IsNullOrWhiteSpace($LinkSurface)) {
  $LinkSurfaceSql = $LinkSurface.Replace("'", "''")
}
$LinkStrongCodeSql = ""
if (-not [string]::IsNullOrWhiteSpace($LinkStrongCode)) {
  $LinkStrongCodeSql = $LinkStrongCode.Replace("'", "''")
}

$linkSingleTokenPreviewSql = @"
WITH target_verse AS (
  SELECT id
  FROM public.bible_verse
  WHERE book_id = $BookId
    AND chapter = $LinkChapter
    AND verse = $LinkVerse
),
target_lexeme AS (
  SELECT id, strong_code, language
  FROM public.bible_lexeme
  WHERE strong_code = upper(trim('$LinkStrongCodeSql'))
),
tokens AS (
  SELECT
    t.id,
    t.verse_id,
    t.token_index,
    t.surface,
    t.start_offset,
    t.end_offset,
    t.lexeme_id,
    l.strong_code AS current_strong_code
  FROM public.bible_verse_token t
  JOIN target_verse tv ON tv.id = t.verse_id
  LEFT JOIN public.bible_lexeme l ON l.id = t.lexeme_id
  WHERE lower(trim(t.surface)) = lower(trim('$LinkSurfaceSql'))
  ORDER BY t.token_index ASC
)
SELECT
  (SELECT id FROM target_verse) AS verse_id,
  (SELECT strong_code FROM target_lexeme) AS new_strong_code,
  (SELECT id FROM target_lexeme) AS new_lexeme_id,
  count(*) AS matching_tokens,
  array_to_string((array_agg(tokens.id ORDER BY tokens.token_index))[1:10], ', ') AS sample_token_ids,
  array_to_string((array_agg(COALESCE(tokens.current_strong_code, 'NULL') ORDER BY tokens.token_index))[1:10], ', ') AS sample_current_strong_codes
FROM tokens;

SELECT
  t.id AS token_id,
  t.token_index,
  t.surface,
  t.start_offset,
  t.end_offset,
  COALESCE(l.strong_code, 'NULL') AS current_strong_code
FROM public.bible_verse_token t
JOIN public.bible_verse v ON v.id = t.verse_id
LEFT JOIN public.bible_lexeme l ON l.id = t.lexeme_id
WHERE v.book_id = $BookId
  AND v.chapter = $LinkChapter
  AND v.verse = $LinkVerse
  AND lower(trim(t.surface)) = lower(trim('$LinkSurfaceSql'))
ORDER BY t.token_index ASC
LIMIT 50;
"@

$linkSingleTokenApplySqlTemplate = @'
DO $$
DECLARE
  v_verse_id int;
  v_lexeme_id bigint;
  v_token_id bigint;
  v_language text;
  v_book_testament text;
BEGIN
  IF NULLIF(trim('__LINK_SURFACE_RAW__'), '') IS NULL THEN
    RAISE EXCEPTION 'LinkSurface é obrigatório';
  END IF;

  IF NULLIF(trim('__LINK_STRONG_RAW__'), '') IS NULL THEN
    RAISE EXCEPTION 'LinkStrongCode é obrigatório';
  END IF;

  IF __LINK_CHAPTER__ <= 0 OR __LINK_VERSE__ <= 0 THEN
    RAISE EXCEPTION 'LinkChapter e LinkVerse devem ser > 0';
  END IF;

  SELECT testament INTO v_book_testament
  FROM public.bible_book
  WHERE id = __BOOK_ID__;

  SELECT id INTO v_verse_id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__ AND chapter = __LINK_CHAPTER__ AND verse = __LINK_VERSE__;

  IF v_verse_id IS NULL THEN
    RAISE EXCEPTION 'Verso não encontrado: book_id %, %:%', __BOOK_ID__, __LINK_CHAPTER__, __LINK_VERSE__;
  END IF;

  v_language := CASE
    WHEN upper(trim('__LINK_STRONG__')) LIKE 'H%' THEN 'hebrew'
    WHEN upper(trim('__LINK_STRONG__')) LIKE 'G%' THEN 'greek'
    ELSE NULL
  END;

  IF v_language IS NULL THEN
    RAISE EXCEPTION 'Strong code inválido: %', upper(trim('__LINK_STRONG__'));
  END IF;

  IF v_book_testament = 'OT' AND v_language <> 'hebrew' THEN
    RAISE EXCEPTION 'Livro OT requer strong H..., recebido: %', upper(trim('__LINK_STRONG__'));
  END IF;
  IF v_book_testament = 'NT' AND v_language <> 'greek' THEN
    RAISE EXCEPTION 'Livro NT requer strong G..., recebido: %', upper(trim('__LINK_STRONG__'));
  END IF;

  INSERT INTO public.bible_lexeme (strong_code, language, updated_at)
  VALUES (upper(trim('__LINK_STRONG__')), v_language, now())
  ON CONFLICT (strong_code) DO UPDATE SET
    language = EXCLUDED.language,
    updated_at = now();

  SELECT id INTO v_lexeme_id
  FROM public.bible_lexeme
  WHERE strong_code = upper(trim('__LINK_STRONG__'));

  SELECT t.id INTO v_token_id
  FROM public.bible_verse_token t
  WHERE t.verse_id = v_verse_id
    AND lower(trim(t.surface)) = lower(trim('__LINK_SURFACE__'))
  ORDER BY t.token_index ASC
  LIMIT 1;

  IF v_token_id IS NULL THEN
    RAISE EXCEPTION 'Token não encontrado no verso: surface "%"', trim('__LINK_SURFACE__');
  END IF;

  UPDATE public.bible_verse_token
  SET
    lexeme_id = v_lexeme_id,
    confidence = 1.0,
    source = COALESCE(NULLIF(trim(source), ''), '') || CASE WHEN NULLIF(trim(source), '') IS NULL THEN '' ELSE ' | ' END || 'manual strong ' || upper(trim('__LINK_STRONG__'))
  WHERE id = v_token_id;
END $$;
'@

$linkSingleTokenApplySql = $linkSingleTokenApplySqlTemplate
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__BOOK_ID__', [string]$BookId)
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__LINK_CHAPTER__', [string]$LinkChapter)
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__LINK_VERSE__', [string]$LinkVerse)
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__LINK_SURFACE__', $LinkSurfaceSql)
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__LINK_STRONG__', $LinkStrongCodeSql)
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__LINK_SURFACE_RAW__', $LinkSurfaceSql)
$linkSingleTokenApplySql = $linkSingleTokenApplySql.Replace('__LINK_STRONG_RAW__', $LinkStrongCodeSql)

$validateSql = @"
SELECT * FROM public.validate_bible_tokens_for_book($BookId);
SELECT count(*) AS tokens_book
FROM public.bible_verse_token t
JOIN public.bible_verse v ON v.id=t.verse_id
WHERE v.book_id = $BookId;
SELECT count(*) AS tokens_sem_lexeme
FROM public.bible_verse_token t
JOIN public.bible_verse v ON v.id=t.verse_id
WHERE v.book_id = $BookId AND t.lexeme_id IS NULL;
SELECT count(*) AS tokens_lexeme_grego_no_ot
FROM public.bible_verse_token t
JOIN public.bible_verse v ON v.id=t.verse_id
JOIN public.bible_lexeme l ON l.id=t.lexeme_id
WHERE v.book_id = $BookId AND l.strong_code LIKE 'G%';
SELECT lower(trim(t.surface)) AS surface, count(*) AS total
FROM public.bible_verse_token t
JOIN public.bible_verse v ON v.id=t.verse_id
WHERE v.book_id = $BookId AND t.lexeme_id IS NULL
GROUP BY lower(trim(t.surface))
ORDER BY total DESC, surface ASC
LIMIT 30;
"@

$surveyBookSql = @"
WITH tokens AS (
  SELECT
    t.id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss,
    min(l.id) AS lexeme_id,
    count(*) AS cnt
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
),
joined AS (
  SELECT
    tok.surface,
    lg.lexeme_id,
    lg.cnt
  FROM tokens tok
  LEFT JOIN lexeme_gloss lg
    ON lg.gloss = tok.surface
)
SELECT
  (SELECT count(*) FROM tokens) AS tokens_sem_lexeme,
  count(*) FILTER (WHERE lexeme_id IS NOT NULL AND cnt = 1) AS tokens_com_match_unico,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NOT NULL AND cnt = 1) AS superficies_match_unico,
  count(*) FILTER (WHERE lexeme_id IS NOT NULL AND cnt > 1) AS tokens_match_ambiguo,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NOT NULL AND cnt > 1) AS superficies_match_ambiguo,
  count(*) FILTER (WHERE lexeme_id IS NULL) AS tokens_sem_match_no_lexico,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NULL) AS superficies_sem_match_no_lexico
FROM joined;

WITH tokens AS (
  SELECT lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss,
    min(l.id) AS lexeme_id,
    count(*) AS cnt
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
)
SELECT
  tok.surface,
  count(*) AS tokens,
  lg.lexeme_id,
  l.strong_code
FROM tokens tok
JOIN lexeme_gloss lg ON lg.gloss = tok.surface AND lg.cnt = 1
JOIN public.bible_lexeme l ON l.id = lg.lexeme_id
GROUP BY tok.surface, lg.lexeme_id, l.strong_code
ORDER BY tokens DESC, tok.surface ASC
LIMIT 100;

WITH lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss,
    count(*) AS cnt
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
)
SELECT
  lg.gloss AS pt_gloss,
  lg.cnt,
  array_to_string((array_agg(l.strong_code ORDER BY l.strong_code))[1:10], ', ') AS sample_strong_codes
FROM lexeme_gloss lg
JOIN public.bible_lexeme l
  ON lower(trim(l.pt_gloss)) = lg.gloss
  AND l.language = 'hebrew'
WHERE lg.cnt > 1
GROUP BY lg.gloss, lg.cnt
ORDER BY lg.cnt DESC, lg.gloss ASC
LIMIT 50;

WITH tokens AS (
  SELECT lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
)
SELECT
  tok.surface,
  count(*) AS tokens
FROM tokens tok
LEFT JOIN lexeme_gloss lg ON lg.gloss = tok.surface
WHERE lg.gloss IS NULL
GROUP BY tok.surface
ORDER BY tokens DESC, tok.surface ASC
LIMIT 100;
"@

$surveyOtSql = @"
WITH tokens AS (
  SELECT
    t.id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  JOIN public.bible_book b ON b.id=v.book_id
  WHERE b.testament = 'OT'
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss,
    min(l.id) AS lexeme_id,
    count(*) AS cnt
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
),
joined AS (
  SELECT
    tok.surface,
    lg.lexeme_id,
    lg.cnt
  FROM tokens tok
  LEFT JOIN lexeme_gloss lg
    ON lg.gloss = tok.surface
)
SELECT
  (SELECT count(*) FROM tokens) AS tokens_sem_lexeme,
  count(*) FILTER (WHERE lexeme_id IS NOT NULL AND cnt = 1) AS tokens_com_match_unico,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NOT NULL AND cnt = 1) AS superficies_match_unico,
  count(*) FILTER (WHERE lexeme_id IS NOT NULL AND cnt > 1) AS tokens_match_ambiguo,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NOT NULL AND cnt > 1) AS superficies_match_ambiguo,
  count(*) FILTER (WHERE lexeme_id IS NULL) AS tokens_sem_match_no_lexico,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NULL) AS superficies_sem_match_no_lexico
FROM joined;

WITH tokens AS (
  SELECT lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  JOIN public.bible_book b ON b.id=v.book_id
  WHERE b.testament = 'OT'
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss,
    min(l.id) AS lexeme_id,
    count(*) AS cnt
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
)
SELECT
  tok.surface,
  count(*) AS tokens,
  lg.lexeme_id,
  l.strong_code
FROM tokens tok
JOIN lexeme_gloss lg ON lg.gloss = tok.surface AND lg.cnt = 1
JOIN public.bible_lexeme l ON l.id = lg.lexeme_id
GROUP BY tok.surface, lg.lexeme_id, l.strong_code
ORDER BY tokens DESC, tok.surface ASC
LIMIT 150;

WITH tokens AS (
  SELECT lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  JOIN public.bible_book b ON b.id=v.book_id
  WHERE b.testament = 'OT'
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss
  FROM public.bible_lexeme l
  WHERE l.language = 'hebrew'
    AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(l.pt_gloss))
)
SELECT
  tok.surface,
  count(*) AS tokens
FROM tokens tok
LEFT JOIN lexeme_gloss lg ON lg.gloss = tok.surface
WHERE lg.gloss IS NULL
GROUP BY tok.surface
ORDER BY tokens DESC, tok.surface ASC
LIMIT 150;
"@

$autoLinkDryRunSql = @"
WITH token_candidates AS (
  SELECT
    t.id AS token_id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_candidates AS (
  SELECT
    lower(trim(pt_gloss)) AS gloss,
    min(id) AS lexeme_id,
    count(*) AS cnt
  FROM public.bible_lexeme
  WHERE language = 'hebrew'
    AND NULLIF(trim(pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(pt_gloss))
),
matches AS (
  SELECT
    tc.token_id,
    lc.lexeme_id
  FROM token_candidates tc
  JOIN lexeme_candidates lc
    ON lc.gloss = tc.surface
  WHERE lc.cnt = 1
)
SELECT
  count(*) AS tokens_que_seriam_vinculados,
  count(DISTINCT tc.surface) AS superficies_unicas
FROM matches m
JOIN token_candidates tc ON tc.token_id = m.token_id;

WITH lexeme_candidates AS (
  SELECT
    lower(trim(pt_gloss)) AS gloss,
    count(*) AS cnt
  FROM public.bible_lexeme
  WHERE language = 'hebrew'
    AND NULLIF(trim(pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(pt_gloss))
)
SELECT gloss AS pt_gloss, cnt
FROM lexeme_candidates
WHERE cnt > 1
ORDER BY cnt DESC, pt_gloss ASC
LIMIT 30;
"@

$autoLinkApplySql = @"
WITH token_candidates AS (
  SELECT
    t.id AS token_id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id=t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
lexeme_candidates AS (
  SELECT
    lower(trim(pt_gloss)) AS gloss,
    min(id) AS lexeme_id,
    count(*) AS cnt
  FROM public.bible_lexeme
  WHERE language = 'hebrew'
    AND NULLIF(trim(pt_gloss), '') IS NOT NULL
  GROUP BY lower(trim(pt_gloss))
),
matches AS (
  SELECT
    tc.token_id,
    lc.lexeme_id
  FROM token_candidates tc
  JOIN lexeme_candidates lc
    ON lc.gloss = tc.surface
  WHERE lc.cnt = 1
)
UPDATE public.bible_verse_token t
SET lexeme_id = m.lexeme_id
FROM matches m
WHERE t.id = m.token_id;
"@

$autoLinkStepBibleDryRunSql = @"
WITH token_candidates AS (
  SELECT
    t.id AS token_id,
    lower(trim(t.surface)) AS surface,
    v.book_id,
    v.chapter,
    v.verse
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
verse_lexemes AS (
  SELECT
    sot.book_id,
    sot.chapter,
    sot.verse,
    sot.lexeme_id
  FROM public.stepbible_original_token sot
  WHERE sot.book_id = $BookId
    AND sot.lexeme_id IS NOT NULL
  GROUP BY sot.book_id, sot.chapter, sot.verse, sot.lexeme_id
),
lexeme_gloss AS (
  SELECT
    lower(trim(l.pt_gloss)) AS gloss,
    l.id AS lexeme_id
  FROM public.bible_lexeme l
  JOIN public.bible_book b ON b.id = $BookId
  WHERE NULLIF(trim(l.pt_gloss), '') IS NOT NULL
    AND (
      (b.testament = 'OT' AND l.language = 'hebrew')
      OR (b.testament = 'NT' AND l.language = 'greek')
    )
),
matches AS (
  SELECT
    tc.token_id,
    lg.lexeme_id,
    count(*) OVER (PARTITION BY tc.token_id) AS cnt
  FROM token_candidates tc
  JOIN lexeme_gloss lg
    ON lg.gloss = tc.surface
  JOIN verse_lexemes vl
    ON vl.book_id = tc.book_id
    AND vl.chapter = tc.chapter
    AND vl.verse = tc.verse
    AND vl.lexeme_id = lg.lexeme_id
),
unique_matches AS (
  SELECT token_id, lexeme_id
  FROM matches
  WHERE cnt = 1
)
SELECT
  count(*) AS tokens_que_seriam_vinculados,
  count(DISTINCT token_id) AS tokens_distintos
FROM unique_matches;
"@

if ($BuildAlignmentFromLexemes) {
  Write-Host "Modo BuildAlignmentFromLexemes: vou criar alinhamentos ARC↔STEP por lexeme." -ForegroundColor Cyan
  Invoke-Psql ("SELECT public.build_bible_verse_token_alignment_for_book({0}, true, 0.6, 'auto alignment') AS alinhamentos_criados;" -f $BookId)
  exit 0
}

if ($OnlyAutoLink) {
  Write-Host "Modo OnlyAutoLink: vou apenas validar/auto-vincular (sem retokenizar)." -ForegroundColor Cyan
  Write-Host "Validação atual:" -ForegroundColor Cyan
  Invoke-Psql $validateSql

  if ($AutoLinkFromGloss) {
    if ($AutoLinkDryRun) {
      Write-Host "AutoLinkFromGloss (dry-run): simulando vínculos por pt_gloss..." -ForegroundColor Cyan
      Invoke-Psql $autoLinkDryRunSql
    } else {
      Write-Host "AutoLinkFromGloss: aplicando vínculos por pt_gloss..." -ForegroundColor Cyan
      Invoke-Psql $autoLinkApplySql
      Write-Host "Validação após auto-link:" -ForegroundColor Cyan
      Invoke-Psql $validateSql
    }
  }

  if ($AutoLinkFromStepBibleCandidates) {
    if ($AutoLinkDryRun) {
      Write-Host "AutoLinkFromStepBibleCandidates (dry-run): simulando vínculos com candidatos do STEPBible..." -ForegroundColor Cyan
      Invoke-Psql $autoLinkStepBibleDryRunSql
    } else {
      Write-Host "AutoLinkFromStepBibleCandidates: aplicando vínculos com candidatos do STEPBible..." -ForegroundColor Cyan
      Invoke-Psql ("SELECT public.auto_link_bible_tokens_from_stepbible({0}, true, 0.7, 'stepbible candidate') AS tokens_vinculados;" -f $BookId)
      Write-Host "Validação após auto-link:" -ForegroundColor Cyan
      Invoke-Psql $validateSql
    }
  }

  exit 0
}

if ($LinkSingleToken) {
  Write-Host "Modo LinkSingleToken: vou vincular 1 token (por surface) a 1 Strong." -ForegroundColor Cyan
  Invoke-Psql $linkSingleTokenPreviewSql
  if (-not $LinkDryRun) {
    Invoke-Psql $linkSingleTokenApplySql
    Write-Host "Vínculo aplicado. Conferindo..." -ForegroundColor Cyan
    Invoke-Psql $linkSingleTokenPreviewSql
  } else {
    Write-Host "LinkDryRun ativo: nada foi alterado no banco." -ForegroundColor Yellow
  }
  exit 0
}

if ($SurveyMissingLexemeLinks) {
  Write-Host "Levantamento: tokens sem lexeme_id com correspondência no léxico (somente leitura)." -ForegroundColor Cyan
  if ($SurveyScope -eq 'ot') {
    Invoke-Psql $surveyOtSql
  } else {
    Invoke-Psql $surveyBookSql
  }
  exit 0
}

$versesCsv = Join-Path $workDir ("bible_verse_book_{0}.csv" -f $BookId)
$versesCsvPsql = $versesCsv.Replace('\', '/').Replace("'", "''")
$exportVerses = "\copy (SELECT id, chapter, verse, text FROM public.bible_verse WHERE book_id = $BookId ORDER BY chapter, verse) TO '$versesCsvPsql' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
Invoke-Psql $exportVerses

$verseByRef = New-Object 'System.Collections.Generic.Dictionary[string,object]'
Import-Csv -LiteralPath $versesCsv -Encoding UTF8 | ForEach-Object {
  $key = ("{0}:{1}" -f $_.chapter, $_.verse)
  $verseByRef[$key] = [PSCustomObject]@{
    id = [int]$_.id
    chapter = [int]$_.chapter
    verse = [int]$_.verse
    text = [string]$_.text
  }
}

Write-Host ("Versos carregados do banco: {0}" -f $verseByRef.Count) -ForegroundColor DarkCyan

$outCsv = Join-Path $exportDir ("bible_verse_token_base_import.book_{0}.csv" -f $BookId)
$rows = New-Object System.Collections.Generic.List[object]
$sourceTag = "ARC auto-tokenize"

foreach ($refKey in $verseByRef.Keys) {
  $verseRow = $verseByRef[$refKey]
  $tokens = Tokenize-ArcVerse -Text $verseRow.text

  for ($i = 0; $i -lt $tokens.Count; $i++) {
    $t = $tokens[$i]
    $rows.Add([PSCustomObject]@{
      verse_id = $verseRow.id
      token_index = $i
      start_offset = $t.start
      end_offset = $t.end
      surface = $t.surface
      normalized = $null
      strong_code = $null
      confidence = $null
      source = $sourceTag
    })
  }
}

$rows | Export-Csv -LiteralPath $outCsv -NoTypeInformation -Encoding UTF8
Write-Host ("CSV gerado: {0}" -f $outCsv) -ForegroundColor Green
Write-Host ("Total tokens: {0}" -f $rows.Count) -ForegroundColor Green

$tokenizedVerses = @($rows | Select-Object -ExpandProperty verse_id -Unique).Count
Write-Host ("Versos tokenizados: {0} / {1}" -f $tokenizedVerses, $verseByRef.Count) -ForegroundColor DarkCyan

$minExpected = [int][math]::Max(1, [math]::Floor($verseByRef.Count * 0.9))
if ($tokenizedVerses -lt $minExpected) {
  throw ("Tokenização muito baixa para book_id={0}: versos tokenizados {1} < mínimo esperado {2}. " -f $BookId, $tokenizedVerses, $minExpected) +
        "Isso geralmente indica textos vazios no banco ou falha no script antes de importar."
}

Write-Host "Limpando tokens existentes do livro e carregando staging..." -ForegroundColor Cyan
Invoke-Psql "DELETE FROM public.bible_verse_token t USING public.bible_verse v WHERE t.verse_id = v.id AND v.book_id = $BookId;"
Invoke-Psql "TRUNCATE TABLE public.bible_verse_token_base_import;"

$psqlCsvPath = $outCsv.Replace('\', '/').Replace("'", "''")
$copyCommand = "\copy public.bible_verse_token_base_import (verse_id, token_index, start_offset, end_offset, surface, normalized, strong_code, confidence, source) FROM '$psqlCsvPath' WITH (FORMAT csv, HEADER true)"
Invoke-Psql $copyCommand

Invoke-Psql "SELECT count(*) AS base_import_rows FROM public.bible_verse_token_base_import;"
Invoke-Psql "SELECT public.merge_bible_verse_token_base_import(true, true) AS merged;"

Invoke-Psql "SELECT count(*) AS tokens_book FROM public.bible_verse_token t JOIN public.bible_verse v ON v.id=t.verse_id WHERE v.book_id = $BookId;"
Invoke-Psql "SELECT count(*) AS tokens_sem_lexeme FROM public.bible_verse_token t JOIN public.bible_verse v ON v.id=t.verse_id WHERE v.book_id = $BookId AND t.lexeme_id IS NULL;"

Write-Host "Validação do livro (tokens e offsets):" -ForegroundColor Cyan
Invoke-Psql "SELECT * FROM public.validate_bible_tokens_for_book($BookId);"

if ($AutoLinkFromGloss) {
  if ($AutoLinkDryRun) {
    Write-Host "AutoLinkFromGloss (dry-run): simulando vínculos por pt_gloss..." -ForegroundColor Cyan
    Invoke-Psql $autoLinkDryRunSql
  } else {
    Write-Host "AutoLinkFromGloss: aplicando vínculos por pt_gloss..." -ForegroundColor Cyan
    Invoke-Psql $autoLinkApplySql
    Write-Host "Validação após auto-link:" -ForegroundColor Cyan
    Invoke-Psql $validateSql
  }
}

if ($AutoLinkFromStepBibleCandidates) {
  if ($AutoLinkDryRun) {
    Write-Host "AutoLinkFromStepBibleCandidates (dry-run): simulando vínculos com candidatos do STEPBible..." -ForegroundColor Cyan
    try {
      Invoke-Psql "SELECT 1 FROM public.stepbible_original_token LIMIT 1;"
      Invoke-Psql $autoLinkStepBibleDryRunSql
    } catch {
      Write-Host "Tabela public.stepbible_original_token não encontrada; pulei o dry-run." -ForegroundColor Yellow
    }
  } else {
    Write-Host "AutoLinkFromStepBibleCandidates: aplicando vínculos com candidatos do STEPBible..." -ForegroundColor Cyan
    Invoke-Psql ("SELECT public.auto_link_bible_tokens_from_stepbible({0}, true, 0.7, 'stepbible candidate') AS tokens_vinculados;" -f $BookId)
    Write-Host "Validação após auto-link:" -ForegroundColor Cyan
    Invoke-Psql $validateSql
  }
}

Write-Host "Tokenização concluída." -ForegroundColor Green
