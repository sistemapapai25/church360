param(
  [int]$BookId = 1,
  [string]$DbPasswordEnv = $env:SUPABASE_DB_PASSWORD,
  [ValidateSet('auto', 'pooler', 'direct')]
  [string]$DbMode = 'auto',
  [string]$OutDir = "",
  [switch]$SkipDb,
  [switch]$ForceRetokenize,
  [switch]$EnsureStepBibleOriginalSchema,
  [switch]$ImportTahotOriginalTokens,
  [switch]$ImportTahotOriginalTokensDryRun,
  [switch]$ImportTagntOriginalTokens,
  [switch]$ImportTagntOriginalTokensDryRun,
  [switch]$BackfillStepBibleTokenLexemeIds,
  [switch]$Phase4Auto,
  [int]$Phase4Chapter = 1,
  [int]$Phase4ChapterFrom = 0,
  [int]$Phase4ChapterTo = 0,
  [int]$Phase4VerseFrom = 1,
  [int]$Phase4VerseTo = 10,
  [switch]$Phase4DryRun,
  [double]$Phase4MinDominantRatio = 1.0,
  [int]$Phase4MinOccurrences = 2,
  [int]$Phase4MinSurfaceLength = 3,
  [double]$Phase4DefaultConfidence = 0.9,
  [switch]$OnlyAutoLink,
  [switch]$AutoLinkFromGloss,
  [switch]$AutoLinkFromStepBibleCandidates,
  [switch]$AutoLinkFromStepBibleCooccurrence,
  [switch]$AutoLinkDryRun,
  [switch]$BuildAlignmentFromLexemes,
  [switch]$LinkSingleToken,
  [string]$LinkSurface = "",
  [string]$LinkStrongCode = "",
  [int]$LinkChapter = 0,
  [int]$LinkVerse = 0,
  [switch]$LinkDryRun,
  [switch]$ApplyManualSeeds,
  [switch]$ManualSeedsDryRun,
  [switch]$DownloadTahotForBook,
  [switch]$DownloadTagntForBook,
  [switch]$SurveyMissingLexemeLinks,
  [ValidateSet('book', 'ot')]
  [string]$SurveyScope = 'book',
  [switch]$ReportCoverage,
  [switch]$ReportCoverageNt,
  [switch]$ReportOtRanking,
  [int]$ReportOtRankingLimit = 12,
  [switch]$ReportNtRanking,
  [int]$ReportNtRankingLimit = 12
)

Write-Host "Church 360 - Tokenização AT (ARC) por livro" -ForegroundColor Cyan

try {
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [Console]::OutputEncoding = $utf8
  $OutputEncoding = $utf8
} catch {}

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
    26 { return "Ezk" }
    27 { return "Dan" }
    28 { return "Hos" }
    29 { return "Jol" }
    30 { return "Amo" }
    31 { return "Oba" }
    32 { return "Jon" }
    33 { return "Mic" }
    34 { return "Nam" }
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
  $matches = [regex]::Matches($StrongTag.ToUpperInvariant(), "([HG]\d{4,5})(?:[A-Z]+)?")
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
    $env:SUPABASE_DB_PASSWORD = $PlainPassword
    $DbPasswordEnv = $PlainPassword
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
  $env:PGCLIENTENCODING = "UTF8"

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
      if ($Command -match "(\r|\n)") {
        $Command | & $psqlExe -h $a.host -p $a.port -U $a.user -d $PROJECT_DB -v ON_ERROR_STOP=1 -f -
      } else {
        & $psqlExe -h $a.host -p $a.port -U $a.user -d $PROJECT_DB -v ON_ERROR_STOP=1 -c $Command
      }
      if ($LASTEXITCODE -eq 0) { return }
      $lastErr = "psql falhou (exit code: $LASTEXITCODE) em modo $($a.label)"
    } catch {
      $lastErr = $_.Exception.Message
    }
  }

  if (-not $lastErr) { $lastErr = "psql falhou" }
  throw $lastErr
}

$ensureStepBibleOriginalSql = @'
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
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.auto_link_bible_tokens_from_stepbible(
  p_book_id int,
  p_only_missing boolean DEFAULT true,
  p_default_confidence real DEFAULT 0.7,
  p_source text DEFAULT 'stepbible candidate'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO off
AS $function$
DECLARE
  v_linked bigint := 0;
  v_testament text;
  v_language text;
BEGIN
  IF p_book_id IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_book') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_verse') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_verse_token') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_lexeme') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.stepbible_original_token') IS NULL THEN
    RETURN 0;
  END IF;

  SELECT testament INTO v_testament
  FROM public.bible_book
  WHERE id = p_book_id;

  v_language := CASE
    WHEN v_testament = 'OT' THEN 'hebrew'
    WHEN v_testament = 'NT' THEN 'greek'
    ELSE NULL
  END;

  IF v_language IS NULL THEN
    RETURN 0;
  END IF;

  WITH token_candidates AS (
    SELECT
      t.id AS token_id,
      v.book_id,
      v.chapter,
      v.verse,
      lower(trim(t.surface)) AS surface
    FROM public.bible_verse_token t
    JOIN public.bible_verse v ON v.id = t.verse_id
    WHERE v.book_id = p_book_id
      AND NULLIF(trim(t.surface), '') IS NOT NULL
      AND (NOT p_only_missing OR t.lexeme_id IS NULL)
  ),
  verse_lexemes AS (
    SELECT
      sot.book_id,
      sot.chapter,
      sot.verse,
      sot.lexeme_id
    FROM public.stepbible_original_token sot
    WHERE sot.book_id = p_book_id
      AND sot.lexeme_id IS NOT NULL
    GROUP BY sot.book_id, sot.chapter, sot.verse, sot.lexeme_id
  ),
  lexeme_gloss AS (
    SELECT
      lower(trim(l.pt_gloss)) AS gloss,
      l.id AS lexeme_id
    FROM public.bible_lexeme l
    WHERE l.language = v_language
      AND NULLIF(trim(l.pt_gloss), '') IS NOT NULL
  ),
  matches AS (
    SELECT
      tc.token_id,
      lg.lexeme_id,
      count(*) OVER (PARTITION BY tc.token_id) AS cnt
    FROM token_candidates tc
    JOIN lexeme_gloss lg ON lg.gloss = tc.surface
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
  ),
  updated AS (
    UPDATE public.bible_verse_token t
    SET
      lexeme_id = um.lexeme_id,
      confidence = COALESCE(t.confidence, p_default_confidence),
      source = CASE
        WHEN NULLIF(trim(t.source), '') IS NULL THEN p_source
        ELSE t.source || ' | ' || p_source
      END
    FROM unique_matches um
    WHERE t.id = um.token_id
    RETURNING 1
  )
  SELECT count(*) INTO v_linked FROM updated;

  RETURN v_linked;
END
$function$;

CREATE TABLE IF NOT EXISTS public.bible_verse_token_alignment (
  id BIGSERIAL PRIMARY KEY,
  verse_token_id BIGINT NOT NULL REFERENCES public.bible_verse_token(id) ON DELETE CASCADE,
  step_token_id BIGINT NOT NULL REFERENCES public.stepbible_original_token(id) ON DELETE CASCADE,
  confidence REAL,
  source TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(verse_token_id, step_token_id)
);

ALTER TABLE public.bible_verse_token_alignment ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Todos podem visualizar alinhamentos de tokens" ON public.bible_verse_token_alignment;
CREATE POLICY "Todos podem visualizar alinhamentos de tokens"
  ON public.bible_verse_token_alignment
  FOR SELECT
  USING (true);

CREATE INDEX IF NOT EXISTS idx_bible_verse_token_alignment_token
  ON public.bible_verse_token_alignment(verse_token_id);
CREATE INDEX IF NOT EXISTS idx_bible_verse_token_alignment_step_token
  ON public.bible_verse_token_alignment(step_token_id);

CREATE OR REPLACE FUNCTION public.build_bible_verse_token_alignment_for_book(
  p_book_id int,
  p_only_missing boolean DEFAULT true,
  p_default_confidence real DEFAULT 0.6,
  p_source text DEFAULT 'auto alignment'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO off
AS $function$
DECLARE
  v_aligned bigint := 0;
  v_testament text;
  v_language text;
BEGIN
  IF p_book_id IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_book') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_verse') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_verse_token') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.stepbible_original_token') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_verse_token_alignment') IS NULL THEN
    RETURN 0;
  END IF;

  SELECT testament INTO v_testament
  FROM public.bible_book
  WHERE id = p_book_id;

  v_language := CASE
    WHEN v_testament = 'OT' THEN 'hebrew'
    WHEN v_testament = 'NT' THEN 'greek'
    ELSE NULL
  END;

  IF v_language IS NULL THEN
    RETURN 0;
  END IF;

  WITH pt_tokens AS (
    SELECT
      t.id AS verse_token_id,
      v.book_id,
      v.chapter,
      v.verse,
      t.lexeme_id
    FROM public.bible_verse_token t
    JOIN public.bible_verse v ON v.id = t.verse_id
    WHERE v.book_id = p_book_id
      AND t.lexeme_id IS NOT NULL
  ),
  pt_counts AS (
    SELECT
      book_id,
      chapter,
      verse,
      lexeme_id,
      count(*) AS cnt
    FROM pt_tokens
    GROUP BY book_id, chapter, verse, lexeme_id
  ),
  step_tokens AS (
    SELECT
      sot.id AS step_token_id,
      sot.book_id,
      sot.chapter,
      sot.verse,
      sot.lexeme_id
    FROM public.stepbible_original_token sot
    WHERE sot.book_id = p_book_id
      AND sot.lexeme_id IS NOT NULL
  ),
  step_counts AS (
    SELECT
      book_id,
      chapter,
      verse,
      lexeme_id,
      count(*) AS cnt
    FROM step_tokens
    GROUP BY book_id, chapter, verse, lexeme_id
  ),
  candidates AS (
    SELECT
      pt.verse_token_id,
      st.step_token_id,
      pt.book_id,
      pt.chapter,
      pt.verse,
      pt.lexeme_id,
      pc.cnt AS pt_cnt,
      sc.cnt AS step_cnt
    FROM pt_tokens pt
    JOIN step_tokens st
      ON st.book_id = pt.book_id
      AND st.chapter = pt.chapter
      AND st.verse = pt.verse
      AND st.lexeme_id = pt.lexeme_id
    JOIN pt_counts pc
      ON pc.book_id = pt.book_id
      AND pc.chapter = pt.chapter
      AND pc.verse = pt.verse
      AND pc.lexeme_id = pt.lexeme_id
    JOIN step_counts sc
      ON sc.book_id = st.book_id
      AND sc.chapter = st.chapter
      AND sc.verse = st.verse
      AND sc.lexeme_id = st.lexeme_id
    WHERE pc.cnt = 1 AND sc.cnt = 1
  ),
  filtered AS (
    SELECT c.*
    FROM candidates c
    WHERE NOT p_only_missing
       OR NOT EXISTS (
         SELECT 1
         FROM public.bible_verse_token_alignment a
         WHERE a.verse_token_id = c.verse_token_id
       )
  ),
  inserted AS (
    INSERT INTO public.bible_verse_token_alignment (
      verse_token_id,
      step_token_id,
      confidence,
      source
    )
    SELECT
      f.verse_token_id,
      f.step_token_id,
      p_default_confidence,
      p_source
    FROM filtered f
    ON CONFLICT (verse_token_id, step_token_id) DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_aligned FROM inserted;

  RETURN v_aligned;
END
$function$;
'@

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
    41 { return "Mrk" }
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
    RAISE EXCEPTION 'LinkSurface is required';
  END IF;

  IF NULLIF(trim('__LINK_STRONG_RAW__'), '') IS NULL THEN
    RAISE EXCEPTION 'LinkStrongCode is required';
  END IF;

  IF __LINK_CHAPTER__ <= 0 OR __LINK_VERSE__ <= 0 THEN
    RAISE EXCEPTION 'LinkChapter and LinkVerse must be > 0';
  END IF;

  SELECT testament INTO v_book_testament
  FROM public.bible_book
  WHERE id = __BOOK_ID__;

  SELECT id INTO v_verse_id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__ AND chapter = __LINK_CHAPTER__ AND verse = __LINK_VERSE__;

  IF v_verse_id IS NULL THEN
    RAISE EXCEPTION 'Verse not found: book_id %, %:%', __BOOK_ID__, __LINK_CHAPTER__, __LINK_VERSE__;
  END IF;

  v_language := CASE
    WHEN upper(trim('__LINK_STRONG__')) LIKE 'H%' THEN 'hebrew'
    WHEN upper(trim('__LINK_STRONG__')) LIKE 'G%' THEN 'greek'
    ELSE NULL
  END;

  IF v_language IS NULL THEN
    RAISE EXCEPTION 'Invalid Strong code: %', upper(trim('__LINK_STRONG__'));
  END IF;

  IF v_book_testament = 'OT' AND v_language <> 'hebrew' THEN
    RAISE EXCEPTION 'OT book requires H..., got: %', upper(trim('__LINK_STRONG__'));
  END IF;
  IF v_book_testament = 'NT' AND v_language <> 'greek' THEN
    RAISE EXCEPTION 'NT book requires G..., got: %', upper(trim('__LINK_STRONG__'));
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
    RAISE EXCEPTION 'Token not found in verse: surface "%"', trim('__LINK_SURFACE__');
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

$reportCoverageSql = @"
WITH tok AS (
  SELECT
    count(*) AS tokens_total,
    count(*) FILTER (WHERE t.lexeme_id IS NOT NULL AND l.strong_code LIKE 'H%') AS tokens_lexeme_hebraico
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  LEFT JOIN public.bible_lexeme l ON l.id = t.lexeme_id
  WHERE v.book_id = $BookId
)
SELECT
  tokens_total,
  tokens_lexeme_hebraico,
  round((tokens_lexeme_hebraico::numeric / NULLIF(tokens_total,0)) * 100, 2) AS pct_hebraico
FROM tok;
"@

$reportCoverageNtSql = @"
WITH tok AS (
  SELECT
    count(*) AS tokens_total,
    count(*) FILTER (WHERE t.lexeme_id IS NOT NULL AND l.strong_code LIKE 'G%') AS tokens_lexeme_grego
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  LEFT JOIN public.bible_lexeme l ON l.id = t.lexeme_id
  WHERE v.book_id = $BookId
)
SELECT
  tokens_total,
  tokens_lexeme_grego,
  round((tokens_lexeme_grego::numeric / NULLIF(tokens_total,0)) * 100, 2) AS pct_grego
FROM tok;
"@

$reportOtRankingSql = @"
WITH book_tok AS (
  SELECT
    v.book_id,
    count(*) AS tokens_total,
    count(*) FILTER (WHERE t.lexeme_id IS NOT NULL AND l.strong_code LIKE 'H%') AS tokens_lexeme_hebraico
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  LEFT JOIN public.bible_lexeme l ON l.id = t.lexeme_id
  JOIN public.bible_book b ON b.id = v.book_id
  WHERE b.testament = 'OT'
  GROUP BY v.book_id
),
book_pct AS (
  SELECT
    book_id,
    tokens_total,
    tokens_lexeme_hebraico,
    round((tokens_lexeme_hebraico::numeric / NULLIF(tokens_total,0)) * 100, 2) AS pct_hebraico
  FROM book_tok
)
SELECT
  book_id,
  tokens_total,
  tokens_lexeme_hebraico,
  pct_hebraico
FROM book_pct
ORDER BY pct_hebraico ASC, book_id ASC
LIMIT $ReportOtRankingLimit;
"@

$reportNtRankingSql = @"
WITH book_tok AS (
  SELECT
    v.book_id,
    count(*) AS tokens_total,
    count(*) FILTER (WHERE t.lexeme_id IS NOT NULL AND l.strong_code LIKE 'G%') AS tokens_lexeme_grego
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  LEFT JOIN public.bible_lexeme l ON l.id = t.lexeme_id
  JOIN public.bible_book b ON b.id = v.book_id
  WHERE b.testament = 'NT'
  GROUP BY v.book_id
),
book_pct AS (
  SELECT
    book_id,
    tokens_total,
    tokens_lexeme_grego,
    round((tokens_lexeme_grego::numeric / NULLIF(tokens_total,0)) * 100, 2) AS pct_grego
  FROM book_tok
)
SELECT
  book_id,
  tokens_total,
  tokens_lexeme_grego,
  pct_grego
FROM book_pct
ORDER BY pct_grego ASC, book_id ASC
LIMIT $ReportNtRankingLimit;
"@

$forceRetokenizeSql = "false"
if ($ForceRetokenize) { $forceRetokenizeSql = "true" }

$retokenizeGuardSqlTemplate = @'
DO $$
DECLARE
  v_tokens bigint := 0;
  v_linked bigint := 0;
  v_align bigint := 0;
BEGIN
  SELECT count(*) INTO v_tokens
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = __BOOK_ID__;

  SELECT count(*) INTO v_linked
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = __BOOK_ID__
    AND t.lexeme_id IS NOT NULL;

  SELECT count(*) INTO v_align
  FROM public.bible_verse_token_alignment a
  JOIN public.bible_verse_token t ON t.id = a.verse_token_id
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = __BOOK_ID__;

  IF (NOT __FORCE_RETOKENIZE__) AND (v_linked > 0 OR v_align > 0) THEN
    RAISE EXCEPTION
      'Blocked: retokenizing book_id=% would erase links (tokens with lexeme_id=%; alignments=%). Use -ForceRetokenize, or run -OnlyAutoLink / -Phase4Auto.',
      __BOOK_ID__, v_linked, v_align;
  END IF;
END $$;
'@

$retokenizeGuardSql = $retokenizeGuardSqlTemplate
$retokenizeGuardSql = $retokenizeGuardSql.Replace('__BOOK_ID__', [string]$BookId)
$retokenizeGuardSql = $retokenizeGuardSql.Replace('__FORCE_RETOKENIZE__', $forceRetokenizeSql)

$invariant = [System.Globalization.CultureInfo]::InvariantCulture

$phase4VerseScopeSqlTemplate = @'
WITH target_verses AS (
  SELECT id, chapter, verse
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
)
SELECT
  count(*) AS versos_no_escopo,
  min(chapter) AS chapter_min,
  min(verse) AS verse_min,
  max(verse) AS verse_max
FROM target_verses;
'@

$phase4ScopeTokenMetricsSqlTemplate = @'
WITH target_verses AS (
  SELECT id, chapter, verse
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
tokens AS (
  SELECT
    t.id,
    lower(trim(t.surface)) AS surface,
    t.lexeme_id
  FROM public.bible_verse_token t
  WHERE t.verse_id IN (SELECT id FROM target_verses)
)
SELECT
  (SELECT count(*) FROM target_verses) AS versos_no_escopo,
  count(*) AS tokens_pt,
  count(*) FILTER (WHERE lexeme_id IS NOT NULL) AS tokens_pt_com_lexeme,
  count(*) FILTER (WHERE lexeme_id IS NULL) AS tokens_pt_sem_lexeme,
  count(DISTINCT surface) FILTER (WHERE lexeme_id IS NULL) AS superficies_sem_lexeme
FROM tokens;
'@

$phase4InheritFromAlignmentDryRunSqlTemplate = @'
WITH target_verses AS (
  SELECT id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
candidates AS (
  SELECT
    t0.id AS token_id,
    lower(trim(t0.surface)) AS surface,
    sot.lexeme_id
  FROM public.bible_verse_token_alignment a
  JOIN public.stepbible_original_token sot
    ON sot.id = a.step_token_id
  JOIN public.bible_verse_token t0
    ON t0.id = a.verse_token_id
  WHERE t0.verse_id IN (SELECT id FROM target_verses)
    AND t0.lexeme_id IS NULL
    AND sot.lexeme_id IS NOT NULL
)
SELECT
  count(*) AS tokens_que_seriam_vinculados,
  count(DISTINCT surface) AS superficies_unicas
FROM candidates;
'@

$phase4InheritFromAlignmentApplySqlTemplate = @'
WITH target_verses AS (
  SELECT id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
candidates AS (
  SELECT
    t0.id AS token_id,
    sot.lexeme_id
  FROM public.bible_verse_token_alignment a
  JOIN public.stepbible_original_token sot
    ON sot.id = a.step_token_id
  JOIN public.bible_verse_token t0
    ON t0.id = a.verse_token_id
  WHERE t0.verse_id IN (SELECT id FROM target_verses)
    AND t0.lexeme_id IS NULL
    AND sot.lexeme_id IS NOT NULL
),
updated AS (
  UPDATE public.bible_verse_token t
  SET
    lexeme_id = c.lexeme_id,
    confidence = COALESCE(t.confidence, 1.0),
    source = CASE
      WHEN NULLIF(trim(t.source), '') IS NULL THEN 'alignment inherit'
      ELSE t.source || ' | alignment inherit'
    END
  FROM candidates c
  WHERE t.id = c.token_id
  RETURNING 1
)
SELECT count(*) AS tokens_vinculados
FROM updated;
'@

$phase4DominantSurfaceSurveySqlTemplate = @'
WITH target_verses AS (
  SELECT id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
tokens AS (
  SELECT
    t.id AS token_id,
    lower(trim(t.surface)) AS surface,
    t.lexeme_id
  FROM public.bible_verse_token t
  WHERE t.verse_id IN (SELECT id FROM target_verses)
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
surface_lexeme AS (
  SELECT
    surface,
    lexeme_id,
    count(*) AS cnt
  FROM tokens
  WHERE lexeme_id IS NOT NULL
    AND length(surface) >= __MIN_SURFACE_LEN__
  GROUP BY surface, lexeme_id
),
surface_totals AS (
  SELECT
    surface,
    sum(cnt) AS total_cnt,
    max(cnt) AS max_cnt,
    count(*) AS variants
  FROM surface_lexeme
  GROUP BY surface
),
dominant AS (
  SELECT
    sl.surface,
    sl.lexeme_id,
    sl.cnt,
    st.total_cnt,
    (sl.cnt::float / NULLIF(st.total_cnt, 0)) AS ratio
  FROM surface_lexeme sl
  JOIN surface_totals st
    ON st.surface = sl.surface
    AND st.max_cnt = sl.cnt
  WHERE st.variants = 1
    AND st.total_cnt >= __MIN_OCCURRENCES__
    AND (sl.cnt::float / NULLIF(st.total_cnt, 0)) >= __MIN_DOM_RATIO__
)
SELECT
  surface,
  lexeme_id,
  cnt,
  total_cnt,
  ratio
FROM dominant
ORDER BY total_cnt DESC, surface ASC
LIMIT 200;
'@

$phase4DominantSurfaceDryRunSqlTemplate = @'
WITH target_verses AS (
  SELECT id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
tokens AS (
  SELECT
    t.id AS token_id,
    lower(trim(t.surface)) AS surface,
    t.lexeme_id
  FROM public.bible_verse_token t
  WHERE t.verse_id IN (SELECT id FROM target_verses)
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
surface_lexeme AS (
  SELECT
    surface,
    lexeme_id,
    count(*) AS cnt
  FROM tokens
  WHERE lexeme_id IS NOT NULL
    AND length(surface) >= __MIN_SURFACE_LEN__
  GROUP BY surface, lexeme_id
),
surface_totals AS (
  SELECT
    surface,
    sum(cnt) AS total_cnt,
    max(cnt) AS max_cnt,
    count(*) AS variants
  FROM surface_lexeme
  GROUP BY surface
),
dominant AS (
  SELECT
    sl.surface,
    sl.lexeme_id
  FROM surface_lexeme sl
  JOIN surface_totals st
    ON st.surface = sl.surface
    AND st.max_cnt = sl.cnt
  WHERE st.variants = 1
    AND st.total_cnt >= __MIN_OCCURRENCES__
    AND (sl.cnt::float / NULLIF(st.total_cnt, 0)) >= __MIN_DOM_RATIO__
),
candidates AS (
  SELECT t.token_id
  FROM tokens t
  JOIN dominant d ON d.surface = t.surface
  WHERE t.lexeme_id IS NULL
)
SELECT
  count(*) AS tokens_que_seriam_vinculados,
  (SELECT count(*) FROM dominant) AS superficies_dominantes
FROM candidates;
'@

$phase4DominantSurfaceApplySqlTemplate = @'
WITH target_verses AS (
  SELECT id
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
tokens AS (
  SELECT
    t.id AS token_id,
    lower(trim(t.surface)) AS surface,
    t.lexeme_id
  FROM public.bible_verse_token t
  WHERE t.verse_id IN (SELECT id FROM target_verses)
    AND NULLIF(trim(t.surface), '') IS NOT NULL
),
surface_lexeme AS (
  SELECT
    surface,
    lexeme_id,
    count(*) AS cnt
  FROM tokens
  WHERE lexeme_id IS NOT NULL
    AND length(surface) >= __MIN_SURFACE_LEN__
  GROUP BY surface, lexeme_id
),
surface_totals AS (
  SELECT
    surface,
    sum(cnt) AS total_cnt,
    max(cnt) AS max_cnt,
    count(*) AS variants
  FROM surface_lexeme
  GROUP BY surface
),
dominant AS (
  SELECT
    sl.surface,
    sl.lexeme_id
  FROM surface_lexeme sl
  JOIN surface_totals st
    ON st.surface = sl.surface
    AND st.max_cnt = sl.cnt
  WHERE st.variants = 1
    AND st.total_cnt >= __MIN_OCCURRENCES__
    AND (sl.cnt::float / NULLIF(st.total_cnt, 0)) >= __MIN_DOM_RATIO__
),
candidates AS (
  SELECT
    t.token_id,
    d.lexeme_id
  FROM tokens t
  JOIN dominant d
    ON d.surface = t.surface
  WHERE t.lexeme_id IS NULL
),
updated AS (
  UPDATE public.bible_verse_token t
  SET
    lexeme_id = c.lexeme_id,
    confidence = COALESCE(t.confidence, __DEFAULT_CONF__),
    source = CASE
      WHEN NULLIF(trim(t.source), '') IS NULL THEN 'surface dominant'
      ELSE t.source || ' | surface dominant'
    END
  FROM candidates c
  WHERE t.id = c.token_id
  RETURNING 1
)
SELECT count(*) AS tokens_vinculados
FROM updated;
'@

$phase4PerVerseMetricsSqlTemplate = @'
WITH target_verses AS (
  SELECT id, verse
  FROM public.bible_verse
  WHERE book_id = __BOOK_ID__
    AND chapter = __PHASE4_CHAPTER__
    AND verse BETWEEN __VERSE_FROM__ AND __VERSE_TO__
),
tokens AS (
  SELECT
    v.verse,
    t.id,
    t.lexeme_id
  FROM public.bible_verse_token t
  JOIN target_verses v ON v.id = t.verse_id
)
SELECT
  verse,
  count(*) AS tokens_pt,
  count(*) FILTER (WHERE lexeme_id IS NOT NULL) AS tokens_pt_com_lexeme
FROM tokens
GROUP BY verse
ORDER BY verse ASC;
'@

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

$ensureAutoLinkStepBibleCooccurrenceFnSql = @'
CREATE OR REPLACE FUNCTION public.auto_link_bible_tokens_from_stepbible_cooccurrence(
  p_book_id int,
  p_only_missing boolean DEFAULT true,
  p_min_co_verses int DEFAULT 3,
  p_min_precision real DEFAULT 0.6,
  p_min_surface_len int DEFAULT 3,
  p_default_confidence real DEFAULT 0.75,
  p_source text DEFAULT 'stepbible cooccurrence'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO off
AS $function$
DECLARE
  v_linked bigint := 0;
BEGIN
  IF p_book_id IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_verse') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_verse_token') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.stepbible_original_token') IS NULL THEN
    RETURN 0;
  END IF;
  IF to_regclass('public.bible_lexeme') IS NULL THEN
    RETURN 0;
  END IF;

  WITH pt_tokens AS (
    SELECT
      v.book_id,
      v.chapter,
      v.verse,
      t.id AS token_id,
      lower(trim(t.surface)) AS surface
    FROM public.bible_verse_token t
    JOIN public.bible_verse v ON v.id = t.verse_id
    WHERE v.book_id = p_book_id
      AND NULLIF(trim(t.surface), '') IS NOT NULL
      AND length(lower(trim(t.surface))) >= p_min_surface_len
      AND (NOT p_only_missing OR t.lexeme_id IS NULL)
  ),
  pt_verse_surface AS (
    SELECT book_id, chapter, verse, surface
    FROM pt_tokens
    GROUP BY book_id, chapter, verse, surface
  ),
  step_verse_strong AS (
    SELECT
      sot.book_id,
      sot.chapter,
      sot.verse,
      regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1') AS strong_code
    FROM public.stepbible_original_token sot
    WHERE sot.book_id = p_book_id
      AND NULLIF(trim(sot.strong_code), '') IS NOT NULL
      AND NULLIF(trim(regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1')), '') IS NOT NULL
    GROUP BY
      sot.book_id,
      sot.chapter,
      sot.verse,
      regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1')
  ),
  strong_verses AS (
    SELECT strong_code, count(*) AS verses_cnt
    FROM step_verse_strong
    GROUP BY strong_code
  ),
  surface_verses AS (
    SELECT surface, count(*) AS verses_cnt
    FROM pt_verse_surface
    GROUP BY surface
  ),
  co AS (
    SELECT
      s.strong_code,
      p.surface,
      count(*) AS co_verses
    FROM step_verse_strong s
    JOIN pt_verse_surface p
      ON p.book_id = s.book_id
      AND p.chapter = s.chapter
      AND p.verse = s.verse
    GROUP BY s.strong_code, p.surface
  ),
  scored AS (
    SELECT
      co.strong_code,
      co.surface,
      co.co_verses,
      sv.verses_cnt AS strong_verses,
      pv.verses_cnt AS surface_verses,
      (co.co_verses::real / NULLIF(sv.verses_cnt, 0)) AS precision
    FROM co
    JOIN strong_verses sv ON sv.strong_code = co.strong_code
    JOIN surface_verses pv ON pv.surface = co.surface
    WHERE co.co_verses >= p_min_co_verses
  ),
  best_for_strong AS (
    SELECT
      s.*,
      row_number() OVER (
        PARTITION BY strong_code
        ORDER BY precision DESC, co_verses DESC, surface_verses ASC, surface ASC
      ) AS rn
    FROM scored s
    WHERE precision >= p_min_precision
  ),
  best_strong_pick AS (
    SELECT strong_code, surface
    FROM best_for_strong
    WHERE rn = 1
  ),
  best_for_surface AS (
    SELECT
      s.*,
      row_number() OVER (
        PARTITION BY surface
        ORDER BY precision DESC, co_verses DESC, strong_code ASC
      ) AS rn
    FROM scored s
    WHERE precision >= p_min_precision
  ),
  mutual AS (
    SELECT b.strong_code, b.surface
    FROM best_strong_pick b
    JOIN best_for_surface s
      ON s.surface = b.surface
      AND s.strong_code = b.strong_code
      AND s.rn = 1
  ),
  target_lexeme AS (
    SELECT
      m.strong_code,
      m.surface,
      l.id AS lexeme_id
    FROM mutual m
    JOIN public.bible_lexeme l
      ON l.strong_code = m.strong_code
  ),
  eligible_tokens AS (
    SELECT DISTINCT
      pt.token_id,
      tl.lexeme_id
    FROM pt_tokens pt
    JOIN target_lexeme tl
      ON tl.surface = pt.surface
    JOIN step_verse_strong sv
      ON sv.book_id = pt.book_id
      AND sv.chapter = pt.chapter
      AND sv.verse = pt.verse
      AND sv.strong_code = tl.strong_code
  ),
  updated AS (
    UPDATE public.bible_verse_token t
    SET
      lexeme_id = e.lexeme_id,
      confidence = COALESCE(t.confidence, p_default_confidence),
      source = CASE
        WHEN NULLIF(trim(t.source), '') IS NULL THEN p_source
        ELSE t.source || ' | ' || p_source
      END
    FROM eligible_tokens e
    WHERE t.id = e.token_id
    RETURNING 1
  )
  SELECT count(*) INTO v_linked
  FROM updated;

  RETURN v_linked;
END
$function$;
'@

$autoLinkStepBibleCooccurrenceDryRunSql = @"
WITH pt_tokens AS (
  SELECT
    v.book_id,
    v.chapter,
    v.verse,
    t.id AS token_id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
    AND length(lower(trim(t.surface))) >= 3
),
pt_verse_surface AS (
  SELECT book_id, chapter, verse, surface
  FROM pt_tokens
  GROUP BY book_id, chapter, verse, surface
),
step_verse_strong AS (
  SELECT
    sot.book_id,
    sot.chapter,
    sot.verse,
    regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1') AS strong_code
  FROM public.stepbible_original_token sot
  WHERE sot.book_id = $BookId
    AND NULLIF(trim(sot.strong_code), '') IS NOT NULL
    AND NULLIF(trim(regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1')), '') IS NOT NULL
  GROUP BY
    sot.book_id,
    sot.chapter,
    sot.verse,
    regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1')
),
strong_verses AS (
  SELECT strong_code, count(*) AS verses_cnt
  FROM step_verse_strong
  GROUP BY strong_code
),
surface_verses AS (
  SELECT surface, count(*) AS verses_cnt
  FROM pt_verse_surface
  GROUP BY surface
),
co AS (
  SELECT
    s.strong_code,
    p.surface,
    count(*) AS co_verses
  FROM step_verse_strong s
  JOIN pt_verse_surface p
    ON p.book_id = s.book_id
    AND p.chapter = s.chapter
    AND p.verse = s.verse
  GROUP BY s.strong_code, p.surface
),
scored AS (
  SELECT
    co.strong_code,
    co.surface,
    co.co_verses,
    sv.verses_cnt AS strong_verses,
    pv.verses_cnt AS surface_verses,
    (co.co_verses::real / NULLIF(sv.verses_cnt, 0)) AS precision
  FROM co
  JOIN strong_verses sv ON sv.strong_code = co.strong_code
  JOIN surface_verses pv ON pv.surface = co.surface
  WHERE co.co_verses >= 3
    AND (co.co_verses::real / NULLIF(sv.verses_cnt, 0)) >= 0.6
),
best_for_strong AS (
  SELECT
    s.*,
    row_number() OVER (
      PARTITION BY strong_code
      ORDER BY precision DESC, co_verses DESC, surface_verses ASC, surface ASC
    ) AS rn
  FROM scored s
),
best_strong_pick AS (
  SELECT strong_code, surface
  FROM best_for_strong
  WHERE rn = 1
),
best_for_surface AS (
  SELECT
    s.*,
    row_number() OVER (
      PARTITION BY surface
      ORDER BY precision DESC, co_verses DESC, strong_code ASC
    ) AS rn
  FROM scored s
),
mutual AS (
  SELECT b.strong_code, b.surface
  FROM best_strong_pick b
  JOIN best_for_surface s
    ON s.surface = b.surface
    AND s.strong_code = b.strong_code
    AND s.rn = 1
),
eligible_tokens AS (
  SELECT DISTINCT
    pt.token_id
  FROM pt_tokens pt
  JOIN mutual m
    ON m.surface = pt.surface
  JOIN step_verse_strong sv
    ON sv.book_id = pt.book_id
    AND sv.chapter = pt.chapter
    AND sv.verse = pt.verse
    AND sv.strong_code = m.strong_code
)
SELECT
  (SELECT count(*) FROM mutual) AS mapeamentos_strong_surface,
  (SELECT count(*) FROM eligible_tokens) AS tokens_que_seriam_vinculados;
"@

$autoLinkStepBibleCooccurrenceApplySql = @"
WITH pt_tokens AS (
  SELECT
    v.book_id,
    v.chapter,
    v.verse,
    t.id AS token_id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = $BookId
    AND t.lexeme_id IS NULL
    AND NULLIF(trim(t.surface), '') IS NOT NULL
    AND length(lower(trim(t.surface))) >= 3
),
pt_verse_surface AS (
  SELECT book_id, chapter, verse, surface
  FROM pt_tokens
  GROUP BY book_id, chapter, verse, surface
),
step_verse_strong AS (
  SELECT
    sot.book_id,
    sot.chapter,
    sot.verse,
    regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1') AS strong_code
  FROM public.stepbible_original_token sot
  WHERE sot.book_id = $BookId
    AND NULLIF(trim(sot.strong_code), '') IS NOT NULL
    AND NULLIF(trim(regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1')), '') IS NOT NULL
  GROUP BY
    sot.book_id,
    sot.chapter,
    sot.verse,
    regexp_replace(upper(trim(sot.strong_code)), '^([HG][0-9]{1,5}).*$', '\1')
),
strong_verses AS (
  SELECT strong_code, count(*) AS verses_cnt
  FROM step_verse_strong
  GROUP BY strong_code
),
surface_verses AS (
  SELECT surface, count(*) AS verses_cnt
  FROM pt_verse_surface
  GROUP BY surface
),
co AS (
  SELECT
    s.strong_code,
    p.surface,
    count(*) AS co_verses
  FROM step_verse_strong s
  JOIN pt_verse_surface p
    ON p.book_id = s.book_id
    AND p.chapter = s.chapter
    AND p.verse = s.verse
  GROUP BY s.strong_code, p.surface
),
scored AS (
  SELECT
    co.strong_code,
    co.surface,
    co.co_verses,
    sv.verses_cnt AS strong_verses,
    pv.verses_cnt AS surface_verses,
    (co.co_verses::real / NULLIF(sv.verses_cnt, 0)) AS precision
  FROM co
  JOIN strong_verses sv ON sv.strong_code = co.strong_code
  JOIN surface_verses pv ON pv.surface = co.surface
  WHERE co.co_verses >= 3
),
best_for_strong AS (
  SELECT
    s.*,
    row_number() OVER (
      PARTITION BY strong_code
      ORDER BY precision DESC, co_verses DESC, surface_verses ASC, surface ASC
    ) AS rn
  FROM scored s
  WHERE precision >= 0.6
),
best_strong_pick AS (
  SELECT strong_code, surface
  FROM best_for_strong
  WHERE rn = 1
),
best_for_surface AS (
  SELECT
    s.*,
    row_number() OVER (
      PARTITION BY surface
      ORDER BY precision DESC, co_verses DESC, strong_code ASC
    ) AS rn
  FROM scored s
  WHERE precision >= 0.6
),
mutual AS (
  SELECT b.strong_code, b.surface
  FROM best_strong_pick b
  JOIN best_for_surface s
    ON s.surface = b.surface
    AND s.strong_code = b.strong_code
    AND s.rn = 1
),
target_lexeme AS (
  SELECT
    m.strong_code,
    m.surface,
    l.id AS lexeme_id
  FROM mutual m
  JOIN public.bible_lexeme l
    ON l.strong_code = m.strong_code
),
eligible_tokens AS (
  SELECT DISTINCT
    pt.token_id,
    tl.lexeme_id
  FROM pt_tokens pt
  JOIN target_lexeme tl
    ON tl.surface = pt.surface
  JOIN step_verse_strong sv
    ON sv.book_id = pt.book_id
    AND sv.chapter = pt.chapter
    AND sv.verse = pt.verse
    AND sv.strong_code = tl.strong_code
),
updated AS (
  UPDATE public.bible_verse_token t
  SET
    lexeme_id = e.lexeme_id,
    confidence = COALESCE(t.confidence, 0.75),
    source = CASE
      WHEN NULLIF(trim(t.source), '') IS NULL THEN 'stepbible cooccurrence'
      ELSE t.source || ' | ' || 'stepbible cooccurrence'
    END
  FROM eligible_tokens e
  WHERE t.id = e.token_id
    AND t.lexeme_id IS NULL
  RETURNING 1
)
SELECT count(*) AS tokens_vinculados
FROM updated;
"@

if ($BackfillStepBibleTokenLexemeIds) {
  Write-Host "Modo BackfillStepBibleTokenLexemeIds: vou normalizar strong_code e preencher lexeme_id no STEPBible." -ForegroundColor Cyan
  $backfillSql = @"
WITH normalized AS (
  SELECT
    id,
    book_id,
    regexp_replace(upper(trim(strong_code)), '^([HG][0-9]{1,5}).*$', '\1') AS strong_code_norm
  FROM public.stepbible_original_token
  WHERE book_id = $BookId
    AND NULLIF(trim(strong_code), '') IS NOT NULL
),
src AS (
  SELECT DISTINCT
    strong_code_norm AS strong_code
  FROM normalized
  WHERE NULLIF(trim(strong_code_norm), '') IS NOT NULL
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
),
updated AS (
  UPDATE public.stepbible_original_token sot
  SET
    strong_code = n.strong_code_norm,
    lexeme_id = l.id
  FROM normalized n
  JOIN public.bible_lexeme l
    ON l.strong_code = n.strong_code_norm
  WHERE sot.id = n.id
    AND (sot.lexeme_id IS NULL OR sot.strong_code IS DISTINCT FROM n.strong_code_norm)
  RETURNING 1
)
SELECT
  (SELECT count(*) FROM upserted) AS lexemes_upserted,
  (SELECT count(*) FROM updated) AS step_tokens_updated,
  (SELECT count(*) FROM public.stepbible_original_token WHERE book_id = $BookId AND lexeme_id IS NULL AND NULLIF(trim(strong_code), '') IS NOT NULL) AS step_tokens_ainda_sem_lexeme;
"@
  Invoke-Psql $backfillSql
  exit 0
}

if ($ReportCoverage -or $ReportCoverageNt -or $ReportOtRanking -or $ReportNtRanking) {
  if ($ReportCoverage) {
    Write-Host "Relatório: cobertura (H%) do livro" -ForegroundColor Cyan
    Invoke-Psql $reportCoverageSql
  }

  if ($ReportCoverageNt) {
    Write-Host "Relatório: cobertura (G%) do livro" -ForegroundColor Cyan
    Invoke-Psql $reportCoverageNtSql
  }

  if ($ReportOtRanking) {
    Write-Host ("Relatório: ranking OT (menores H%) - top {0}" -f $ReportOtRankingLimit) -ForegroundColor Cyan
    Invoke-Psql $reportOtRankingSql
  }

  if ($ReportNtRanking) {
    Write-Host ("Relatório: ranking NT (menores G%) - top {0}" -f $ReportNtRankingLimit) -ForegroundColor Cyan
    Invoke-Psql $reportNtRankingSql
  }

  exit 0
}

if ($BuildAlignmentFromLexemes) {
  Write-Host "Modo BuildAlignmentFromLexemes: vou criar alinhamentos ARC<->STEP por lexeme." -ForegroundColor Cyan
  Invoke-Psql ("SELECT public.build_bible_verse_token_alignment_for_book({0}, true, 0.6, 'auto alignment') AS alinhamentos_criados;" -f $BookId)
  exit 0
}

if ($Phase4Auto) {
  try {
    Invoke-Psql "SELECT 1 FROM public.stepbible_original_token LIMIT 1;"
    Invoke-Psql "SELECT 1 FROM public.bible_verse_token_alignment LIMIT 1;"
  } catch {
    throw "Faltam tabelas public.stepbible_original_token e/ou public.bible_verse_token_alignment para Phase4Auto."
  }

  $chapters = @($Phase4Chapter)
  if ($Phase4ChapterFrom -gt 0 -and $Phase4ChapterTo -gt 0 -and $Phase4ChapterTo -ge $Phase4ChapterFrom) {
    $chapters = @($Phase4ChapterFrom..$Phase4ChapterTo)
  }

  foreach ($ch in $chapters) {
    $Phase4Chapter = $ch
    $minDomRatioSql = $Phase4MinDominantRatio.ToString($invariant)
    $defaultConfidenceSql = $Phase4DefaultConfidence.ToString($invariant)

    $phase4VerseScopeSql = $phase4VerseScopeSqlTemplate
    $phase4VerseScopeSql = $phase4VerseScopeSql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4VerseScopeSql = $phase4VerseScopeSql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4VerseScopeSql = $phase4VerseScopeSql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4VerseScopeSql = $phase4VerseScopeSql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)

    $phase4ScopeTokenMetricsSql = $phase4ScopeTokenMetricsSqlTemplate
    $phase4ScopeTokenMetricsSql = $phase4ScopeTokenMetricsSql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4ScopeTokenMetricsSql = $phase4ScopeTokenMetricsSql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4ScopeTokenMetricsSql = $phase4ScopeTokenMetricsSql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4ScopeTokenMetricsSql = $phase4ScopeTokenMetricsSql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)

    $phase4InheritFromAlignmentDryRunSql = $phase4InheritFromAlignmentDryRunSqlTemplate
    $phase4InheritFromAlignmentDryRunSql = $phase4InheritFromAlignmentDryRunSql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4InheritFromAlignmentDryRunSql = $phase4InheritFromAlignmentDryRunSql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4InheritFromAlignmentDryRunSql = $phase4InheritFromAlignmentDryRunSql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4InheritFromAlignmentDryRunSql = $phase4InheritFromAlignmentDryRunSql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)

    $phase4InheritFromAlignmentApplySql = $phase4InheritFromAlignmentApplySqlTemplate
    $phase4InheritFromAlignmentApplySql = $phase4InheritFromAlignmentApplySql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4InheritFromAlignmentApplySql = $phase4InheritFromAlignmentApplySql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4InheritFromAlignmentApplySql = $phase4InheritFromAlignmentApplySql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4InheritFromAlignmentApplySql = $phase4InheritFromAlignmentApplySql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)

    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySqlTemplate
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__MIN_SURFACE_LEN__', [string]$Phase4MinSurfaceLength)
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__MIN_OCCURRENCES__', [string]$Phase4MinOccurrences)
    $phase4DominantSurfaceSurveySql = $phase4DominantSurfaceSurveySql.Replace('__MIN_DOM_RATIO__', $minDomRatioSql)

    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSqlTemplate
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__MIN_SURFACE_LEN__', [string]$Phase4MinSurfaceLength)
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__MIN_OCCURRENCES__', [string]$Phase4MinOccurrences)
    $phase4DominantSurfaceDryRunSql = $phase4DominantSurfaceDryRunSql.Replace('__MIN_DOM_RATIO__', $minDomRatioSql)

    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySqlTemplate
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__MIN_SURFACE_LEN__', [string]$Phase4MinSurfaceLength)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__MIN_OCCURRENCES__', [string]$Phase4MinOccurrences)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__MIN_DOM_RATIO__', $minDomRatioSql)
    $phase4DominantSurfaceApplySql = $phase4DominantSurfaceApplySql.Replace('__DEFAULT_CONF__', $defaultConfidenceSql)

    $phase4PerVerseMetricsSql = $phase4PerVerseMetricsSqlTemplate
    $phase4PerVerseMetricsSql = $phase4PerVerseMetricsSql.Replace('__BOOK_ID__', [string]$BookId)
    $phase4PerVerseMetricsSql = $phase4PerVerseMetricsSql.Replace('__PHASE4_CHAPTER__', [string]$Phase4Chapter)
    $phase4PerVerseMetricsSql = $phase4PerVerseMetricsSql.Replace('__VERSE_FROM__', [string]$Phase4VerseFrom)
    $phase4PerVerseMetricsSql = $phase4PerVerseMetricsSql.Replace('__VERSE_TO__', [string]$Phase4VerseTo)

    Write-Host ("Modo Phase4Auto: book_id={0} {1}:{2}-{3}" -f $BookId, $Phase4Chapter, $Phase4VerseFrom, $Phase4VerseTo) -ForegroundColor Cyan
    Invoke-Psql $phase4VerseScopeSql

    Write-Host "Phase4: métricas do escopo (antes)..." -ForegroundColor Cyan
    Invoke-Psql $phase4ScopeTokenMetricsSql

    Write-Host "Phase4: herança via alinhamentos (dry-run)..." -ForegroundColor Cyan
    Invoke-Psql $phase4InheritFromAlignmentDryRunSql

    Write-Host "Phase4: superfícies dominantes detectadas..." -ForegroundColor Cyan
    Invoke-Psql $phase4DominantSurfaceSurveySql

    Write-Host "Phase4: propagação por superfície dominante (dry-run)..." -ForegroundColor Cyan
    Invoke-Psql $phase4DominantSurfaceDryRunSql

    if (-not $Phase4DryRun) {
      Write-Host "Phase4: aplicando herança via alinhamentos..." -ForegroundColor Cyan
      Invoke-Psql $phase4InheritFromAlignmentApplySql

      Write-Host "Phase4: aplicando propagação por superfície dominante..." -ForegroundColor Cyan
      Invoke-Psql $phase4DominantSurfaceApplySql

      Write-Host "Phase4: métricas do escopo (depois)..." -ForegroundColor Cyan
      Invoke-Psql $phase4ScopeTokenMetricsSql

      Write-Host "Phase4: métricas por verso no escopo..." -ForegroundColor Cyan
      Invoke-Psql $phase4PerVerseMetricsSql
    } else {
      Write-Host "Phase4DryRun ativo: nada foi alterado no banco." -ForegroundColor Yellow
    }
  }

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

  if ($AutoLinkFromStepBibleCooccurrence) {
    if ($AutoLinkDryRun) {
      Write-Host "AutoLinkFromStepBibleCooccurrence (dry-run): simulando vínculos por coocorrência (Strong <-> surface)..." -ForegroundColor Cyan
      Invoke-Psql $autoLinkStepBibleCooccurrenceDryRunSql
    } else {
      Write-Host "AutoLinkFromStepBibleCooccurrence: aplicando vínculos por coocorrência (Strong <-> surface)..." -ForegroundColor Cyan
      $prevDbMode = $DbMode
      $DbMode = 'direct'
      try {
        Invoke-Psql $autoLinkStepBibleCooccurrenceApplySql
      } finally {
        $DbMode = $prevDbMode
      }
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

if ($ApplyManualSeeds) {
  if ($SkipDb) {
    throw "ApplyManualSeeds requer acesso ao banco (não use -SkipDb)."
  }

  $seeds = @(
    @{ surface = "jesus"; strong_code = "G2424" }
    @{ surface = "deus"; strong_code = "G2316" }
    @{ surface = "senhor"; strong_code = "G2962" }
    @{ surface = "cristo"; strong_code = "G5547" }
    @{ surface = "pai"; strong_code = "G3962" }
    @{ surface = "filho"; strong_code = "G5207" }
    @{ surface = "homem"; strong_code = "G0444" }
    @{ surface = "discípulos"; strong_code = "G3101" }
    @{ surface = "discÃ­pulos"; strong_code = "G3101" }
    @{ surface = "reino"; strong_code = "G0932" }
    @{ surface = "vida"; strong_code = "G2222" }
    @{ surface = "verdade"; strong_code = "G0225" }
    @{ surface = "fé"; strong_code = "G4102" }
    @{ surface = "fÃ©"; strong_code = "G4102" }
    @{ surface = "pecado"; strong_code = "G0266" }
    @{ surface = "amor"; strong_code = "G0026" }
    @{ surface = "espírito"; strong_code = "G4151" }
    @{ surface = "espÃ­rito"; strong_code = "G4151" }
    @{ surface = "terra"; strong_code = "G1093" }
    @{ surface = "céu"; strong_code = "G3772" }
    @{ surface = "céus"; strong_code = "G3772" }
    @{ surface = "cÃ©u"; strong_code = "G3772" }
    @{ surface = "cÃ©us"; strong_code = "G3772" }
    @{ surface = "disse"; strong_code = "G3004" }
    @{ surface = "disse-lhes"; strong_code = "G3004" }
    @{ surface = "graça"; strong_code = "G5485" }
    @{ surface = "graÃ§a"; strong_code = "G5485" }
    @{ surface = "paz"; strong_code = "G1515" }
    @{ surface = "irmãos"; strong_code = "G0080" }
    @{ surface = "irmÃ£os"; strong_code = "G0080" }
    @{ surface = "igreja"; strong_code = "G1577" }
    @{ surface = "salvação"; strong_code = "G4991" }
    @{ surface = "salvaÃ§Ã£o"; strong_code = "G4991" }
    @{ surface = "glória"; strong_code = "G1391" }
    @{ surface = "glÃ³ria"; strong_code = "G1391" }
    @{ surface = "paulo"; strong_code = "G3972" }
    @{ surface = "timóteo"; strong_code = "G5095" }
    @{ surface = "timÃ³teo"; strong_code = "G5095" }
    @{ surface = "evangelho"; strong_code = "G2098" }
    @{ surface = "joão"; strong_code = "G2491" }
    @{ surface = "joÃ£o"; strong_code = "G2491" }
    @{ surface = "maria"; strong_code = "G3137" }
    @{ surface = "israel"; strong_code = "G2474" }
    @{ surface = "davi"; strong_code = "G1138" }
    @{ surface = "jerusalém"; strong_code = "G2414" }
    @{ surface = "jerusalÃ©m"; strong_code = "G2414" }
    @{ surface = "anjo"; strong_code = "G0032" }
    @{ surface = "anjos"; strong_code = "G0032" }
    @{ surface = "outra"; strong_code = "G3825" }
    @{ surface = "tudo"; strong_code = "G3745" }
    @{ surface = "muitos"; strong_code = "G4183" }
    @{ surface = "povo"; strong_code = "G2992" }
    @{ surface = "fora"; strong_code = "G1854" }
    @{ surface = "palavra"; strong_code = "G3056" }
    @{ surface = "mulher"; strong_code = "G1135" }
    @{ surface = "mortos"; strong_code = "G3498" }
    @{ surface = "então"; strong_code = "G5119" }
    @{ surface = "entÃ£o"; strong_code = "G5119" }
    @{ surface = "caminho"; strong_code = "G3598" }
    @{ surface = "lugar"; strong_code = "G5117" }
    @{ surface = "alguém"; strong_code = "G5100" }
    @{ surface = "alguÃ©m"; strong_code = "G5100" }
    @{ surface = "pães"; strong_code = "G0740" }
    @{ surface = "pÃ£es"; strong_code = "G0740" }
    @{ surface = "hora"; strong_code = "G5610" }
    @{ surface = "assentado"; strong_code = "G2521" }
    @{ surface = "cidade"; strong_code = "G4172" }
    @{ surface = "dois"; strong_code = "G1417" }
    @{ surface = "morte"; strong_code = "G2288" }
    @{ surface = "primeiro"; strong_code = "G4413" }
    @{ surface = "vestes"; strong_code = "G2440" }
    @{ surface = "coração"; strong_code = "G2588" }
    @{ surface = "coraÃ§Ã£o"; strong_code = "G2588" }
    @{ surface = "cada"; strong_code = "G1538" }
    @{ surface = "três"; strong_code = "G5140" }
    @{ surface = "trÃªs"; strong_code = "G5140" }
    @{ surface = "fogo"; strong_code = "G4442" }
    @{ surface = "parábola"; strong_code = "G3850" }
    @{ surface = "parÃ¡bola"; strong_code = "G3850" }
    @{ surface = "pois"; strong_code = "G5028" }
    @{ surface = "digo"; strong_code = "G0281" }
    @{ surface = "fariseus"; strong_code = "G5330" }
    @{ surface = "irmão"; strong_code = "G0080" }
    @{ surface = "irmÃ£o"; strong_code = "G0080" }
    @{ surface = "qualquer"; strong_code = "G0302" }
    @{ surface = "escribas"; strong_code = "G1122" }
    @{ surface = "diante"; strong_code = "G1715" }
    @{ surface = "campo"; strong_code = "G0068" }
    @{ surface = "sacerdotes"; strong_code = "G0749" }
    @{ surface = "servo"; strong_code = "G1401" }
  )

  Write-Host ("Modo ApplyManualSeeds: book_id={0} seeds={1} dry_run={2}" -f $BookId, $seeds.Count, $ManualSeedsDryRun) -ForegroundColor Cyan
  Invoke-Psql ("SELECT id AS book_id, testament FROM public.bible_book WHERE id = {0};" -f $BookId)

  $seedDryRunSqlTemplate = @'
WITH target_tokens AS (
  SELECT
    t.id,
    lower(trim(t.surface)) AS surface
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = __BOOK_ID__
    AND t.lexeme_id IS NULL
    AND lower(trim(t.surface)) = lower(trim('__SURFACE__'))
)
SELECT
  '__SURFACE__' AS surface,
  '__STRONG__' AS strong_code,
  count(*) AS tokens_missing_lexeme
FROM target_tokens;
'@

  $seedApplySqlTemplate = @'
WITH upserted AS (
  INSERT INTO public.bible_lexeme (strong_code, language, updated_at)
  VALUES (upper(trim('__STRONG__')), 'greek', now())
  ON CONFLICT (strong_code) DO UPDATE SET
    language = EXCLUDED.language,
    updated_at = now()
  RETURNING id
),
lex AS (
  SELECT id FROM upserted
  UNION ALL
  SELECT l.id
  FROM public.bible_lexeme l
  WHERE l.strong_code = upper(trim('__STRONG__'))
    AND NOT EXISTS (SELECT 1 FROM upserted)
  LIMIT 1
),
target_tokens AS (
  SELECT t.id
  FROM public.bible_verse_token t
  JOIN public.bible_verse v ON v.id = t.verse_id
  WHERE v.book_id = __BOOK_ID__
    AND t.lexeme_id IS NULL
    AND lower(trim(t.surface)) = lower(trim('__SURFACE__'))
),
updated AS (
  UPDATE public.bible_verse_token t2
  SET
    lexeme_id = (SELECT id FROM lex),
    confidence = 1.0,
    source = CASE
      WHEN NULLIF(trim(t2.source), '') IS NULL THEN '__SOURCE__'
      ELSE t2.source || ' | ' || '__SOURCE__'
    END
  FROM target_tokens tt
  WHERE t2.id = tt.id
  RETURNING 1
)
SELECT
  '__SURFACE__' AS surface,
  '__STRONG__' AS strong_code,
  (SELECT count(*) FROM target_tokens) AS tokens_missing_lexeme,
  (SELECT count(*) FROM updated) AS tokens_updated;
'@

  foreach ($seed in $seeds) {
    $surfaceSql = ([string]$seed.surface).Replace("'", "''")
    $strongSql = ([string]$seed.strong_code).Replace("'", "''")
    $sourceSql = ("manual seed {0}" -f $strongSql).Replace("'", "''")

    if ($ManualSeedsDryRun) {
      $sql = $seedDryRunSqlTemplate
      $sql = $sql.Replace('__BOOK_ID__', [string]$BookId)
      $sql = $sql.Replace('__SURFACE__', $surfaceSql)
      $sql = $sql.Replace('__STRONG__', $strongSql)
      Invoke-Psql $sql
    } else {
      $sql = $seedApplySqlTemplate
      $sql = $sql.Replace('__BOOK_ID__', [string]$BookId)
      $sql = $sql.Replace('__SURFACE__', $surfaceSql)
      $sql = $sql.Replace('__STRONG__', $strongSql)
      $sql = $sql.Replace('__SOURCE__', $sourceSql)
      Invoke-Psql $sql
    }
  }

  Write-Host "Validação após seeds:" -ForegroundColor Cyan
  Invoke-Psql $validateSql
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
Invoke-Psql $retokenizeGuardSql
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
