# Script configuratie
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$logFile = Join-Path $env:TEMP "newpc_setup.log"

# Function to log messages
function Write-LogMessage {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
}

# Set execution policy to Bypass
Write-Host "Execution policy instellen..." -ForegroundColor Yellow
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
Write-LogMessage "Execution policy ingesteld op Bypass"

# WiFi Verbinding
function Connect-ToWiFi {
    $SSID = "Music lover"
    $Password = "1234poiu"

    Write-Host "Automatisch verbinden met $SSID..." -ForegroundColor Yellow
    Write-LogMessage "Poging tot verbinden met WiFi netwerk: $SSID"

    # Controleer of het netwerk bestaat
    $network = netsh wlan show networks | Select-String -Pattern $SSID

    if ($network) {
        Write-Host "Netwerk $SSID gevonden. Bezig met verbinden..." -ForegroundColor Yellow
        
        try {
            # Maak een tijdelijk profiel XML
            $profileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <hex>$SSID</hex>
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
            $profileXml | Set-Content "$env:TEMP\WiFiProfile.xml"
            netsh wlan add profile filename="$env:TEMP\WiFiProfile.xml"
            Remove-Item "$env:TEMP\WiFiProfile.xml"

            # Probeer verbinding te maken met het netwerk
            netsh wlan connect name=$SSID
            
            # Wacht even om de verbindingsstatus te controleren
            Start-Sleep -Seconds 5
            
            # Controleer of we verbonden zijn
            $connectionStatus = netsh wlan show interfaces | Select-String -Pattern $SSID
            
            if ($connectionStatus) {
                Write-Host "Succesvol verbonden met $SSID" -ForegroundColor Green
                Write-LogMessage "Succesvol verbonden met WiFi netwerk: $SSID"
            } else {
                Write-Host "Kan niet verbinden met $SSID. Controleer of het wachtwoord correct is." -ForegroundColor Red
                Write-LogMessage "Kan niet verbinden met WiFi netwerk: $SSID"
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Host "Er is een fout opgetreden tijdens het verbinden: $errorMsg" -ForegroundColor Red
            Write-LogMessage "Fout bij WiFi verbinding: $errorMsg"
        }
    } else {
        Write-Host "Netwerk $SSID niet gevonden. Controleer of het netwerk binnen bereik is." -ForegroundColor Red
        Write-LogMessage "WiFi netwerk $SSID niet gevonden"
    }
}

# Function to check for administrative privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to handle errors
function Handle-Error {
    param($ErrorMessage)
    Write-LogMessage "FOUT: $ErrorMessage"
    Write-Host "Er is een fout opgetreden!" -ForegroundColor Red
    Write-Host "Controleer het logbestand op $logFile voor details" -ForegroundColor Red
}

# Function to remove unwanted Windows apps
function Remove-WindowsApps {
    try {
        Write-Host "Controleren op voorgeinstalleerde Windows apps..." -ForegroundColor Yellow
        Write-LogMessage "Start controle Windows apps"
        
        $appsToRemove = @(
            "Microsoft.BingWeather"
            "Microsoft.GetHelp"
            "Microsoft.Getstarted"
            "Microsoft.Microsoft3DViewer"
            "Microsoft.MicrosoftOfficeHub"
            "Microsoft.MicrosoftSolitaireCollection"
            "Microsoft.MixedReality.Portal"
            "Microsoft.Office.OneNote"
            "Microsoft.People"
            "Microsoft.SkypeApp"
            "Microsoft.WindowsAlarms"
            "Microsoft.WindowsFeedbackHub"
            "Microsoft.WindowsMaps"
            "Microsoft.Xbox.TCUI"
            "Microsoft.XboxApp"
            "Microsoft.XboxGameOverlay"
            "Microsoft.XboxGamingOverlay"
            "Microsoft.XboxIdentityProvider"
            "Microsoft.XboxSpeechToTextOverlay"
            "Microsoft.YourPhone"
            "Microsoft.ZuneMusic"
            "Microsoft.ZuneVideo"
        )

        # Check for existing apps
        $existingApps = @()
        $i = 0
        Write-Progress -Activity "Apps controleren" -Status "Zoeken naar voorgeïnstalleerde apps..." -PercentComplete 0
        foreach ($app in $appsToRemove) {
            $i++
            $percentComplete = ($i / $appsToRemove.Count) * 100
            Write-Progress -Activity "Apps controleren" -Status "Controleren: $app" -PercentComplete $percentComplete
            
            $package = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            $provisionedPackage = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | 
                                Where-Object DisplayName -eq $app
            
            if ($package -ne $null -or $provisionedPackage -ne $null) {
                $existingApps += $app
                Write-LogMessage "Gevonden app: $app"
            }
        }
        Write-Progress -Activity "Apps controleren" -Completed

        if ($existingApps.Count -eq 0) {
            Write-Host "Geen Windows apps gevonden om te verwijderen" -ForegroundColor Cyan
            Write-LogMessage "Geen Windows apps aanwezig om te verwijderen"
            return $true
        }
        
        # Remove found apps
        Write-Host "Verwijderen van $($existingApps.Count) gevonden Windows apps..." -ForegroundColor Yellow
        
        $appsRemoved = 0
        $i = 0
        foreach ($app in $existingApps) {
            $i++
            $percentComplete = ($i / $existingApps.Count) * 100
            Write-Progress -Activity "Apps verwijderen" -Status "Verwijderen: $app" -PercentComplete $percentComplete
            
            Write-Host "Verwijderen: $app" -ForegroundColor Yellow
            Write-LogMessage "Verwijderen app: $app"
            
            $package = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($package -ne $null) {
                $package | Remove-AppxPackage -ErrorAction SilentlyContinue
                $appsRemoved++
            }
            
            $provisionedPackage = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | 
                                Where-Object DisplayName -eq $app
            if ($provisionedPackage -ne $null) {
                $provisionedPackage | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            }
        }
        Write-Progress -Activity "Apps verwijderen" -Completed
        if ($appsRemoved -gt 0) {
            Write-Host "$appsRemoved Windows apps succesvol verwijderd" -ForegroundColor Green
            Write-LogMessage "$appsRemoved Windows apps succesvol verwijderd"
        } else {
            Write-Host "Geen apps verwijderd (mogelijk al verwijderd)" -ForegroundColor Cyan
            Write-LogMessage "Geen apps verwijderd"
        }
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Fout bij verwijderen Windows apps: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Fout bij verwijderen Windows apps: $errorMsg"
        return $false
    }
}

# Function to find and click a button by its text
function Click-Button {
    param (
        [string]$WindowTitle,
        [string]$ButtonText
    )
    
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class Win32 {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
        
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
        
        public const int BM_CLICK = 0x00F5;
    }
"@
    
    Start-Sleep -Seconds 1  # Give UI time to update
    
    $hwnd = [Win32]::FindWindow([NullString]::Value, $WindowTitle)
    if ($hwnd -ne [IntPtr]::Zero) {
        $button = [Win32]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", $ButtonText)
        if ($button -ne [IntPtr]::Zero) {
            [void][Win32]::SendMessage($button, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
            return $true
        }
    }
    return $false
}

# Function to install software using Ninite
function Install-NiniteSoftware {
    try {
        Write-Host "Ninite installer downloaden..." -ForegroundColor Yellow
        Write-LogMessage "Ninite installer downloaden"
        
        Write-Progress -Activity "Ninite Installatie" -Status "Installer downloaden..." -PercentComplete 20
        
        # Create temp directory if it doesn't exist
        $tempDir = Join-Path $env:TEMP "NiniteInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir | Out-Null
        }
        
        Write-Progress -Activity "Ninite Installatie" -Status "Installer uitvoeren..." -PercentComplete 40
        
        # Download Ninite installer
        $niniteUrl = "https://raw.githubusercontent.com/VenimK/MusicLover/main/MLPACK.exe"
        $installerPath = Join-Path $tempDir "MLPACK.exe"
        
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($niniteUrl, $installerPath)
            Write-LogMessage "Ninite installer gedownload naar: $installerPath"
            
            Write-Progress -Activity "Ninite Installatie" -Status "Software installeren..." -PercentComplete 60
            
            if (Test-Path $installerPath) {
                Start-Process -FilePath $installerPath -Wait
                Write-Progress -Activity "Ninite Installatie" -Status "Installatie voltooid" -PercentComplete 100
                Write-Host "Ninite installatie voltooid" -ForegroundColor Green
                Write-LogMessage "Ninite installatie succesvol"
                Start-Sleep -Seconds 2
            }
            else {
                throw "Installer niet gevonden na download"
            }
        }
        catch {
            throw "Download of uitvoering van Ninite installer mislukt: $_"
        }
        finally {
            Write-Progress -Activity "Ninite Installatie" -Completed
            # Cleanup
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Ninite installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Ninite installatie mislukt: $errorMsg"
        Write-Host @"
Als Ninite niet werkt, hier zijn de directe download links:
1. Chrome: https://www.google.com/chrome/
2. VLC: https://www.videolan.org/vlc/
3. 7-Zip: https://7-zip.org/
"@ -ForegroundColor Yellow
        
        # Alternative installation instructions
        Write-Host @"

Als Ninite niet werkt, hier zijn de directe download links:
1. Chrome: https://www.google.com/chrome/
2. VLC: https://www.videolan.org/vlc/
3. 7-Zip: https://7-zip.org/

Je kunt deze programma's handmatig downloaden en installeren.
"@ -ForegroundColor Yellow
    }
}

# Function to install Adobe Reader DC silently
function Install-AdobeReader {
    try {
        # Check common installation paths for Adobe Reader DC
        $adobePaths = @(
            "${env:ProgramFiles}\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            "${env:ProgramFiles}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        )

        foreach ($path in $adobePaths) {
            if (Test-Path $path) {
                Write-Host "Adobe Reader DC is al geinstalleerd" -ForegroundColor Green
                Write-LogMessage "Adobe Reader DC is al geinstalleerd - installatie overgeslagen"
                return
            }
        }

        Write-Host "Adobe Reader DC installeren..." -ForegroundColor Yellow
        Write-LogMessage "Adobe Reader DC installatie gestart"
        
        $tempDir = Join-Path $env:TEMP "AdobeInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Adobe Reader DC Enterprise MSI download URL
        $adobeUrl = "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2300320269/AcroRdrDCx642300320269_nl_NL.exe"
        $installerPath = Join-Path $tempDir "AdobeReaderDC.exe"
        
        # Download Adobe Reader
        Write-Host "Adobe Reader DC downloaden..." -ForegroundColor Yellow
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($adobeUrl, $installerPath)
        }
        catch {
            throw "Adobe Reader download mislukt: $($_.Exception.Message)"
        }
        
        # Verify download
        if (-not (Test-Path $installerPath)) {
            throw "Adobe Reader installer niet gevonden na download"
        }
        
        # Install Adobe Reader silently
        Write-Host "Adobe Reader DC installeren..." -ForegroundColor Yellow
        $arguments = "/sAll /rs /msi EULA_ACCEPT=YES"
        $process = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Adobe Reader DC succesvol geinstalleerd" -ForegroundColor Green
            Write-LogMessage "Adobe Reader DC installatie voltooid"
        }
        else {
            throw "Adobe Reader installatie mislukt met exit code: $($process.ExitCode)"
        }
        
        # Cleanup
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
    catch {
        Write-LogMessage "Adobe Reader installatie mislukt: $($_.Exception.Message)"
        Write-Host "Adobe Reader installatie mislukt. Download handmatig via: https://get.adobe.com/nl/reader/" -ForegroundColor Red
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
        Write-Host "Winget installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Winget installatie"

        # Controleer of winget al is geinstalleerd
        $hasWinget = Get-AppxPackage -Name Microsoft.DesktopAppInstaller

        if ($hasWinget) {
            Write-Host "Bestaande Winget installatie verwijderen..." -ForegroundColor Yellow
            Write-LogMessage "Verwijderen bestaande Winget installatie"
            Get-AppxPackage *Microsoft.DesktopAppInstaller* | Remove-AppxPackage
            Start-Sleep -Seconds 2
        }

        # Download en installeer de nieuwste versie van winget
        Write-Host "Nieuwste Winget installer downloaden..." -ForegroundColor Cyan
        Write-LogMessage "Downloaden Winget installer"
        $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $installerPath = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"

        Invoke-WebRequest -Uri $wingetUrl -OutFile $installerPath
        Write-Host "Winget installeren..." -ForegroundColor Cyan
        Write-LogMessage "Installeren Winget"
        Add-AppxPackage $installerPath

        # Ruim het installatiebestand op
        if (Test-Path $installerPath) {
            Remove-Item $installerPath
        }

        # Ververs omgevingsvariabelen
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verifieer installatie
        Write-Host "Winget installatie verifieren..." -ForegroundColor Cyan
        Write-LogMessage "Verifieren Winget installatie"
        $wingetVersion = winget --version
        Write-Host "Winget succesvol geinstalleerd! Versie: $wingetVersion" -ForegroundColor Green
        Write-LogMessage "Winget succesvol geinstalleerd: $wingetVersion"
        
        # Accept Microsoft Store agreements
        Write-Host "Microsoft Store voorwaarden accepteren..." -ForegroundColor Yellow
        winget settings --enable LocalManifestFiles
        winget settings --enable MSStore
        winget source reset --force msstore
        
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Winget installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Winget installatie mislukt: $errorMsg"
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

# Function to install Windows Updates
function Install-WindowsUpdates {
    try {
        Write-Host "Windows Updates installeren..." -ForegroundColor Yellow
        Write-LogMessage "Start Windows Updates installatie"

        # Install PSWindowsUpdate module if not present
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "PSWindowsUpdate module installeren..." -ForegroundColor Cyan
            Install-Module PSWindowsUpdate -Force -Confirm:$false
        }

        # Import the module
        Import-Module PSWindowsUpdate

        # Install required updates first
        Write-Host "Vereiste updates zoeken en installeren..." -ForegroundColor Cyan
        $requiredUpdates = Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
        
        # Install optional updates
        Write-Host "Optionele updates zoeken en installeren..." -ForegroundColor Cyan
        $optionalUpdates = Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -MicrosoftUpdate

        Write-Host "Windows Updates succesvol geinstalleerd!" -ForegroundColor Green
        Write-LogMessage "Windows Updates succesvol geinstalleerd"
        
        # Show update summary without using Get-WUHistory
        Write-Host "`nUpdate samenvatting:" -ForegroundColor Yellow
        if ($requiredUpdates) {
            Write-Host "Geinstalleerde vereiste updates:" -ForegroundColor Cyan
            $requiredUpdates | Format-Table -Property Title, KB, Size -AutoSize
        }
        if ($optionalUpdates) {
            Write-Host "Geinstalleerde optionele updates:" -ForegroundColor Cyan
            $optionalUpdates | Format-Table -Property Title, KB, Size -AutoSize
        }
        if (-not $requiredUpdates -and -not $optionalUpdates) {
            Write-Host "Geen updates gevonden om te installeren." -ForegroundColor Cyan
        }
        
        Write-Host "Start de computer opnieuw op om de updates te voltooien." -ForegroundColor Yellow
        Write-LogMessage "Updates geinstalleerd - herstart nodig"

    } catch {
        $errorMsg = $_.Exception.Message
        Write-LogMessage "Windows Updates installatie mislukt: $errorMsg"
        Write-Host "Windows Updates installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-Host @"
Als de automatische update niet werkt:
1. Open Windows Settings
2. Ga naar Update & Security
3. Klik op Check for Updates
4. Ga naar 'View optional updates' voor optionele updates
"@ -ForegroundColor Yellow
    }
}

# Function to find and click a button by its text
function Click-Button {
    param (
        [string]$WindowTitle,
        [string]$ButtonText
    )
    
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class Win32 {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
        
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
        
        public const int BM_CLICK = 0x00F5;
    }
"@
    
    Start-Sleep -Seconds 1  # Give UI time to update
    
    $hwnd = [Win32]::FindWindow([NullString]::Value, $WindowTitle)
    if ($hwnd -ne [IntPtr]::Zero) {
        $button = [Win32]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", $ButtonText)
        if ($button -ne [IntPtr]::Zero) {
            [void][Win32]::SendMessage($button, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
            return $true
        }
    }
    return $false
}

# Function to restore power settings to default values
function Reset-PowerSettings {
    try {
        Write-Host "Energie-instellingen terugzetten naar standaard..." -ForegroundColor Yellow
        Write-LogMessage "Start herstel energie-instellingen"

        # Reset to balanced power scheme
        powercfg /setactive SCHEME_BALANCED

        # Reset monitor timeout (15 minutes on AC, 5 minutes on battery)
        powercfg /change monitor-timeout-ac 15
        powercfg /change monitor-timeout-dc 5

        # Reset standby timeout (30 minutes on AC, 15 minutes on battery)
        powercfg /change standby-timeout-ac 30
        powercfg /change standby-timeout-dc 15

        # Reset disk timeout (20 minutes on AC, 10 minutes on battery)
        powercfg /change disk-timeout-ac 20
        powercfg /change disk-timeout-dc 10

        # Enable hibernate
        powercfg /hibernate on

        Write-Host "Energie-instellingen succesvol teruggezet naar standaard" -ForegroundColor Green
        Write-LogMessage "Energie-instellingen hersteld naar standaard"
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Fout bij herstellen energie-instellingen: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Fout bij herstellen energie-instellingen: $errorMsg"
    }
}

# Main script execution
try {
    Write-Host "=== Windows PC Setup Script ===" -ForegroundColor Green
    Write-LogMessage "Script gestart"
    
    # Check for administrative privileges
    if (-not (Test-Administrator)) {
        throw "Dit script moet als administrator worden uitgevoerd!"
    }

    # Connect to WiFi first
    Connect-ToWiFi

    # Optimize power settings
    Write-Host "=== Energie-instellingen Optimaliseren ===" -ForegroundColor Green
    Write-LogMessage "Start energie-instellingen optimalisatie"
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    powercfg /change hibernate-timeout-ac 0
    powercfg /change hibernate-timeout-dc 0
    Write-Host "Energie-instellingen succesvol aangepast" -ForegroundColor Green
    Write-LogMessage "Energie-instellingen optimalisatie voltooid"

    # Install Windows Updates
    Install-WindowsUpdates

    # Install Winget
    if (-not (Install-Winget)) {
        Write-Warning "Winget installatie mislukt - verdergaan met de rest van het script"
    }
    
    # Install Belgian eID software
    Install-BelgianEid
    
    # Get customer number at start
    $klantnummer = Read-Host "Voer het klantnummer in"

    # Add Klantnummer to HTML form
    $autoFillScript = @"
<script>
    function fillForm() {
        console.log('Filling form...');
        // Fill in Klantnummer
        var klantnummerInput = document.getElementById('client-number');
        if (klantnummerInput) {
            klantnummerInput.value = '$klantnummer';
            console.log('Klantnummer filled:', '$klantnummer');
        } else {
            console.log('Klantnummer input not found');
        }
    }

    // Try multiple events to ensure the form is filled
    document.addEventListener('DOMContentLoaded', fillForm);
    window.addEventListener('load', fillForm);
    
    // Backup timeout in case the events don't fire
    setTimeout(fillForm, 500);
</script>
"@

    # Download and open the HTML form with the customer number
    $htmlUrl = "https://raw.githubusercontent.com/VenimK/MusicLover/main/index_updated.html"
    $htmlContent = (Invoke-WebRequest -Uri $htmlUrl).Content
    $tempPath = Join-Path $env:TEMP "Klant_formulier.html"

    # Create temp HTML with auto-fill script
    $htmlContent = $htmlContent -replace '</head>', "$autoFillScript`n</head>"
    Set-Content -Path $tempPath -Value $htmlContent -Force

    # Open the form in default browser
    Start-Process $tempPath

    # Install required modules
    try {
        Write-Host "Benodigde modules installeren..." -ForegroundColor Yellow
        
        # Check if modules are already installed
        $nugetInstalled = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        $psWindowsUpdateInstalled = Get-Module -Name PSWindowsUpdate -ListAvailable -ErrorAction SilentlyContinue

        # Install NuGet if not present
        if (-not $nugetInstalled) {
            Write-Host "NuGet installeren..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
        }
        else {
            Write-Host "NuGet is al geinstalleerd" -ForegroundColor Green
        }

        # Install PSWindowsUpdate if not present
        if (-not $psWindowsUpdateInstalled) {
            Write-Host "PSWindowsUpdate installeren..." -ForegroundColor Yellow
            Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
        }
        else {
            Write-Host "PSWindowsUpdate is al geinstalleerd" -ForegroundColor Green
        }

        Write-LogMessage "Modules succesvol geinstalleerd of waren al aanwezig"
    }
    catch {
        $errorMsg = $_.Exception.Message
        throw "Installatie van modules mislukt: $errorMsg"
    }

    # Import modules
    Write-Host "Modules importeren..." -ForegroundColor Yellow
    Import-Module -Name PSWindowsUpdate -Force
    Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false

    # Windows Updates
    Write-LogMessage "Windows Updates starten"
    try {
        Write-Host "=== Windows Updates Installeren ===" -ForegroundColor Green
        Get-WuList -MicrosoftUpdate -Verbose
        # Added -AutoReboot:$false to prevent automatic reboots
        # Added -IgnoreReboot to skip reboot requests
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:$false -IgnoreReboot -Verbose
        Write-LogMessage "Windows Updates succesvol voltooid"
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-LogMessage "Windows Updates installatie mislukt: $errorMsg"
        Write-Host "Windows Updates installatie mislukt: $errorMsg" -ForegroundColor Red
    }
    
    # Install software using Ninite
    Write-Host "=== Software Installeren ===" -ForegroundColor Green
    Install-NiniteSoftware
    
    # Install Adobe Reader
    Install-AdobeReader
    
    # Clean up Windows apps
    Write-Host "=== Windows Apps Opruimen ===" -ForegroundColor Green
    Remove-WindowsApps
    
    # Reset power settings to default
    Reset-PowerSettings
    
    Write-Host "`n=== Setup Voltooid ===" -ForegroundColor Green
    Write-LogMessage "Script succesvol afgerond"
}
catch {
    Write-Error "Er is een fout opgetreden!"
    Write-LogMessage "FOUT: $($_.Exception.Message)"
    Write-Host "Controleer het logbestand op $logFile voor details" -ForegroundColor Red
}

# Final log message
Write-LogMessage "Script uitvoering beeindigd"
