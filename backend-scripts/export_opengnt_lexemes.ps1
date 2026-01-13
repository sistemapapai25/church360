param(
  [string]$OutDir = "",
  [string]$SourceTag = "opengnt:OpenGNT_BASE_TEXT.zip@master"
)

$ErrorActionPreference = "Stop"

Write-Host "Church 360 - Exportando léxico (Strong/lemma/translit) do OpenGNT" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $PWD "out"
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$workDir = Join-Path $env:TEMP "church360_opengnt"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$zipUrl = "https://github.com/eliranwong/OpenGNT/raw/master/OpenGNT_BASE_TEXT.zip"
$zipPath = Join-Path $workDir "OpenGNT_BASE_TEXT.zip"

if (-not (Test-Path -LiteralPath $zipPath)) {
  Write-Host "Baixando: $zipUrl" -ForegroundColor Green
  Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing | Out-Null
}

$extractDir = Join-Path $workDir "extracted"
if (Test-Path -LiteralPath $extractDir) {
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

$csvCandidate = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter "OpenGNT_version*.csv" | Select-Object -First 1
if (-not $csvCandidate) {
  $csvCandidate = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter "*.csv" | Select-Object -First 1
}
if (-not $csvCandidate) {
  throw "Não encontrei CSV no zip do OpenGNT (OpenGNT_BASE_TEXT.zip)."
}

$baseTextPath = $csvCandidate.FullName
Write-Host "Base text: $baseTextPath" -ForegroundColor DarkCyan

function Split-Composite {
  param([string]$Value)
  if ($null -eq $Value) { return @() }
  $v = $Value.Trim()
  if ($v -eq "") { return @() }
  $v = $v.Trim("〔").Trim("〕").Trim()
  if ($v -eq "") { return @() }
  return ($v -split "[|｜]" | ForEach-Object { $_.Trim() })
}

function Normalize-StrongGreek {
  param([string]$SnValue)
  if ([string]::IsNullOrWhiteSpace($SnValue)) { return $null }
  $raw = $SnValue.Trim()
  $raw = $raw.Trim("G").Trim("g")

  $m = [regex]::Match($raw, "^(?<digits>\d{1,5})(?<suffix>[A-Za-z]{0,8})$")
  if (-not $m.Success) { return $null }

  $digits = $m.Groups["digits"].Value
  $suffix = $m.Groups["suffix"].Value.ToUpperInvariant()
  $paddedDigits = if ($digits.Length -ge 4) { $digits } else { $digits.PadLeft(4, "0") }
  return ("G{0}{1}" -f $paddedDigits, $suffix)
}

$records = New-Object 'System.Collections.Generic.Dictionary[string,object]'

$lines = Get-Content -LiteralPath $baseTextPath -Encoding UTF8
foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $cols = $line -split "`t"
  if ($cols.Length -lt 10) { continue }

  if ($cols[0] -eq "OGNTsort") { continue }

  $col8 = [string]$cols[7]
  $col10 = [string]$cols[9]

  $wordParts = Split-Composite $col8
  if ($wordParts.Count -lt 6) { continue }

  $lemma = $wordParts[3]
  $sn = $wordParts[5]
  $strongCode = Normalize-StrongGreek $sn
  if ([string]::IsNullOrWhiteSpace($strongCode)) { continue }

  $transParts = Split-Composite $col10
  $transliteration = $null
  if ($transParts.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($transParts[1])) {
    $transliteration = $transParts[1]
  } elseif ($transParts.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($transParts[0])) {
    $transliteration = $transParts[0]
  }

  $key = $strongCode.ToUpperInvariant()
  if (-not $records.ContainsKey($key)) {
    $records[$key] = [PSCustomObject]@{
      strong_code     = $strongCode
      language        = "greek"
      lemma           = ($lemma ?? "").Trim()
      transliteration = ($transliteration ?? "").Trim()
      source_tag      = $SourceTag
    }
    continue
  }

  $existing = $records[$key]
  $newLemma = ($lemma ?? "").Trim()
  $newTranslit = ($transliteration ?? "").Trim()

  if ([string]::IsNullOrWhiteSpace($existing.lemma) -and -not [string]::IsNullOrWhiteSpace($newLemma)) {
    $existing.lemma = $newLemma
  }
  if ([string]::IsNullOrWhiteSpace($existing.transliteration) -and -not [string]::IsNullOrWhiteSpace($newTranslit)) {
    $existing.transliteration = $newTranslit
  }
}

$outLexemeCsv = Join-Path $OutDir "bible_lexeme_base_import.opengnt.csv"
$outSourceCsv = Join-Path $OutDir "bible_lexeme_source.opengnt.csv"

$records.Values `
| Select-Object strong_code, language, lemma, transliteration `
| Sort-Object strong_code `
| Export-Csv -LiteralPath $outLexemeCsv -NoTypeInformation -Encoding UTF8

$records.Values `
| Select-Object strong_code, source_tag `
| Sort-Object strong_code `
| Export-Csv -LiteralPath $outSourceCsv -NoTypeInformation -Encoding UTF8

Write-Host ("Strong únicos (grego): {0}" -f $records.Count) -ForegroundColor Green
Write-Host "CSV para bible_lexeme_base_import: $outLexemeCsv" -ForegroundColor Green
Write-Host "CSV para rastreio (source): $outSourceCsv" -ForegroundColor Green
