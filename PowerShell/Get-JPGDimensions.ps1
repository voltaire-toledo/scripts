Add-Type -AssemblyName System.Drawing
$jpgFiles = Get-ChildItem -Path "*.jpg"
foreach ($file in $jpgFiles) {
    $image = $null
    try {
        $image = [System.Drawing.Image]::FromFile($file.FullName)
        $width = $image.Width
        $height = $image.Height
        Write-Output "File: $file.Name, Width: $width, Height: $height"
    }
    finally {
        if ($null -ne $image) {
            $image.Dispose()
        }
    }
}