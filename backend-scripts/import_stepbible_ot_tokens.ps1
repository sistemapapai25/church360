param(
  [int]$BookId = 1,
  [string]$DbPasswordEnv = $env:SUPABASE_DB_PASSWORD,
  [string]$OutDir = "",
  [switch]$SkipDb,
  [switch]$OnlyAutoLink,
  [switch]$AutoLinkFromGloss,
  [switch]$AutoLinkDryRun,
  [switch]$SurveyMissingLexemeLinks,
  [ValidateSet('book', 'ot')]
  [string]$SurveyScope = 'book'
)

Write-Host "Church 360 - Tokenização AT (ARC) por livro" -ForegroundColor Cyan

$PROJECT_HOST = "aws-0-sa-east-1.pooler.supabase.com"
$PROJECT_PORT = 6543
$PROJECT_DB   = "postgres"
$PROJECT_USER = "postgres.heswheljavpcyspuicsi"

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

$workDir = Get-DefaultWorkDir
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$exportDir = $workDir
if (-not [string]::IsNullOrWhiteSpace($OutDir)) {
  $exportDir = $OutDir
}
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

if ($SkipDb) {
  Write-Host "SkipDb ativo: nada a fazer sem acesso ao banco." -ForegroundColor Yellow
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

Write-Host "Tokenização concluída." -ForegroundColor Green
