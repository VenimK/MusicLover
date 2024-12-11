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

# Function to install software using winget
function Install-WingetSoftware {
    try {
        Write-Host "`nWinget software installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start winget software installatie"
        
        Show-Progress -Activity "Winget" -Status "Voorbereiden..." -PercentComplete 10
        
        # Install software using winget
        $softwareList = @(
            "Google.Chrome",
            "7zip.7zip",
            "VideoLAN.VLC",
            "BelgianGovernment.Belgium-eIDmiddleware",
            "BelgianGovernment.eIDViewer"
        )
        
        $totalSteps = $softwareList.Count
        $currentStep = 0
        $progress = 0
        $increment = 90 / $totalSteps
        
        foreach ($software in $softwareList) {
            $currentStep++
            $progress += $increment
            
            # Calculate progress percentage for ASCII bar
            $percentComplete = [math]::Round(($currentStep / $totalSteps) * 100)
            $progressBar = "[" + ("█" * [math]::Floor($percentComplete/2)) + (" " * (50 - [math]::Floor($percentComplete/2))) + "]"
            
            Write-Host "`r$progressBar $percentComplete% " -NoNewline -ForegroundColor Green
            Show-Progress -Activity "Winget" -Status "Controleren $software..." -PercentComplete (10 + $progress)
            
            # Check if already installed
            $installed = winget list --id $software --exact | Select-String "^$software"
            
            if ($installed) {
                Write-Host "`n$software is al geinstalleerd. Overslaan..." -ForegroundColor Green
                Write-LogMessage "$software is al geinstalleerd"
                continue
            }
            
            Write-Host "`n$software installeren..." -ForegroundColor Cyan
            Write-LogMessage "$software installeren"
            
            # Install if not present
            winget install --id $software --silent --accept-source-agreements --accept-package-agreements --source winget
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Waarschuwing: $software installatie mislukt" -ForegroundColor Yellow
                Write-LogMessage "Waarschuwing: $software installatie mislukt"
                continue
            }
            Write-Host "$software succesvol geinstalleerd" -ForegroundColor Green
            Write-LogMessage "$software succesvol geinstalleerd"
        }
        
        # Complete the progress bar
        $progressBar = "[" + ("█" * 50) + "]"
        Write-Host "`r$progressBar 100% " -ForegroundColor Green
        
        Show-Progress -Activity "Winget" -Status "Voltooid" -PercentComplete 100
        Write-Host "`nWinget software installatie voltooid" -ForegroundColor Green
        Write-LogMessage "Winget software installatie voltooid"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "`nWinget software installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Winget software installatie mislukt: $errorMsg"
        Show-Progress -Activity "Winget" -Status "Mislukt" -PercentComplete 100
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

# Function to install Adobe Reader
function Install-AdobeReader {
    try {
        Write-Host "`nAdobe Reader installatie controleren..." -ForegroundColor Yellow
        Write-LogMessage "Start Adobe Reader installatie check"

        # Check multiple registry locations for Adobe Reader
        $paths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $adobeInstalled = $false
        foreach ($path in $paths) {
            if (Test-Path $path) {
                $installed = Get-ItemProperty $path | 
                    Where-Object { 
                        $_.DisplayName -like "*Adobe Acrobat*" -or 
                        $_.DisplayName -like "*Adobe Reader*" -or
                        $_.DisplayName -like "*Acrobat Reader*"
                    }
                if ($installed) {
                    $adobeInstalled = $true
                    $version = $installed.DisplayName
                    break
                }
            }
        }

        # Also check common installation paths
        $commonPaths = @(
            "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            "$env:ProgramFiles\Adobe\Reader 11.0\Reader\AcroRd32.exe",
            "${env:ProgramFiles(x86)}\Adobe\Reader 11.0\Reader\AcroRd32.exe"
        )

        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                $adobeInstalled = $true
                break
            }
        }

        if ($adobeInstalled) {
            Write-Host "Adobe Reader is al geinstalleerd. Installatie wordt overgeslagen." -ForegroundColor Green
            Write-LogMessage "Adobe Reader is al geinstalleerd"
            Show-Progress -Activity "Adobe Reader" -Status "Reeds geinstalleerd" -PercentComplete 100
            return $true
        }

        Show-Progress -Activity "Adobe Reader" -Status "Voorbereiden..." -PercentComplete 10
        
        # Create temp directory
        $userTemp = [System.IO.Path]::GetTempPath()
        $tempDir = Join-Path $userTemp "AdobeReaderInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }

        Show-Progress -Activity "Adobe Reader" -Status "Downloaden..." -PercentComplete 20
        
        # Download Adobe Reader
        $adobeUrl = "https://admdownload.adobe.com/rdcm/installers/live/readerdc64.exe"
        $installerPath = Join-Path $tempDir "AdobeReaderDC.exe"
        
        Show-Progress -Activity "Adobe Reader" -Status "Bestand ophalen..." -PercentComplete 40
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($adobeUrl, $installerPath)
        }
        catch {
            throw "Adobe Reader download mislukt: $($_.Exception.Message)"
        }

        Show-Progress -Activity "Adobe Reader" -Status "Installeren..." -PercentComplete 50
        Write-Host "`nAdobe Reader installeren..." -ForegroundColor Cyan
        Write-LogMessage "Adobe Reader installeren"
        $arguments = "/sAll /rs /msi /norestart /quiet EULA_ACCEPT=YES"
        
        # Start installation process with admin rights
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $installerPath
        $pinfo.Arguments = $arguments
        $pinfo.UseShellExecute = $true
        $pinfo.Verb = "runas"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            throw "Adobe Reader installatie mislukt met exit code: $($process.ExitCode)"
        }

        Show-Progress -Activity "Adobe Reader" -Status "PDF associatie instellen..." -PercentComplete 80
        
        # Set Adobe Reader as default PDF application
        try {
            $assocPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\UserChoice"
            if (Test-Path $assocPath) {
                Remove-Item -Path $assocPath -Force -Recurse
            }
            Start-Process "cmd.exe" -ArgumentList "/c ftype AcroExch.Document.DC=`"$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe`" `"%1`"" -Verb runas -Wait
            Start-Process "cmd.exe" -ArgumentList "/c assoc .pdf=AcroExch.Document.DC" -Verb runas -Wait
        }
        catch {
            Write-LogMessage "Waarschuwing: Kon PDF associatie niet instellen: $($_.Exception.Message)"
            # Continue even if association fails
        }

        # Cleanup
        Show-Progress -Activity "Adobe Reader" -Status "Opruimen..." -PercentComplete 90
        Start-Sleep -Seconds 2  # Wait a bit before cleanup
        try {
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -Force -ErrorAction Stop
            }
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Force -Recurse -ErrorAction Stop
            }
        }
        catch {
            Write-LogMessage "Cleanup waarschuwing: $($_.Exception.Message)"
            # Continue even if cleanup fails
        }

        Show-Progress -Activity "Adobe Reader" -Status "Voltooid" -PercentComplete 100
        Write-Host "`nAdobe Reader installatie voltooid" -ForegroundColor Green
        Write-LogMessage "Adobe Reader installatie voltooid"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "`nAdobe Reader installatie mislukt: $errorMsg" -ForegroundColor Red
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

# Function to install Adobe Reader
function Install-AdobeReader {
    try {
        Write-Host "`nAdobe Reader installatie controleren..." -ForegroundColor Yellow
        Write-LogMessage "Start Adobe Reader installatie check"

        # Check multiple registry locations for Adobe Reader
        $paths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $adobeInstalled = $false
        foreach ($path in $paths) {
            if (Test-Path $path) {
                $installed = Get-ItemProperty $path | 
                    Where-Object { 
                        $_.DisplayName -like "*Adobe Acrobat*" -or 
                        $_.DisplayName -like "*Adobe Reader*" -or
                        $_.DisplayName -like "*Acrobat Reader*"
                    }
                if ($installed) {
                    $adobeInstalled = $true
                    $version = $installed.DisplayName
                    break
                }
            }
        }

        # Also check common installation paths
        $commonPaths = @(
            "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            "$env:ProgramFiles\Adobe\Reader 11.0\Reader\AcroRd32.exe",
            "${env:ProgramFiles(x86)}\Adobe\Reader 11.0\Reader\AcroRd32.exe"
        )

        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                $adobeInstalled = $true
                break
            }
        }

        if ($adobeInstalled) {
            Write-Host "Adobe Reader is al geinstalleerd. Installatie wordt overgeslagen." -ForegroundColor Green
            Write-LogMessage "Adobe Reader is al geinstalleerd"
            Show-Progress -Activity "Adobe Reader" -Status "Reeds geinstalleerd" -PercentComplete 100
            return $true
        }

        Show-Progress -Activity "Adobe Reader" -Status "Voorbereiden..." -PercentComplete 10
        
        # Create temp directory
        $userTemp = [System.IO.Path]::GetTempPath()
        $tempDir = Join-Path $userTemp "AdobeReaderInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }

        Show-Progress -Activity "Adobe Reader" -Status "Downloaden..." -PercentComplete 20
        
        # Download Adobe Reader
        $adobeUrl = "https://admdownload.adobe.com/rdcm/installers/live/readerdc64.exe"
        $installerPath = Join-Path $tempDir "AdobeReaderDC.exe"
        
        Show-Progress -Activity "Adobe Reader" -Status "Bestand ophalen..." -PercentComplete 40
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($adobeUrl, $installerPath)
        }
        catch {
            throw "Adobe Reader download mislukt: $($_.Exception.Message)"
        }

        Show-Progress -Activity "Adobe Reader" -Status "Installeren..." -PercentComplete 50
        Write-Host "`nAdobe Reader installeren..." -ForegroundColor Cyan
        Write-LogMessage "Adobe Reader installeren"
        $arguments = "/sAll /rs /msi /norestart /quiet EULA_ACCEPT=YES"
        
        # Start installation process with admin rights
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $installerPath
        $pinfo.Arguments = $arguments
        $pinfo.UseShellExecute = $true
        $pinfo.Verb = "runas"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            throw "Adobe Reader installatie mislukt met exit code: $($process.ExitCode)"
        }

        Show-Progress -Activity "Adobe Reader" -Status "PDF associatie instellen..." -PercentComplete 80
        
        # Set Adobe Reader as default PDF application
        try {
            $assocPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\UserChoice"
            if (Test-Path $assocPath) {
                Remove-Item -Path $assocPath -Force -Recurse
            }
            Start-Process "cmd.exe" -ArgumentList "/c ftype AcroExch.Document.DC=`"$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe`" `"%1`"" -Verb runas -Wait
            Start-Process "cmd.exe" -ArgumentList "/c assoc .pdf=AcroExch.Document.DC" -Verb runas -Wait
        }
        catch {
            Write-LogMessage "Waarschuwing: Kon PDF associatie niet instellen: $($_.Exception.Message)"
            # Continue even if association fails
        }

        # Cleanup
        Show-Progress -Activity "Adobe Reader" -Status "Opruimen..." -PercentComplete 90
        Start-Sleep -Seconds 2  # Wait a bit before cleanup
        try {
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -Force -ErrorAction Stop
            }
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Force -Recurse -ErrorAction Stop
            }
        }
        catch {
            Write-LogMessage "Cleanup waarschuwing: $($_.Exception.Message)"
            # Continue even if cleanup fails
        }

        Show-Progress -Activity "Adobe Reader" -Status "Voltooid" -PercentComplete 100
        Write-Host "`nAdobe Reader installatie voltooid" -ForegroundColor Green
        Write-LogMessage "Adobe Reader installatie voltooid"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "`nAdobe Reader installatie mislukt: $errorMsg" -ForegroundColor Red
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

        Show-Progress -Activity "Index Bestand" -Status "Voorbereiden..." -PercentComplete 10
        
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
            $webClient.DownloadFile($indexUrl, $indexPath)
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

    # Stap 5: Winget software installatie
    Write-Host "`nStap 5: Winget software installeren..." -ForegroundColor Yellow
    Install-WingetSoftware

    # Stap 6: Adobe Reader installatie
    Write-Host "`nStap 6: Adobe Reader installeren..." -ForegroundColor Yellow
    Install-AdobeReader

    # Stap 7: Windows updates installeren
    Write-Host "`nStap 7: Windows updates installeren..." -ForegroundColor Yellow
    if (-not (Install-WindowsUpdates)) {
        Write-Host "Windows updates gefaald, maar script gaat door..." -ForegroundColor Yellow
        Write-LogMessage "Windows updates gefaald, script gaat door"
    }

    # Stap 8: Node.js installatie
    Write-Host "`nStap 8: Node.js installatie controleren..." -ForegroundColor Yellow
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

    # Stap 9: NPM packages installeren
    Write-Host "`nStap 9: NPM packages installeren..." -ForegroundColor Yellow
    if (-not (Install-NpmPackages)) {
        throw "NPM packages installatie mislukt"
    }

    # Stap 10: Server starten
    Write-Host "`nStap 10: Node.js server starten..." -ForegroundColor Yellow
    if (-not (Start-NodeServer)) {
        throw "Server starten mislukt"
    }

    # Stap 11: Index openen
    Write-Host "`nStap 11: Index openen..." -ForegroundColor Yellow
    Open-IndexFile

    Write-Host "`nSetup succesvol afgerond!" -ForegroundColor Green
    Write-LogMessage "Script succesvol afgerond"
}
catch {
    Write-Host "`nFout opgetreden: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Controleer het logbestand voor meer details: $logFile" -ForegroundColor Yellow
    Write-LogMessage "Script gefaald: $($_.Exception.Message)"
    exit 1
}
