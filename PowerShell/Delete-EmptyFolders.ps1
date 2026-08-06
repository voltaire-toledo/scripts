param(
  [Parameter(Mandatory = $false)]
  [string]$Root = (Get-Location).Path
  ,
  [Parameter(Mandatory = $false)]
  [switch]$Force
  ,
  [Parameter(Mandatory = $false)]
  [switch]$HideProgress
)

if (-not $Force) {
    Write-Host "WARNING: This script will delete all empty subdirectories within: $Root" -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to proceed? (Y/N)"
    if ($confirmation -notmatch '^[yY]$') {
        Write-Host "Operation cancelled by user."
        exit
    }
}


Set-StrictMode -Version 3.0

$rootFull = (Resolve-Path -LiteralPath $Root).Path

function Write-Log {
    param($Message, $Color, $NoNewline = $false)
    if (-not $HideProgress) {
        Write-Host $Message -ForegroundColor $Color -NoNewline:$NoNewline
    }
}

# Delete empty directories under the root (excluding the root itself)
Get-ChildItem -LiteralPath $rootFull -Recurse -Directory | Sort-Object FullName -Descending | ForEach-Object {
  $dir = $_
  Write-Log "Processing: $($dir.FullName)..." Cyan -NoNewline $true
  if ($dir.FullName -eq $rootFull) {
    Write-Log "(skipping)" Yellow
    return
  }
  $hasChildren = Get-ChildItem -LiteralPath $dir.FullName -Force | Select-Object -First 1
  if (-not $hasChildren) {
    Remove-Item -LiteralPath $dir.FullName -Force
    Write-Log "Deleted" Green
  } else {
    Write-Log "Not empty" Yellow
  }
}
