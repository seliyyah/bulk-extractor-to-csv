<#
.SYNOPSIS
    Converts bulk_extractor output files to CSV, for Timeline Explorer, Excel or any other CSV tool.

.DESCRIPTION
    bulk_extractor writes its results as tab-separated text files with '#' comment headers. On a memory image
    they easily reach hundreds of MB and hundreds of thousands of lines, which is too much for Notepad and awkward
    in most editors. This script turns each file into a CSV with a header row, so it can be filtered, sorted and
    searched like any other forensic CSV.

    Two file layouts are handled automatically:
      Feature files   (url.txt, domain.txt, email.txt, json.txt, ...)  -> Offset, Feature, Context, ContextClean
      Count lists     (url_searches.txt, url_services.txt, and the *_histogram.txt files with -IncludeHistograms)
                                                                       -> Count, Feature, Notes

    ContextClean is the Context column with bulk_extractor's '\000' escapes removed, so UTF-16 text such as
    'h\000t\000t\000p\000s' reads as 'https'. Context itself is kept exactly as bulk_extractor wrote it.

    The bulk_extractor output folder is only read; nothing in it is changed or deleted.

.PARAMETER Folder
    A bulk_extractor output folder (the folder given to bulk_extractor -o).

.PARAMETER Only
    Optional. Convert only these files, by name without .txt, e.g. -Only url,domain,email,url_searches

.PARAMETER OutputPath
    Optional. Where to write the CSV files. Default: a 'csv' subfolder of -Folder.

.PARAMETER IncludeHistograms
    Also convert the *_histogram.txt files (they are small and readable as they are, so they are skipped by default).

.EXAMPLE
    .\Convert-BeToCsv.ps1 -Folder E:\Analysis\case01_mem

.EXAMPLE
    .\Convert-BeToCsv.ps1 -Folder E:\Analysis\case01_mem -Only url,domain,email -OutputPath E:\Analysis\case01_csv

.NOTES
    Version 1.0.0. Windows PowerShell 5.1 or PowerShell 7. MIT License.
    https://github.com/seliyyah/bulk-extractor-to-csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][Alias('Path')][string]$Folder,
    [string[]]$Only,
    [string]$OutputPath,
    [switch]$IncludeHistograms
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { throw "Folder not found: $Folder" }
$Folder = (Resolve-Path -LiteralPath $Folder).ProviderPath
if (-not (Test-Path -LiteralPath (Join-Path $Folder 'report.xml'))) {
    Write-Warning "No report.xml in $Folder. Is this a bulk_extractor output folder? Continuing anyway."
}
if (-not $OutputPath) { $OutputPath = Join-Path $Folder 'csv' }
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$files = @(Get-ChildItem -LiteralPath $Folder -Filter '*.txt' -File | Where-Object {
    $_.Length -gt 0 -and ($IncludeHistograms -or $_.Name -notlike '*histogram*')
})
if ($Only) { $files = @($files | Where-Object { $Only -contains $_.BaseName }) }
if (-not $files.Count) { throw "No matching bulk_extractor .txt files found in $Folder" }

$utf8Bom = New-Object System.Text.UTF8Encoding $true    # BOM so Excel and Timeline Explorer read UTF-8 correctly
$total = [Diagnostics.Stopwatch]::StartNew()
$summary = foreach ($f in $files) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $dst = Join-Path $OutputPath ($f.BaseName + '.csv')
    $w = New-Object System.IO.StreamWriter($dst, $false, $utf8Bom)
    $rows = 0
    $layout = $null
    try {
        foreach ($l in [System.IO.File]::ReadLines($f.FullName)) {
            if ($l.Length -eq 0 -or $l[0] -eq '#') { continue }
            $p = $l.Split("`t")
            if (-not $layout) {
                # Count lists start with 'n=<count>'; feature files start with a byte offset.
                $layout = if ($p[0] -match '^n=\d+$') { 'Count list' } else { 'Features' }
                $w.WriteLine($(if ($layout -eq 'Count list') { 'Count,Feature,Notes' } else { 'Offset,Feature,Context,ContextClean' }))
            }
            # Quoting is written inline: a function call per row is very slow in Windows PowerShell 5.1.
            $feat = if ($p.Count -gt 1) { $p[1].Replace('"', '""') } else { '' }
            $rest = if ($p.Count -gt 2) { $p[2].Replace('"', '""') } else { '' }
            if ($layout -eq 'Count list') {
                $w.Write($p[0].Substring(2)); $w.Write(',"'); $w.Write($feat); $w.Write('","'); $w.Write($rest); $w.WriteLine('"')
            }
            else {
                $w.Write('"'); $w.Write($p[0].Replace('"', '""')); $w.Write('","'); $w.Write($feat); $w.Write('","')
                $w.Write($rest); $w.Write('","'); $w.Write($rest.Replace('\000', '')); $w.WriteLine('"')
            }
            $rows++
        }
    }
    finally { $w.Close() }
    if (-not $layout) { Remove-Item -LiteralPath $dst -Force; continue }   # only comments: nothing to convert
    [pscustomobject]@{ File = $f.Name; Layout = $layout; Rows = $rows; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}
$summary | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ('{0} file(s) converted in {1:N0} s. CSV files are in {2}' -f @($summary).Count, $total.Elapsed.TotalSeconds, $OutputPath)
