# Test script for PC serial number and index functionality
Set-ExecutionPolicy Bypass -Scope Process -Force

# Function to write log messages
function Write-LogMessage {
    param([string]$Message)
    Write-Host $Message
}

# Function to show progress
function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

# Function to get PC serial number
function Get-PCSerialNumber {
    try {
        $serialNumber = (Get-WmiObject -Class Win32_Bios).SerialNumber
        return $serialNumber.Trim()
    }
    catch {
        Write-Host "Fout bij ophalen serienummer: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij ophalen serienummer: $($_.Exception.Message)"
        return "Niet beschikbaar"
    }
}

# Function to download and open index file
function Open-IndexFile {
    try {
        Write-Host "`nIndex bestand downloaden en openen..." -ForegroundColor Yellow
        Write-LogMessage "Start download en openen index bestand"

        Show-Progress -Activity "Index Bestand" -Status "Voorbereiden..." -PercentComplete 10

        # Get PC Serial Number
        $serialNumber = Get-PCSerialNumber
        Write-Host "PC Serienummer: $serialNumber" -ForegroundColor Cyan

        # Create temp directory if it doesn't exist
        $tempDir = Join-Path $env:TEMP "IndexDownload"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }

        Show-Progress -Activity "Index Bestand" -Status "Downloaden..." -PercentComplete 30
        
        # Download index file
        $indexUrl = "https://raw.githubusercontent.com/VenimK/MusicLover/main/index_updated.html"
        $indexPath = Join-Path $tempDir "index.html"
        
        Write-Host "`nIndex bestand downloaden..." -ForegroundColor Cyan
        Write-LogMessage "Index bestand downloaden"
        
        try {
            $webClient = New-Object System.Net.WebClient
            $content = $webClient.DownloadString($indexUrl)
            
            # Inject JavaScript to set serial number
            $injectedScript = @"
<script>
    window.addEventListener('load', function() {
        var serialInput = document.getElementById('client-serial');
        if (serialInput) {
            serialInput.value = '$serialNumber';
            serialInput.readOnly = true;
        }
    });
</script>
</head>
"@
            
            # Insert the script before the closing head tag
            $content = $content -replace '</head>', $injectedScript
            
            # Save modified content
            [System.IO.File]::WriteAllText($indexPath, $content)
        }
        catch {
            throw "Index bestand download mislukt: $($_.Exception.Message)"
        }

        Show-Progress -Activity "Index Bestand" -Status "Chrome openen..." -PercentComplete 80
        
        # Start Chrome minimized
        try {
            Start-Process chrome.exe -ArgumentList $indexPath -WindowStyle Minimized
            Start-Sleep -Seconds 2
        }
        catch {
            throw "Chrome starten mislukt: $($_.Exception.Message)"
        }

        Show-Progress -Activity "Index Bestand" -Status "Gereed" -PercentComplete 100
        Write-Host "`nIndex bestand succesvol geopend in Chrome (geminimaliseerd)" -ForegroundColor Green
        Write-LogMessage "Index bestand succesvol geopend in Chrome (geminimaliseerd)"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-LogMessage "Index bestand openen mislukt: $errorMsg"
        Write-Host "`nIndex bestand openen mislukt: $errorMsg" -ForegroundColor Red
        Show-Progress -Activity "Index Bestand" -Status "Mislukt" -PercentComplete 100
        return $false
    }
}

# Main execution
try {
    Write-Host "=== Test Script Serienummer en Index ===" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    Open-IndexFile

    Write-Host "`nTest succesvol afgerond!" -ForegroundColor Green
}
catch {
    Write-Host "Er is een fout opgetreden: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogMessage "Script fout: $($_.Exception.Message)"
}
