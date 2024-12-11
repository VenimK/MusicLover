# Script configuratie
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$logFile = Join-Path $env:TEMP "newpc_setup.log"

# Function to log messages
function Write-LogMessage {
    param(
        [string]$Message
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        Add-Content -Path $logFile -Value $logMessage
    }
    catch {
        Write-Warning "Kon niet loggen naar bestand: $($_.Exception.Message)"
    }
}

# WiFi Connection Function
function Connect-ToWiFi {
    param (
        [string]$SSID = "Music lover",
        [string]$Password = "1234poiu"
    )
    
    Write-Host "Automatisch verbinden met $SSID..." -ForegroundColor Yellow
    Write-LogMessage "Poging tot verbinden met WiFi netwerk: $SSID"

    try {
        # Controleer of het netwerk bestaat
        $networks = (netsh wlan show networks) -join "`n"
        if ($networks -notmatch [regex]::Escape($SSID)) {
            throw "Netwerk $SSID niet gevonden"
        }

        Write-Host "Netwerk $SSID gevonden. Bezig met verbinden..." -ForegroundColor Yellow
        
        # Maak een tijdelijk profiel XML
        $hexSSID = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($SSID)).Replace("-","")
        $profileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <name>$SSID</name>
            <hex>$hexSSID</hex>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
        # Voeg het profiel toe
        $profilePath = "$env:TEMP\WiFiProfile.xml"
        $profileXml | Set-Content $profilePath -Encoding UTF8
        $addResult = netsh wlan add profile filename="$profilePath"
        Remove-Item $profilePath -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -ne 0) {
            throw "Fout bij toevoegen WiFi profiel: $addResult"
        }

        # Probeer verbinding te maken met het netwerk
        $connectResult = netsh wlan connect name="$SSID"
        if ($LASTEXITCODE -ne 0) {
            throw "Fout bij verbinden: $connectResult"
        }
        
        # Wacht even om de verbindingsstatus te controleren
        Write-Host "Wachten op verbinding..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Controleer of we verbonden zijn
        $interfaces = (netsh wlan show interfaces) -join "`n"
        if ($interfaces -notmatch [regex]::Escape($SSID)) {
            throw "Kan niet verbinden met $SSID"
        }

        Write-Host "Succesvol verbonden met $SSID" -ForegroundColor Green
        Write-LogMessage "Succesvol verbonden met WiFi netwerk: $SSID"
        return $true
    }
    catch {
        Write-Host "WiFi Fout: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "WiFi Fout: $($_.Exception.Message)"
        return $false
    }
}

# Function to install Windows Update module if needed
function Install-WindowsUpdateModule {
    Write-Host "Windows Update PowerShell module controleren..." -ForegroundColor Yellow
    Write-LogMessage "Windows Update PowerShell module controle gestart"
    
    try {
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "PSWindowsUpdate module installeren..." -ForegroundColor Yellow
            Install-Module -Name PSWindowsUpdate -Force -AllowClobber
            Write-LogMessage "PSWindowsUpdate module geïnstalleerd"
        }
        Import-Module PSWindowsUpdate
        return $true
    }
    catch {
        Write-Host "Fout bij installeren Windows Update module: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij installeren Windows Update module: $($_.Exception.Message)"
        return $false
    }
}

# Function to check and install Windows Updates
function Install-WindowsUpdates {
    Write-Host "Windows Updates controleren en installeren..." -ForegroundColor Yellow
    Write-LogMessage "Windows Updates proces gestart"
    
    try {
        if (-not (Install-WindowsUpdateModule)) {
            throw "Kon Windows Update module niet installeren"
        }

        # Check for all updates including optional ones
        Write-Host "Beschikbare updates controleren (inclusief optionele updates)..." -ForegroundColor Yellow
        
        # Get regular updates
        $regularUpdates = Get-WindowsUpdate
        
        # Get optional updates
        $optionalUpdates = Get-WindowsUpdate -IsHidden
        
        $totalUpdates = $regularUpdates.Count + $optionalUpdates.Count

        if ($totalUpdates -eq 0) {
            Write-Host "Geen updates beschikbaar (regulier of optioneel)" -ForegroundColor Green
            Write-LogMessage "Geen Windows Updates beschikbaar"
            return $true
        }

        Write-Host "Gevonden updates:" -ForegroundColor Yellow
        Write-Host "- Reguliere updates: $($regularUpdates.Count)" -ForegroundColor Yellow
        Write-Host "- Optionele updates: $($optionalUpdates.Count)" -ForegroundColor Yellow
        Write-LogMessage "Gevonden: $($regularUpdates.Count) reguliere updates, $($optionalUpdates.Count) optionele updates"

        # Install regular updates
        if ($regularUpdates.Count -gt 0) {
            Write-Host "Reguliere updates worden geinstalleerd..." -ForegroundColor Yellow
            Install-WindowsUpdate -AcceptAll -AutoReboot:$false -Verbose | Out-File (Join-Path $env:TEMP "Windows_Regular_Updates_Log.txt")
        }

        # Install optional updates
        if ($optionalUpdates.Count -gt 0) {
            Write-Host "Optionele updates worden geinstalleerd..." -ForegroundColor Yellow
            Install-WindowsUpdate -AcceptAll -AutoReboot:$false -IsHidden -Verbose | Out-File (Join-Path $env:TEMP "Windows_Optional_Updates_Log.txt")
        }
        
        Write-Host "Alle Windows Updates succesvol geinstalleerd (regulier en optioneel)" -ForegroundColor Green
        Write-LogMessage "Alle Windows Updates succesvol geinstalleerd"
        return $true
    }
    catch {
        Write-Host "Fout bij Windows Updates: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij Windows Updates: $($_.Exception.Message)"
        return $false
    }
}

# Function to check Node.js installation
function Test-NodeJS {
    Write-Host "Node.js installatie controleren..." -ForegroundColor Yellow
    Write-LogMessage "Node.js installatie controle gestart"
    
    try {
        # Add Node.js to PATH if it exists
        $nodePath = "C:\Program Files\nodejs"
        if (Test-Path $nodePath) {
            $env:Path = "$env:Path;$nodePath"
        }
        
        $nodeVersion = node -v
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Node.js gevonden: $nodeVersion" -ForegroundColor Green
            Write-LogMessage "Node.js gevonden: $nodeVersion"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to install Node.js using winget
function Install-NodeJS {
    Write-Host "Node.js installeren via winget..." -ForegroundColor Yellow
    Write-LogMessage "Node.js installatie gestart via winget"
    
    try {
        Write-Progress -Activity "Node.js Installatie" -Status "Node.js installeren..." -PercentComplete 20
        
        # Uninstall existing Node.js if present (silent)
        winget uninstall OpenJS.NodeJS.LTS --silent 2>$null
        Start-Sleep -Seconds 2
        
        # Install Node.js LTS
        winget install --id OpenJS.NodeJS.LTS --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Winget installatie mislukt"
        }
        
        Write-Progress -Activity "Node.js Installatie" -Status "PATH bijwerken..." -PercentComplete 80
        
        # Add Node.js to PATH
        $nodePath = "C:\Program Files\nodejs"
        $env:Path = "$env:Path;$nodePath"
        
        Write-Host "Node.js succesvol geinstalleerd" -ForegroundColor Green
        Write-LogMessage "Node.js installatie succesvol"
        Write-Progress -Activity "Node.js Installatie" -Completed
        
        return $true
    }
    catch {
        Write-Host "Fout bij Node.js installatie: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij Node.js installatie: $($_.Exception.Message)"
        Write-Progress -Activity "Node.js Installatie" -Completed
        return $false
    }
}

# Function to install npm packages
function Install-NpmPackages {
    Write-Host "NPM packages installeren..." -ForegroundColor Yellow
    Write-LogMessage "NPM packages installatie gestart"
    
    try {
        # Navigate to server directory
        Set-Location -Path $PSScriptRoot
        
        # Check if package.json exists
        if (-not (Test-Path "package.json")) {
            throw "package.json niet gevonden in: $PSScriptRoot"
        }
        
        Write-Progress -Activity "NPM Packages" -Status "Dependencies installeren..." -PercentComplete 50
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "NPM install commando mislukt"
        }
        
        Write-Host "NPM packages succesvol geinstalleerd" -ForegroundColor Green
        Write-LogMessage "NPM packages succesvol geinstalleerd"
        Write-Progress -Activity "NPM Packages" -Completed
        return $true
    }
    catch {
        Write-Host "Fout bij NPM packages installatie: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij NPM packages installatie: $($_.Exception.Message)"
        Write-Progress -Activity "NPM Packages" -Completed
        return $false
    }
}

# Function to start Node.js server
function Start-NodeServer {
    Write-Host "Node.js server starten..." -ForegroundColor Yellow
    Write-LogMessage "Node.js server wordt gestart"
    
    try {
        # Start server.js in a new window
        $serverPath = Join-Path $PSScriptRoot "server.js"
        if (-not (Test-Path $serverPath)) {
            throw "server.js niet gevonden in: $PSScriptRoot"
        }
        
        # Start the server in a new window
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "node `"$serverPath`""
        
        Write-Host "Node.js server gestart op http://localhost:3000" -ForegroundColor Green
        Write-LogMessage "Node.js server succesvol gestart"
        return $true
    }
    catch {
        Write-Host "Fout bij starten Node.js server: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij starten Node.js server: $($_.Exception.Message)"
        return $false
    }
}

# Main script execution
try {
    Write-Host "=== Windows PC Setup Script ===" -ForegroundColor Cyan
    Write-LogMessage "Script gestart"

    # Stap 1: Execution Policy
    Write-Host "`nStap 1: Execution Policy instellen..." -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    Write-LogMessage "Execution Policy ingesteld op Bypass"

    # Stap 2: WiFi verbinding
    Write-Host "`nStap 2: WiFi verbinding maken..." -ForegroundColor Yellow
    if (-not (Connect-ToWiFi)) {
        Write-Host "WiFi verbinding mislukt, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "WiFi verbinding mislukt, script gaat door"
    }

    # Stap 3: Windows Updates
    Write-Host "`nStap 3: Windows Updates controleren en installeren..." -ForegroundColor Yellow
    if (-not (Install-WindowsUpdates)) {
        Write-Host "Windows Updates gefaald, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "Windows Updates gefaald, script gaat door"
    }

    # Stap 4: Node.js installatie
    Write-Host "`nStap 4: Node.js installatie controleren..." -ForegroundColor Yellow
    if (-not (Test-NodeJS)) {
        Write-Host "Node.js niet gevonden. Installatie starten..." -ForegroundColor Yellow
        if (-not (Install-NodeJS)) {
            throw "Node.js installatie mislukt"
        }
        
        # Controleer opnieuw na installatie
        if (-not (Test-NodeJS)) {
            throw "Node.js installatie verificatie mislukt"
        }
    }

    # Stap 5: NPM packages installeren
    Write-Host "`nStap 5: NPM packages installeren..." -ForegroundColor Yellow
    if (-not (Install-NpmPackages)) {
        throw "NPM packages installatie mislukt"
    }

    # Stap 6: Server starten
    Write-Host "`nStap 6: Node.js server starten..." -ForegroundColor Yellow
    if (-not (Start-NodeServer)) {
        throw "Server starten mislukt"
    }

    Write-Host "`nSetup succesvol afgerond!" -ForegroundColor Green
    Write-LogMessage "Script succesvol afgerond"
}
catch {
    Write-Host "`nFout opgetreden: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Controleer het logbestand voor meer details: $logFile" -ForegroundColor Yellow
    Write-LogMessage "Script gefaald: $($_.Exception.Message)"
    exit 1
}
