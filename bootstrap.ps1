# Bootstrap script voor NewPC Setup
$ErrorActionPreference = 'Stop'

try {
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "NewPCSetup"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    # Download main script from GitHub Gist or your server
    $scriptUrl = "https://gist.githubusercontent.com/VenimK/246a96a920c401f88a9c37e41c8d00e5/raw/406eeb63a3509ae66a90b70ac7b6984701e58501/newpc_fixed.ps1"  # Replace with your actual URL
    $scriptPath = Join-Path $tempDir "newpc_fixed.ps1"
    
    # Set TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Download script
    Write-Host "Downloading setup script..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath
    
    # Run script with elevated privileges if needed
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    } else {
        & $scriptPath
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
