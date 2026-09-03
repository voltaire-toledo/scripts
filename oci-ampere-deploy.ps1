param(
    [Parameter(Mandatory=$true)]
    [string]$CompartmentId,

    [Parameter(Mandatory=$true)]
    [string]$SubnetId,

    [Parameter(Mandatory=$true)]
    [string]$ImageId,

    [Parameter(Mandatory=$false)]
    [string[]]$AvailabilityDomains = @(
        "YourRegionKey:US-CHICAGO-1-AD-1",
        "YourRegionKey:US-CHICAGO-1-AD-2",
        "YourRegionKey:US-CHICAGO-1-AD-3"
    ),

    [Parameter(Mandatory=$false)]
    [string]$SshKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
)

$Env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING="True"

$Shape = "VM.Standard.A1.Flex"
$Ocpus = 2
$MemoryInGBs = 12
$BootVolumeSize = 100

Write-Host "Starting OCI Ampere VM deployment script..." -ForegroundColor Cyan
Write-Host "Target: $Ocpus OCPU, ${MemoryInGBs}GB RAM, Ubuntu" -ForegroundColor Cyan

$success = $false
$attempt = 1

while (-not $success) {
    foreach ($ad in $AvailabilityDomains) {
        Write-Host "`n[Attempt $attempt] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Attempting AD: $ad..."
        
        $output = oci compute instance launch `
            --compartment-id $CompartmentId `
            --availability-domain $ad `
            --shape $Shape `
            --shape-config "{`"ocpus`": $Ocpus, `"memoryInGBs`": $MemoryInGBs}" `
            --subnet-id $SubnetId `
            --image-id $ImageId `
            --boot-volume-size-in-gbs $BootVolumeSize `
            --assign-public-ip true `
            --display-name "Ampere-Free-Tier-VM" `
            --ssh-authorized-keys-file $SshKeyFile `
            2>&1

        $outputStr = $output | Out-String

        if ($LASTEXITCODE -eq 0 -and $outputStr -match "PROVISIONING") {
            Write-Host "`nSuccess! Your Ampere VM is being provisioned in $ad." -ForegroundColor Green
            $success = $true
            break
        } elseif ($outputStr -match "Out of host capacity") {
            Write-Host "Out of capacity in $ad." -ForegroundColor Yellow
        } elseif ($outputStr -match "TooManyRequests") {
            Write-Host "Rate limited by Oracle (TooManyRequests). Cooling down..." -ForegroundColor DarkYellow
        } else {
            Write-Host "`nAn unexpected error occurred in ${ad}:" -ForegroundColor Red
            Write-Host $outputStr
        }

        if (-not $success) {
            Start-Sleep -Seconds 15
        }
    }
    
    if (-not $success) {
        Write-Host "Cycle complete. Retrying in 120 seconds..." -ForegroundColor Magenta
        Start-Sleep -Seconds 120
        $attempt++
    }
}
