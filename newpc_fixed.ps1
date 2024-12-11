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

# Check if running in proper console host
$hasConsoleHost = $Host.Name -eq "ConsoleHost"
if (-not $hasConsoleHost) {
    Write-Warning "Script wordt niet uitgevoerd in een console window. Voortgangsbalk zal niet zichtbaar zijn."
}

# Function to show a visual progress bar
function Show-Progress {
    param (
        [string]$Activity,
        [int]$PercentComplete,
        [string]$Status
    )
    
    $width = 50 # Width of the progress bar
    $complete = [math]::Floor($width * ($PercentComplete / 100))
    $remaining = $width - $complete
    
    # Clear the current line
    Write-Host "`r" -NoNewline
    
    # Write the activity name
    Write-Host "$Activity : " -NoNewline
    
    # Write the opening bracket
    Write-Host "[" -NoNewline
    
    # Write the completed portion in green
    if ($complete -gt 0) {
        Write-Host ("=" * $complete) -NoNewline -ForegroundColor Green
    }
    
    # Write the arrow in green if not complete
    if ($remaining -gt 0) {
        Write-Host ">" -NoNewline -ForegroundColor Green
        # Fill the remaining space
        if ($remaining -gt 1) {
            Write-Host (" " * ($remaining - 1)) -NoNewline
        }
    }
    
    # Write the closing bracket and percentage
    Write-Host "] " -NoNewline
    Write-Host "$PercentComplete% - " -NoNewline
    
    # Write the status
    Write-Host $Status -NoNewline
    
    if ($PercentComplete -eq 100) {
        Write-Host "" # New line after completion
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

# Function to click buttons in windows
function Click-Button {
    param (
        [string]$WindowTitle,
        [string]$ButtonText
    )
    
    try {
        Add-Type -AssemblyName UIAutomation
        $automation = [System.Windows.Automation.AutomationElement]
        $window = $automation::RootElement.FindFirst(
            [System.Windows.Automation.TreeScope]::Children,
            (New-Object System.Windows.Automation.PropertyCondition($automation::NameProperty, $WindowTitle))
        )
        
        if ($window) {
            $button = $window.FindFirst(
                [System.Windows.Automation.TreeScope]::Descendants,
                (New-Object System.Windows.Automation.PropertyCondition($automation::NameProperty, $ButtonText))
            )
            
            if ($button) {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $invokePattern.Invoke()
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to install software using Ninite
function Install-NiniteSoftware {
    try {
        Write-Host "Ninite installer downloaden..." -ForegroundColor Yellow
        Write-LogMessage "Ninite installer downloaden"
        
        # Create temp directory if it doesn't exist
        $tempDir = Join-Path $env:TEMP "NiniteInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Define direct download link to your pre-configured Ninite installer
        $niniteUrl = "https://raw.githubusercontent.com/VenimK/MusicLover/main/MLPACK.exe"
        $ninitePath = Join-Path $tempDir "MLPACK.exe"
        
        # Download Ninite installer with progress
        Write-Host "Bestand downloaden van cloud storage..." -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($niniteUrl, $ninitePath)
        }
        catch {
            throw "Download mislukt: $($_.Exception.Message)"
        }
        
        # Verify file exists and has content
        if (-not (Test-Path $ninitePath)) {
            throw "Ninite installer niet gevonden na download"
        }
        
        $fileInfo = Get-Item $ninitePath
        if ($fileInfo.Length -eq 0) {
            throw "Gedownload bestand is leeg"
        }
        
        Write-Host "Software installeren via Ninite..." -ForegroundColor Yellow
        Write-LogMessage "Software installatie gestart via Ninite"
        
        # Create and configure a new process
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $ninitePath
        $pinfo.Arguments = ""  # Run without silent mode to show UI
        $pinfo.UseShellExecute = $true
        $pinfo.Verb = "runas"  # Run as administrator
        $pinfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        
        Write-Host "Ninite installer starten met admin rechten..." -ForegroundColor Yellow
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo
        
        # Start the process
        $process.Start()
        Start-Sleep -Seconds 10
        
        Write-Host "Ninite installatie gestart" -ForegroundColor Green
        Write-LogMessage "Ninite installatie gestart"
        
        # Cleanup
        if ($process -ne $null) {
            $process.Dispose()
        }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-LogMessage "Ninite installatie mislukt: $errorMsg"
        Write-Host "Ninite installatie mislukt" -ForegroundColor Red
        Write-Host @"
Als Ninite niet werkt, hier zijn de directe download links:
1. Chrome: https://www.google.com/chrome/
2. VLC: https://www.videolan.org/vlc/
3. 7-Zip: https://7-zip.org/
"@ -ForegroundColor Yellow
        
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
    try {
        Write-Host "Node.js installeren via winget..." -ForegroundColor Yellow
        Write-LogMessage "Node.js installatie gestart via winget"
        
        Show-Progress -Activity "Node.js Installatie" -Status "Voorbereiden..." -PercentComplete 20
        
        # Uninstall existing Node.js if present (silent)
        winget uninstall OpenJS.NodeJS.LTS --silent 2>$null
        Start-Sleep -Seconds 2
        
        # Install Node.js LTS
        winget install --id OpenJS.NodeJS.LTS --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Winget installatie mislukt"
        }
        
        Show-Progress -Activity "Node.js Installatie" -Status "PATH bijwerken..." -PercentComplete 80
        
        # Add Node.js to PATH
        $nodePath = "C:\Program Files\nodejs"
        $env:Path = "$env:Path;$nodePath"
        
        Write-Host "Node.js succesvol geinstalleerd" -ForegroundColor Green
        Write-LogMessage "Node.js installatie succesvol"
        Show-Progress -Activity "Node.js Installatie" -Completed
        
        return $true
    }
    catch {
        Write-Host "Fout bij Node.js installatie: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij Node.js installatie: $($_.Exception.Message)"
        Show-Progress -Activity "Node.js Installatie" -Completed
        return $false
    }
}

# Function to install npm packages
function Install-NpmPackages {
    try {
        Write-Host "NPM packages installeren..." -ForegroundColor Yellow
        Write-LogMessage "NPM packages installatie gestart"
        
        Show-Progress -Activity "NPM Packages" -Status "Voorbereiden..." -PercentComplete 20
        
        # Navigate to server directory
        Set-Location -Path $PSScriptRoot
        
        # Check if package.json exists
        if (-not (Test-Path "package.json")) {
            throw "package.json niet gevonden in: $PSScriptRoot"
        }
        
        Show-Progress -Activity "NPM Packages" -Status "Dependencies installeren..." -PercentComplete 50
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "NPM install commando mislukt"
        }
        
        Write-Host "NPM packages succesvol geinstalleerd" -ForegroundColor Green
        Write-LogMessage "NPM packages succesvol geinstalleerd"
        Show-Progress -Activity "NPM Packages" -Completed
        return $true
    }
    catch {
        Write-Host "Fout bij NPM packages installatie: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij NPM packages installatie: $($_.Exception.Message)"
        Show-Progress -Activity "NPM Packages" -Completed
        return $false
    }
}

# Function to start Node.js server
function Start-NodeServer {
    try {
        Write-Host "Node.js server starten..." -ForegroundColor Yellow
        Write-LogMessage "Node.js server wordt gestart"
        
        Show-Progress -Activity "Server" -Status "Voorbereiden..." -PercentComplete 20
        
        # Start server.js in a new window
        $serverPath = Join-Path $PSScriptRoot "server.js"
        if (-not (Test-Path $serverPath)) {
            throw "server.js niet gevonden in: $PSScriptRoot"
        }
        
        # Start the server in a new window
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "node `"$serverPath`""
        
        Write-Host "Node.js server gestart op http://localhost:3000" -ForegroundColor Green
        Write-LogMessage "Node.js server succesvol gestart"
        Show-Progress -Activity "Server" -Completed
        return $true
    }
    catch {
        Write-Host "Fout bij starten Node.js server: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij starten Node.js server: $($_.Exception.Message)"
        Show-Progress -Activity "Server" -Completed
        return $false
    }
}

# Function to install Adobe Reader DC silently
function Install-AdobeReader {
    try {
        Write-Host "Adobe Reader installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Adobe Reader installatie"
        
        Show-Progress -Activity "Adobe Reader" -Status "Controleren..." -PercentComplete 10
        
        # Check if Adobe Reader is already installed
        $adobeInstalled = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
            Where-Object { $_.DisplayName -like "*Adobe Acrobat Reader*" }
            
        if ($adobeInstalled) {
            Show-Progress -Activity "Adobe Reader" -Status "Reeds geinstalleerd" -PercentComplete 100
            Write-Host "Adobe Reader is al geinstalleerd" -ForegroundColor Green
            Write-LogMessage "Adobe Reader is al geinstalleerd"
            return $true
        }
        
        Show-Progress -Activity "Adobe Reader" -Status "Downloaden..." -PercentComplete 30
        
        # Download Adobe Reader
        $url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300920137/AcroRdrDC2300920137_nl_NL.exe"
        $installerPath = Join-Path $env:TEMP "AdobeReaderDC.exe"
        
        Write-Host "Adobe Reader downloaden..." -ForegroundColor Cyan
        Write-LogMessage "Adobe Reader downloaden"
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $installerPath)
        
        Show-Progress -Activity "Adobe Reader" -Status "Installeren..." -PercentComplete 60
        
        # Install Adobe Reader silently
        Write-Host "Adobe Reader installeren..." -ForegroundColor Cyan
        Write-LogMessage "Adobe Reader installeren"
        Start-Process -FilePath $installerPath -ArgumentList "/sAll /rs /msi /norestart /quiet EULA_ACCEPT=YES" -Wait
        
        Show-Progress -Activity "Adobe Reader" -Status "Opruimen..." -PercentComplete 90
        
        # Cleanup
        if (Test-Path $installerPath) {
            Remove-Item $installerPath
        }
        
        Show-Progress -Activity "Adobe Reader" -Status "Voltooid" -PercentComplete 100
        Write-Host "Adobe Reader succesvol geinstalleerd" -ForegroundColor Green
        Write-LogMessage "Adobe Reader succesvol geinstalleerd"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Adobe Reader installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Adobe Reader installatie mislukt: $errorMsg"
        Show-Progress -Activity "Adobe Reader" -Status "Mislukt" -PercentComplete 100
        return $false
    }
}

# Function to optimize power settings
function Set-OptimalPowerSettings {
    try {
        Write-Host "Energie-instellingen optimaliseren..." -ForegroundColor Yellow
        Write-LogMessage "Energie-instellingen aanpassen gestart"

        # Set power plan to High Performance
        $powerPlan = Get-WmiObject -Namespace root\cimv2\power -Class Win32_PowerPlan | Where-Object { $_.ElementName -eq "High Performance" }
        if ($powerPlan) {
            $powerPlan.Activate()
            Write-Host "High Performance energieplan geactiveerd" -ForegroundColor Green
        }

        # Configure power settings using powercfg
        # Never turn off display when plugged in
        powercfg /change monitor-timeout-ac 0
        powercfg /change monitor-timeout-dc 0
        # Never put computer to sleep when plugged in
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 0
        # Never turn off hard disk
        powercfg /change disk-timeout-ac 0
        powercfg /change disk-timeout-dc 0
        # Disable hibernate
        powercfg /hibernate off
        # Disable USB selective suspend
        powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        # Apply changes
        powercfg /setactive scheme_current

        Write-Host "Energie-instellingen succesvol aangepast" -ForegroundColor Green
        Write-LogMessage "Energie-instellingen succesvol aangepast"
    }
    catch {
        Write-LogMessage "Energie-instellingen aanpassen mislukt: $($_.Exception.Message)"
        Write-Host "Energie-instellingen aanpassen mislukt" -ForegroundColor Red
    }
}

# Function to install Winget
function Install-Winget {
    try {
        Write-Host "`nWinget installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Winget installatie"

        # Start progress
        Show-Progress -Activity "Winget Installatie" -Status "Voorbereiden..." -PercentComplete 0

        # Controleer of winget al is geinstalleerd
        $hasWinget = Get-AppxPackage -Name Microsoft.DesktopAppInstaller

        if ($hasWinget) {
            Show-Progress -Activity "Winget Installatie" -Status "Verwijderen oude versie..." -PercentComplete 20
            Write-Host "`nBestaande Winget installatie verwijderen..." -ForegroundColor Yellow
            Write-LogMessage "Verwijderen bestaande Winget installatie"
            Get-AppxPackage *Microsoft.DesktopAppInstaller* | Remove-AppxPackage
            Start-Sleep -Seconds 2
        }

        # Download en installeer de nieuwste versie van winget
        Show-Progress -Activity "Winget Installatie" -Status "Downloaden..." -PercentComplete 40
        Write-Host "`nNieuwste Winget installer downloaden..." -ForegroundColor Cyan
        Write-LogMessage "Downloaden Winget installer"
        $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $installerPath = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"

        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($wingetUrl, $installerPath)

        Show-Progress -Activity "Winget Installatie" -Status "Installeren..." -PercentComplete 60
        Write-Host "`nWinget installeren..." -ForegroundColor Cyan
        Write-LogMessage "Installeren Winget"
        Add-AppxPackage $installerPath

        # Ruim het installatiebestand op
        Show-Progress -Activity "Winget Installatie" -Status "Opruimen..." -PercentComplete 80
        if (Test-Path $installerPath) {
            Remove-Item $installerPath
        }

        # Ververs omgevingsvariabelen
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verifieer installatie
        Show-Progress -Activity "Winget Installatie" -Status "Verificatie..." -PercentComplete 90
        Write-Host "`nWinget installatie verifieren..." -ForegroundColor Cyan
        Write-LogMessage "Verifieren Winget installatie"
        $wingetVersion = winget --version
        
        # Accept Microsoft Store agreements
        Show-Progress -Activity "Winget Installatie" -Status "Configureren..." -PercentComplete 95
        Write-Host "`nMicrosoft Store voorwaarden accepteren..." -ForegroundColor Yellow
        winget settings --enable LocalManifestFiles
        winget settings --enable MSStore
        winget source reset --force msstore
        
        Show-Progress -Activity "Winget Installatie" -Status "Voltooid" -PercentComplete 100
        Write-Host "`nWinget succesvol geinstalleerd! Versie: $wingetVersion" -ForegroundColor Green
        Write-LogMessage "Winget succesvol geinstalleerd: $wingetVersion"
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "`nWinget installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Winget installatie mislukt: $errorMsg"
        Show-Progress -Activity "Winget Installatie" -Status "Mislukt" -PercentComplete 100
        return $false
    }
}

# Function to install Belgian eID software
function Install-BelgianEid {
    try {
        Write-Host "Belgische eID software installeren..." -ForegroundColor Yellow
        Write-LogMessage "Start installatie Belgische eID software"

        # Install eID middleware
        Write-Host "eID middleware installeren..." -ForegroundColor Cyan
        winget install -e --id BelgianGovernment.Belgium-eIDmiddleware --silent --accept-source-agreements --accept-package-agreements --source winget

        if ($LASTEXITCODE -eq 0) {
            Write-Host "eID middleware succesvol geinstalleerd!" -ForegroundColor Green
            Write-LogMessage "eID middleware succesvol geinstalleerd"
        } else {
            throw "Installatie van eID middleware is mislukt"
        }

        # Install eID viewer
        Write-Host "eID viewer installeren..." -ForegroundColor Cyan
        winget install -e --id BelgianGovernment.eIDViewer --silent --accept-source-agreements --accept-package-agreements --source winget

        if ($LASTEXITCODE -eq 0) {
            Write-Host "eID viewer succesvol geinstalleerd!" -ForegroundColor Green
            Write-LogMessage "eID viewer succesvol geinstalleerd"
        } else {
            throw "Installatie van eID viewer is mislukt"
        }

    } catch {
        $errorMsg = $_.Exception.Message
        Write-LogMessage "Belgische eID software installatie mislukt: $errorMsg"
        Write-Host "Belgische eID software installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-Host @"
Als de automatische installatie niet werkt, hier zijn de directe download links:
1. eID middleware: https://eid.belgium.be/nl/download/middleware-windows
2. eID viewer: https://eid.belgium.be/nl/download/eid-viewer-windows
"@ -ForegroundColor Yellow
    }
}

Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Window {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
    }
"@

# Function to focus PowerShell window
function Set-PowerShellWindowFocus {
    $PSWindow = [Window]::GetConsoleWindow()
    [Window]::ShowWindow($PSWindow, 5)
    [Window]::SetForegroundWindow($PSWindow)
}

# Function to download and open index file
function Open-IndexFile {
    try {
        Write-Host "`nIndex bestand downloaden en openen..." -ForegroundColor Yellow
        Write-LogMessage "Start download en openen index bestand"

        Show-Progress -Activity "Index Bestand" -Status "Downloaden..." -PercentComplete 20
        
        # Create temp directory if it doesn't exist
        $tempDir = Join-Path $env:TEMP "IndexFile"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Download index file
        $indexUrl = "https://raw.githubusercontent.com/VenimK/MusicLover/main/index_updated.html"
        $indexPath = Join-Path $tempDir "index_updated.html"
        
        Show-Progress -Activity "Index Bestand" -Status "Bestand ophalen..." -PercentComplete 40
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($indexUrl, $indexPath)
        }
        catch {
            throw "Index bestand download mislukt: $($_.Exception.Message)"
        }
        
        Show-Progress -Activity "Index Bestand" -Status "Bestand controleren..." -PercentComplete 60
        # Verify file exists and has content
        if (-not (Test-Path $indexPath)) {
            throw "Index bestand niet gevonden na download"
        }
        
        $fileInfo = Get-Item $indexPath
        if ($fileInfo.Length -eq 0) {
            throw "Gedownload bestand is leeg"
        }

        Show-Progress -Activity "Index Bestand" -Status "Chrome openen..." -PercentComplete 80
        # Open in Chrome
        $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
        $chromePath86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        
        if (Test-Path $chromePath) {
            Start-Process $chromePath -ArgumentList $indexPath
        }
        elseif (Test-Path $chromePath86) {
            Start-Process $chromePath86 -ArgumentList $indexPath
        }
        else {
            throw "Google Chrome niet gevonden"
        }

        # Give Chrome a moment to open
        Start-Sleep -Seconds 1
        
        # Bring PowerShell window back to focus
        Set-PowerShellWindowFocus

        Show-Progress -Activity "Index Bestand" -Status "Voltooid" -PercentComplete 100
        Write-Host "`nIndex bestand succesvol geopend in Chrome" -ForegroundColor Green
        Write-LogMessage "Index bestand succesvol geopend"
        
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

# Main script execution
try {
    Write-Host "=== Windows PC Setup Script ===" -ForegroundColor Cyan
    Write-LogMessage "Script gestart"

    # Stap 1: Execution Policy
    Write-Host "`nStap 1: Execution Policy instellen..." -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    Write-LogMessage "Execution Policy ingesteld op Bypass"

    # Stap 2: Energie-instellingen optimaliseren
    Write-Host "`nStap 2: Energie-instellingen optimaliseren..." -ForegroundColor Yellow
    Set-OptimalPowerSettings

    # Stap 3: WiFi verbinding
    Write-Host "`nStap 3: WiFi verbinding maken..." -ForegroundColor Yellow
    if (-not (Connect-ToWiFi)) {
        Write-Host "WiFi verbinding mislukt, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "WiFi verbinding mislukt, script gaat door"
    }

    # Stap 4: Winget installatie
    Write-Host "`nStap 4: Winget installeren..." -ForegroundColor Yellow
    if (-not (Install-Winget)) {
        Write-Host "Winget installatie mislukt, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "Winget installatie mislukt, script gaat door"
    }

    # Stap 5: Belgische eID software installatie
    Write-Host "`nStap 5: Belgische eID software installeren..." -ForegroundColor Yellow
    Install-BelgianEid

    # Stap 6: Software installatie via Ninite
    Write-Host "`nStap 6: Software installeren via Ninite..." -ForegroundColor Yellow
    if (-not (Install-NiniteSoftware)) {
        Write-Host "Software installatie mislukt, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "Software installatie mislukt, script gaat door"
    }

    # Stap 7: Index bestand openen
    Write-Host "`nStap 7: Index bestand downloaden en openen..." -ForegroundColor Yellow
    if (-not (Open-IndexFile)) {
        Write-Host "Index bestand openen mislukt, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "Index bestand openen mislukt, script gaat door"
    }

    # Stap 8: Adobe Reader installatie
    Write-Host "`nStap 8: Adobe Reader installeren..." -ForegroundColor Yellow
    Install-AdobeReader
    
    # Stap 9: Windows Updates
    Write-Host "`nStap 9: Windows Updates controleren en installeren..." -ForegroundColor Yellow
    if (-not (Install-WindowsUpdates)) {
        Write-Host "Windows Updates gefaald, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "Windows Updates gefaald, script gaat door"
    }

    # Stap 10: Node.js installatie
    Write-Host "`nStap 10: Node.js installatie controleren..." -ForegroundColor Yellow
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

    # Stap 11: NPM packages installeren
    Write-Host "`nStap 11: NPM packages installeren..." -ForegroundColor Yellow
    if (-not (Install-NpmPackages)) {
        throw "NPM packages installatie mislukt"
    }

    # Stap 12: Server starten
    Write-Host "`nStap 12: Node.js server starten..." -ForegroundColor Yellow
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
