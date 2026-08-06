param(
  [Parameter(Mandatory = $true)]
  [string]$Root,

  [Parameter(Mandatory = $true)]
  [string[]]$Subfolders
)

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
  throw "The specified Root path does not exist or is not a directory: $Root"
}
$rootFull = (Resolve-Path -LiteralPath $Root).Path

$tasksPath = Join-Path $rootFull "TASKS.md"

$extensions = @(".jpg",".jpeg",".png",".webp",".bmp",".tif",".tiff",".gif",".heic")
$dimSuffixRegex = '_\d+x\d+$'

function Get-ExifDate($img) {
  $tagOriginal = 0x9003
  $tagDigitized = 0x9004
  foreach ($tag in @($tagOriginal, $tagDigitized)) {
    try {
      $pi = $img.GetPropertyItem($tag)
      if ($pi -and $pi.Value) {
        $raw = [System.Text.Encoding]::ASCII.GetString($pi.Value)
        $raw = $raw.Trim([char]0)
        if ($raw) {
          return [datetime]::ParseExact($raw, 'yyyy:MM:dd HH:mm:ss', $null)
        }
      }
    } catch { }
  }
  return $null
}

function Get-DimensionsAndDate($path) {
  $result = [ordered]@{ Width = $null; Height = $null; Date = $null }
  try {
    $img = [System.Drawing.Image]::FromFile($path)
    try {
      $result.Width = $img.Width
      $result.Height = $img.Height
      $result.Date = Get-ExifDate $img
    } finally {
      $img.Dispose()
    }
  } catch { }
  return $result
}

function Get-UniquePath($folder, $fileName) {
  $candidate = Join-Path $folder $fileName
  if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  $ext = [System.IO.Path]::GetExtension($fileName)
  $i = 1
  while ($true) {
    $name = "{0}_dup{1}{2}" -f $base, $i, $ext
    $candidate = Join-Path $folder $name
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $i++
  }
}

Add-Content -Path $tasksPath -Value ("`n## Script Run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Content -Path $tasksPath -Value ("Script: process-images.ps1")
Add-Content -Path $tasksPath -Value ("Root: " + $rootFull)
Add-Content -Path $tasksPath -Value ("Subfolders: " + ($Subfolders -join ', '))

$processed = 0
$skippedDim = 0
$movedUndetermined = 0
$lastPath = $null

foreach ($sub in $Subfolders) {
  $subPath = Join-Path $rootFull $sub
  if (-not (Test-Path -LiteralPath $subPath)) { continue }
  $dir = Get-Item -LiteralPath $subPath
  if (-not $dir.PSIsContainer) { continue }

  Get-ChildItem -LiteralPath $subPath -Recurse -File | Where-Object {
    $extensions -contains $_.Extension.ToLower()
  } | ForEach-Object {
    $file = $_
    if ($lastPath -eq $file.FullName) {
      Add-Content -Path $tasksPath -Value ("Loop detected at: " + $file.FullName)
      return
    }
    $lastPath = $file.FullName

    $info = Get-DimensionsAndDate $file.FullName
    if (-not $info.Width -or -not $info.Height) {
      $skippedDim++
      Add-Content -Path $tasksPath -Value ("Skipped (no dimensions): " + $file.FullName)
      $info = $null; $file = $null; return
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $ext = $file.Extension
    $hasSuffix = $base -match $dimSuffixRegex
    if (-not $hasSuffix) {
      $newName = "{0}_{1}x{2}{3}" -f $base, $info.Width, $info.Height, $ext
      $newPath = Join-Path $file.Directory.FullName $newName
      if ($newPath -ne $file.FullName) {
        Rename-Item -LiteralPath $file.FullName -NewName $newName
        $file = Get-Item -LiteralPath $newPath
      }
    }

    $year = $null
    if ($info.Date) {
      $year = $info.Date.Year
    } else {
      $year = $file.CreationTime.Year
      if (-not $year) { $year = $file.LastWriteTime.Year }
    }

    $destFolder = if ($year) { Join-Path $rootFull $year } else { Join-Path $rootFull "Undetermined" }
    if (-not (Test-Path -LiteralPath $destFolder)) {
      New-Item -ItemType Directory -Path $destFolder | Out-Null
    }
    if (-not $year) { $movedUndetermined++ }

    $destPath = Get-UniquePath $destFolder $file.Name
    if ($destPath -ne $file.FullName) {
      Move-Item -LiteralPath $file.FullName -Destination $destPath
    }

    Add-Content -Path $tasksPath -Value ("Processed: " + $destPath)
    $processed++

  }
}

Add-Content -Path $tasksPath -Value ("Summary: processed=" + $processed + ", skipped_no_dimensions=" + $skippedDim + ", moved_undetermined=" + $movedUndetermined)
