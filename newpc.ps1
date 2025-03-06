<#
.SYNOPSIS
    Geautomatiseerd installatiescript voor nieuwe Windows PC's in een bedrijfsomgeving.

.DESCRIPTION
    Dit script automatiseert het installatieproces van nieuwe Windows PC's, inclusief:
    - Configuratie van energie-instellingen
    - Netwerk/WiFi configuratie
    - Windows Updates
    - Software installatie via Winget
    - Installatie van specifieke software (Notepad++, Belgian eID, etc.)
    - Node.js omgeving setup
    
    Het script bevat foutafhandeling, logging en meerdere installatiemethoden
    voor betere betrouwbaarheid.

.PARAMETER SkipWindowsUpdates
    Sla de Windows Updates installatie over.

.PARAMETER WifiSSID
    De naam van het WiFi netwerk waarmee verbinding moet worden gemaakt.

.PARAMETER WifiPassword
    Het wachtwoord voor het WiFi netwerk. Moet worden aangeleverd als SecureString voor veiligheid.

.PARAMETER DryRun
    Voer het script uit zonder daadwerkelijke wijzigingen (test modus).

.PARAMETER SkipNodeJSInstallation
    Sla de Node.js installatie over.

.PARAMETER SkipNpmPackages
    Sla de NPM packages installatie over.

.PARAMETER SkipNodeServer
    Sla het starten van de Node.js server over.

.PARAMETER SkipIndexOpen
    Sla het openen van het index bestand over.

.PARAMETER RunNodeJSInstallation
    Forceer de Node.js installatie.

.PARAMETER RunNpmPackages
    Forceer de NPM packages installatie.

.PARAMETER RunNodeServer
    Forceer het starten van de Node.js server.

.PARAMETER RunIndexOpen
    Forceer het openen van het index bestand.

.EXAMPLE
    # Uitvoeren met standaard instellingen
    .\newpc.ps1

.EXAMPLE
    # Uitvoeren met specifieke WiFi gegevens
    $wachtwoord = Read-Host -AsSecureString "Voer WiFi wachtwoord in"
    .\newpc.ps1 -WifiSSID "BedrijfsWiFi" -WifiPassword $wachtwoord

.EXAMPLE
    # Uitvoeren zonder Windows Updates
    .\newpc.ps1 -SkipWindowsUpdates

.NOTES
    Versie:         2.0
    Auteur:         TechStick
    Aanmaakdatum:   2024-01-17
    
    Vereisten:
    - Windows 10 of hoger
    - PowerShell 5.1 of hoger
    - Administratieve rechten
    
    Het script zal:
    1. Energie-instellingen configureren
    2. Netwerk verbinding opzetten
    3. Klantnummer opvragen
    4. Windows Updates installeren (tenzij overgeslagen)
    5. Winget installeren
    6. Notepad++ installeren (met fallback methoden)
    7. Overige software via Winget installeren
    8. Node.js omgeving opzetten (tenzij overgeslagen)

.LINK
    https://github.com/yourusername/yourrepository

#>

[CmdletBinding()]
param(
    [switch]$SkipWindowsUpdates,
    [string]$WifiSSID,
    [SecureString]$WifiPassword,
    [switch]$DryRun,
    [switch]$SkipNodeJSInstallation,
    [switch]$SkipNpmPackages,
    [switch]$SkipNodeServer,
    [switch]$SkipIndexOpen,
    [switch]$RunNodeJSInstallation,
    [switch]$RunNpmPackages,
    [switch]$RunNodeServer,
    [switch]$RunIndexOpen
)

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Host "Dit script vereist Administrator rechten." -ForegroundColor Red
    Write-Host "Start PowerShell als Administrator en probeer opnieuw." -ForegroundColor Red
    
    # Attempt to restart the script with elevated privileges
    try {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    catch {
        Write-Host "Kon script niet opnieuw starten met Administrator rechten." -ForegroundColor Red
        exit 1
    }
}

# Minimum PowerShell version check
$minimumPSVersion = [Version]'5.1'
if ($PSVersionTable.PSVersion -lt $minimumPSVersion) {
    Write-Host "Fout: PowerShell versie $($PSVersionTable.PSVersion) is niet ondersteund." -ForegroundColor Red
    Write-Host "Minimaal vereiste versie: $minimumPSVersion" -ForegroundColor Red
    exit 1
}

# Dependency check function
function Test-ScriptDependencies {
    $dependencies = @{
        'Winget' = { 
            # First check if winget is already available
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                return $true
            }
            
            # If not found, check Windows version
            $osInfo = Get-WmiObject -Class Win32_OperatingSystem
            $windowsVersion = [System.Version]($osInfo.Version)
            
            # For Windows 11 (build 22000 or higher), winget should be pre-installed
            if ($windowsVersion.Build -ge 22000) {
                Write-Host "Windows 11 gedetecteerd. Winget zou pre-geïnstalleerd moeten zijn." -ForegroundColor Yellow
                Write-Host "Controleer of de App Installer correct is geïnstalleerd via de Microsoft Store." -ForegroundColor Yellow
                return $false
            }
            
            # For Windows 10 1809 or later
            if ($windowsVersion.Major -eq 10 -and $windowsVersion.Build -ge 17763) {
                return $false
            }
            
            return $false
        }
        'PSWindowsUpdate' = { Get-Module -ListAvailable -Name PSWindowsUpdate }
        'NetSh' = { Get-Command netsh -ErrorAction SilentlyContinue }
    }

    $missingDependencies = @()
    foreach ($dep in $dependencies.Keys) {
        if (-not (& $dependencies[$dep])) {
            $missingDependencies += $dep
        }
    }

    if ($missingDependencies.Count -gt 0) {
        Write-Host "Ontbrekende afhankelijkheden: $($missingDependencies -join ', ')" -ForegroundColor Red
        return $false
    }
    return $true
}

# Enhanced logging function
function Write-EnhancedLog {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Console output
    switch ($Level) {
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }

    # File logging
    Add-Content -Path $logFile -Value $logMessage
}

# Global error handler
$ErrorActionPreference = 'Stop'
$global:ErrorHandler = {
    param($ErrorRecord)
    
    $errorMessage = $ErrorRecord.Exception.Message
    $errorDetails = $ErrorRecord | Format-List * -Force | Out-String
    
    Write-EnhancedLog -Message "Onverwachte fout: $errorMessage" -Level 'Error'
    Write-EnhancedLog -Message "Fout details: $errorDetails" -Level 'Error'
    
    # Optionally, you could add more advanced error handling here
    # Such as sending an error report, cleaning up temporary files, etc.
}

# Set up global error handler
$global:Error.Clear()
$ErrorView = 'NormalView'

# Verbose logging
function Write-VerboseLog {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
        Add-Content -Path $logFile -Value "[$timestamp] [VERBOSE] $Message"
    }
}

# Dry run mode
function Invoke-DryRunCheck {
    if ($DryRun) {
        Write-Host "[DRY RUN] Simulatie modus - Geen wijzigingen worden doorgevoerd" -ForegroundColor Cyan
        return $true
    }
    return $false
}

# Check for Administrator privileges
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "Dit script vereist Administrator rechten. Start PowerShell als Administrator en probeer opnieuw." -ForegroundColor Red
    exit 1
}

# Script configuratie
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$logFile = if ($global:ClientNumber) {
    Join-Path $env:TEMP "newpc_setup_$($global:ClientNumber)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
} else {
    Join-Path $env:TEMP "newpc_setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}
$configFile = Join-Path $PSScriptRoot "config.ps1"

# Function to log messages
function Write-LogMessage {
    param(
        [string]$Message
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"

        # Console output
        Write-Host $logMessage

        # File logging
        Add-Content -Path $logFile -Value $logMessage
    }
    catch {
        Write-Warning "Kon niet loggen naar bestand: $($_.Exception.Message)"
    }
}

# Function to send SMS notifications using Textbee API
function Send-TextbeeSMS {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$PhoneNumber = $null
    )
    
    try {
        Write-Host "SMS notificatie versturen..." -ForegroundColor Yellow
        Write-LogMessage "Start SMS notificatie verzending"
        
        # Load SMS configuration
        $smsConfigPath = Join-Path $PSScriptRoot "sms_config.ps1"
        if (Test-Path $smsConfigPath) {
            . $smsConfigPath
        } else {
            # Fallback to environment variables
            $TEXTBEE_DEVICE_ID = $env:TEXTBEE_DEVICE_ID
            $TEXTBEE_API_KEY = $env:TEXTBEE_API_KEY
            $TEXTBEE_NOTIFICATION_PHONE = $env:TEXTBEE_NOTIFICATION_PHONE
        }

        # Validate configuration
        if (-not $TEXTBEE_DEVICE_ID -or -not $TEXTBEE_API_KEY) {
            throw "Textbee configuratie ontbreekt. Controleer sms_config.ps1 of omgevingsvariabelen."
        }

        # Use provided phone number or fallback to config
        if (-not $PhoneNumber) {
            $PhoneNumber = $TEXTBEE_NOTIFICATION_PHONE
            if (-not $PhoneNumber) {
                throw "Geen telefoonnummer opgegeven en geen standaard nummer geconfigureerd."
            }
        }

        # Check network connectivity
        if (-not (Test-FastNetworkConnection)) {
            throw "Geen netwerkverbinding beschikbaar."
        }

        # Prepare API request
        $apiUrl = "https://api.textbee.dev/api/v1/gateway/devices/$TEXTBEE_DEVICE_ID/send-sms"
        $headers = @{
            'x-api-key' = $TEXTBEE_API_KEY
            'Content-Type' = 'application/json'
        }
        
        $body = @{
            recipients = @($PhoneNumber)
            message = $Message
        } | ConvertTo-Json

        # Send request
        $null = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body -ContentType 'application/json'
        
        Write-Host "SMS notificatie succesvol verzonden" -ForegroundColor Green
        Write-LogMessage "SMS notificatie succesvol verzonden naar $PhoneNumber"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Fout bij versturen SMS: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Fout bij versturen SMS: $errorMsg"
        
        # Log additional error details if available
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $statusDesc = $_.Exception.Response.StatusDescription
            Write-LogMessage "HTTP Status: $statusCode - $statusDesc"
            
            try {
                $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
                Write-LogMessage "API Error: $($errorDetails.message)"
            } catch {}
        }
        
        return $false
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

# Faster network connectivity check
function Test-FastNetworkConnection {
    # List of reliable DNS servers to test
    $dnsServers = @(
        "8.8.8.8",     # Google DNS
        "1.1.1.1",     # Cloudflare DNS
        "9.9.9.9"      # Quad9 DNS
    )

    # Parallel connection test
    $connectionTasks = $dnsServers | ForEach-Object {
        Start-Job -ScriptBlock {
            param($server)
            try {
                # Faster, lightweight ping with short timeout
                $ping = [System.Net.NetworkInformation.Ping]::new()
                $result = $ping.Send($server, 1000)  # 1-second timeout
                return $result.Status -eq 'Success'
            }
            catch {
                return $false
            }
        } -ArgumentList $_
    }

    # Wait for results with a short overall timeout
    $timeout = 2 # 2 minutes timeout
    $waitResult = Wait-Job -Job $connectionTasks -Timeout $timeout

    if ($waitResult -notcontains $connectionTasks) {
        Write-Host "Timeout bij zoeken naar updates. Doorgaan met gevonden updates..." -ForegroundColor Yellow
        Write-LogMessage "Timeout bij zoeken naar updates"
    }
    
    $successfulConnections = $connectionTasks | 
        Receive-Job | 
        Where-Object { $_ -eq $true }

    # Cleanup jobs
    $connectionTasks | Remove-Job -Force
    
    return ($successfulConnections.Count -gt 0)
}

# Function to setup network connection
function Connect-Network {
    param (
        [Parameter(Mandatory=$false)]
        [string]$WifiSSID,
        [Parameter(Mandatory=$false)]
        [SecureString]$WifiPassword
    )

    Write-Host "`nNetwerk verbinding controleren..." -ForegroundColor Yellow
    Write-LogMessage "Start netwerk verbinding controle"

    # Check for LAN connection first
    if (Test-FastNetworkConnection) {
        Write-Host "LAN verbinding gevonden, verdergaan met script..." -ForegroundColor Green
        Write-LogMessage "LAN verbinding actief"
        return $true
    }

    # Test connection once
    $hasConnection = Test-FastNetworkConnection
    if ($hasConnection) {
        Write-Host "Actieve netwerk verbinding gevonden, verdergaan met script..." -ForegroundColor Green
        Write-LogMessage "Bestaande netwerk verbinding gevonden"
        return $true
    }

    # No network connection, try WiFi
    Write-Host "Geen actieve netwerk verbinding gevonden. WiFi verbinding wordt opgezet..." -ForegroundColor Yellow
    Write-LogMessage "Geen netwerk verbinding gevonden, start WiFi setup"

    # Try to load config file if parameters are not provided
    if (-not $WifiSSID -or -not $WifiPassword) {
        if (Test-Path $configFile) {
            try {
                . $configFile
                if (-not $WifiSSID) { $WifiSSID = $WifiConfig.SSID }
                if (-not $WifiPassword) { $WifiPassword = $WifiConfig.Password }
            }
            catch {
                Write-Host "Fout bij laden van WiFi configuratie: $($_.Exception.Message)" -ForegroundColor Red
                Write-LogMessage "Fout bij laden van WiFi configuratie: $($_.Exception.Message)"
                return $false
            }
        }
        
        # If still no credentials, prompt user
        if (-not $WifiSSID) {
            Write-Host "Voer WiFi SSID in:" -ForegroundColor Cyan
            $WifiSSID = Read-Host
        }
        if (-not $WifiPassword) {
            Write-Host "Voer WiFi wachtwoord in:" -ForegroundColor Cyan
            $WifiPassword = Read-Host -AsSecureString
        }
    }

    Write-Host "Automatisch verbinden met $WifiSSID..." -ForegroundColor Yellow
    Write-LogMessage "Poging tot verbinden met WiFi netwerk: $WifiSSID"

    try {
        # Convert SecureString to plain text only when needed (within the function)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($WifiPassword)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        
        try {
            # Create WiFi profile XML
            $hexSSID = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($WifiSSID)).Replace("-","")
            $profileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$WifiSSID</name>
    <SSIDConfig>
        <SSID>
            <hex>$hexSSID</hex>
            <name>$WifiSSID</name>
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
                <keyMaterial>$plainPassword</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
            # Add the profile
            $profilePath = "$env:TEMP\WiFiProfile.xml"
            $profileXml | Set-Content $profilePath -Encoding UTF8
            $null = netsh wlan add profile filename="$profilePath"
            
            # Connect to network
            netsh wlan connect name="$WifiSSID"
            Start-Sleep -Seconds 5  # Wait for connection
            
            # Cleanup
            if (Test-Path $profilePath) {
                Remove-Item $profilePath -Force
            }
            
            $hasConnection = Test-FastNetworkConnection
            if ($hasConnection) {
                Write-Host "Succesvol verbonden met $WifiSSID" -ForegroundColor Green
                Write-LogMessage "Succesvol verbonden met WiFi netwerk: $WifiSSID"
                return $true
            } else {
                Write-Host "Kon niet verbinden met $WifiSSID binnen 5 seconden" -ForegroundColor Yellow
                Write-LogMessage "Timeout bij verbinden met WiFi netwerk: $WifiSSID"
                return $false
            }
        }
        finally {
            # Clean up the plain text password from memory
            if ($plainPassword) {
                $plainPassword = $null
            }
            if ($BSTR) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            }
        }
    }
    catch {
        Write-Host "Fout bij WiFi verbinding: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij WiFi verbinding: $($_.Exception.Message)"
        return $false
    }
}

# Function to click buttons in windows
function Invoke-Button {
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
        
        # Verify winget is working
        try {
            $wingetVersion = winget --version
            Write-Host "Winget versie: $wingetVersion" -ForegroundColor Cyan
            Write-LogMessage "Winget versie: $wingetVersion"
        }
        catch {
            throw "Winget is niet correct geïnstalleerd. Probeer het script opnieuw uit te voeren."
        }
        
        # Get all available upgrades at once
        Write-Host "Beschikbare updates controleren..." -ForegroundColor Cyan
        $availableUpdates = winget upgrade --accept-source-agreements | Out-String
        $upgradeList = @{}
        
        # Parse the output to create a lookup table of available updates
        $availableUpdates -split "`n" | ForEach-Object {
            if ($_ -match "^[\s\S]+?\s+(\S+)\s+\S+\s+\S+\s+\S+") {
                $upgradeList[$matches[1]] = $true
            }
        }
        
        $softwareList = @(
            @{
                Id = "Google.Chrome"
                RegPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
                    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
                )
                ExePaths = @(
                    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
                )
            },
            @{
                Id = "7zip.7zip"
                RegPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{23170F69-40C1-2702-2102-000001000000}",
                    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{23170F69-40C1-2702-2102-000001000000}"
                )
                ExePaths = @(
                    "$env:ProgramFiles\7-Zip\7z.exe",
                    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
                )
            },
            @{
                Id = "VideoLAN.VLC"
                RegPaths = @(
                    "HKLM:\SOFTWARE\VideoLAN\VLC",
                    "HKLM:\SOFTWARE\Wow6432Node\VideoLAN\VLC",
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player",
                    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\VLC media player"
                )
                ExePaths = @(
                    "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
                    "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
                )
            },
            @{
                Id = "BelgianGovernment.Belgium-eIDmiddleware"
                RegPaths = @(
                    "HKLM:\SOFTWARE\Belgium Identity Card",
                    "HKLM:\SOFTWARE\Wow6432Node\Belgium Identity Card"
                )
            },
            @{
                Id = "BelgianGovernment.eIDViewer"
                RegPaths = @(
                    "HKLM:\SOFTWARE\Belgian eID Viewer",
                    "HKLM:\SOFTWARE\Wow6432Node\Belgian eID Viewer"
                )
            },
            @{
                Id = "Adobe.Acrobat.Reader.64-bit"
                RegPaths = @(
                    "HKLM:\SOFTWARE\Adobe\Acrobat Reader",
                    "HKLM:\SOFTWARE\Wow6432Node\Adobe\Acrobat Reader"
                )
            }
        )
        
        $totalSteps = $softwareList.Count
        $currentStep = 0
        
        foreach ($software in $softwareList) {
            $currentStep++
            $progress = [math]::Round(($currentStep / $totalSteps) * 100)
            
            Show-Progress -Activity "Software Installatie" -Status "Controleren $($software.Id)..." -PercentComplete $progress
            
            Write-Host "`nControleren $($software.Id)..." -ForegroundColor Cyan
            Write-LogMessage "Start controle van $($software.Id)"
            
            # Check if already installed through registry or file paths
            $isInstalled = $false
            
            # Check registry paths
            foreach ($regPath in $software.RegPaths) {
                if (Test-Path $regPath) {
                    $isInstalled = $true
                    break
                }
            }
            
            # Check exe paths if defined
            if (-not $isInstalled -and $software.ExePaths) {
                foreach ($exePath in $software.ExePaths) {
                    if (Test-Path $exePath) {
                        $isInstalled = $true
                        break
                    }
                }
            }
            
            # Double check with winget if not found in registry/files
            if (-not $isInstalled) {
                $null = winget list --id $software.Id --exact
                $isInstalled = $LASTEXITCODE -eq 0
            }
            
            if ($isInstalled) {
                # Check if update is available using the pre-fetched list
                if ($upgradeList.ContainsKey($software.Id)) {
                    Write-Host "$($software.Id) update beschikbaar. Bijwerken..." -ForegroundColor Yellow
                    Write-LogMessage "$($software.Id) update beschikbaar, start upgrade"
                    
                    $retryCount = 0
                    $maxRetries = if ($software.RetryCount) { $software.RetryCount } else { 1 }
                    $success = $false
                    
                    while (-not $success -and $retryCount -lt $maxRetries) {
                        if ($retryCount -gt 0) {
                            Write-Host "Poging $($retryCount + 1) van $maxRetries..." -ForegroundColor Yellow
                        }
                        
                        if ($software.WingetArgs) {
                            winget upgrade --id $software.Id --exact --silent --accept-source-agreements --accept-package-agreements @($software.WingetArgs)
                        } else {
                            winget upgrade --id $software.Id --exact --silent --accept-source-agreements --accept-package-agreements
                        }
                        
                        if ($LASTEXITCODE -eq 0) {
                            $success = $true
                            Write-Host "$($software.Id) is bijgewerkt naar de laatste versie" -ForegroundColor Green
                            Write-LogMessage "$($software.Id) upgrade succesvol"
                        } else {
                            $retryCount++
                            if ($retryCount -lt $maxRetries) {
                                Write-Host "Update mislukt, opnieuw proberen..." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2
                            }
                        }
                    }
                    
                    if (-not $success) {
                        Write-Host "Waarschuwing: $($software.Id) update mislukt na $maxRetries pogingen" -ForegroundColor Yellow
                        Write-LogMessage "$($software.Id) update mislukt na $maxRetries pogingen"
                    }
                } else {
                    Write-Host "$($software.Id) is al geinstalleerd en up-to-date" -ForegroundColor Green
                    Write-LogMessage "$($software.Id) is up-to-date"
                }
            } else {
                # Install if not present
                Write-Host "$($software.Id) wordt geinstalleerd..." -ForegroundColor Yellow
                
                $retryCount = 0
                $maxRetries = if ($software.RetryCount) { $software.RetryCount } else { 1 }
                $success = $false
                
                while (-not $success -and $retryCount -lt $maxRetries) {
                    if ($retryCount -gt 0) {
                        Write-Host "Poging $($retryCount + 1) van $maxRetries..." -ForegroundColor Yellow
                    }
                    
                    if ($software.WingetArgs) {
                        winget install --id $software.Id --exact --silent --accept-source-agreements --accept-package-agreements @($software.WingetArgs)
                    } else {
                        winget install --id $software.Id --exact --silent --accept-source-agreements --accept-package-agreements
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        $success = $true
                        Write-Host "$($software.Id) succesvol geinstalleerd" -ForegroundColor Green
                        Write-LogMessage "$($software.Id) installatie succesvol"
                        
                        # Extra verification for new installations
                        Start-Sleep -Seconds 2  # Wait for installation to complete
                        if ($software.ExePaths) {
                            $exeExists = $false
                            foreach ($exePath in $software.ExePaths) {
                                if (Test-Path $exePath) {
                                    $exeExists = $true
                                    break
                                }
                            }
                            if (-not $exeExists) {
                                Write-Host "Waarschuwing: $($software.Id) executable niet gevonden na installatie" -ForegroundColor Yellow
                                Write-LogMessage "$($software.Id) executable niet gevonden na installatie"
                                $success = $false  # Mark as failed to trigger retry
                            }
                        }
                    }
                    
                    if (-not $success) {
                        $retryCount++
                        if ($retryCount -lt $maxRetries) {
                            Write-Host "Installatie mislukt, opnieuw proberen..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                        }
                    }
                }
                
                if (-not $success) {
                    Write-Host "Waarschuwing: $($software.Id) installatie mislukt na $maxRetries pogingen" -ForegroundColor Yellow
                    Write-LogMessage "$($software.Id) installatie mislukt na $maxRetries pogingen"
                }
            }
        }
        
        Show-Progress -Activity "Software Installatie" -Status "Voltooid" -PercentComplete 100
        Write-Host "`nAlle software installaties voltooid" -ForegroundColor Green
        Write-LogMessage "Software installaties voltooid"
        return $true
    }
    catch {
        Write-Host "Software installatie mislukt: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Software installatie mislukt: $($_.Exception.Message)"
        Show-Progress -Activity "Software Installatie" -Status "Mislukt" -PercentComplete 100
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
    try {
        Write-Host "Windows Updates installeren..." -ForegroundColor Yellow
        Write-LogMessage "Start Windows Updates installatie"

        # Install PSWindowsUpdate module if not present
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Install-WindowsUpdateModule
        }
        
        # Import the module
        Import-Module PSWindowsUpdate
        
        # Get updates in parallel
        Write-Host "Updates zoeken..." -ForegroundColor Yellow
        
        $regularJob = Start-Job -ScriptBlock { 
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate 
        }
        
        $optionalJob = Start-Job -ScriptBlock { 
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate -IsHidden 
        }
        
        # Wait for both jobs to complete with timeout
        $timeout = 120 # 2 minutes timeout
        $completed = Wait-Job -Job $regularJob, $optionalJob -Timeout $timeout

        if ($completed -notcontains $regularJob -or $completed -notcontains $optionalJob) {
            Write-Host "Timeout bij zoeken naar updates. Doorgaan met gevonden updates..." -ForegroundColor Yellow
            Write-LogMessage "Timeout bij zoeken naar updates"
        }
        
        $regularUpdates = Receive-Job -Job $regularJob -ErrorAction SilentlyContinue
        $optionalUpdates = Receive-Job -Job $optionalJob -ErrorAction SilentlyContinue
        
        Remove-Job -Job $regularJob, $optionalJob -Force
        
        $regularCount = if ($regularUpdates) { @($regularUpdates).Count } else { 0 }
        $optionalCount = if ($optionalUpdates) { @($optionalUpdates).Count } else { 0 }
        $totalUpdates = $regularCount + $optionalCount

        if ($totalUpdates -eq 0) {
            Write-Host "Geen updates beschikbaar (regulier of optioneel)" -ForegroundColor Green
            Write-LogMessage "Geen Windows Updates beschikbaar"
            return $true
        }

        Write-Host "Gevonden updates:" -ForegroundColor Yellow
        Write-Host "- Reguliere updates: $regularCount" -ForegroundColor Yellow
        Write-Host "- Optionele updates: $optionalCount" -ForegroundColor Yellow
        Write-LogMessage "Gevonden: $regularCount reguliere updates, $optionalCount optionele updates"

        # Display detailed update information
        if ($regularCount -gt 0) {
            Write-Host "`nDetails van reguliere updates:" -ForegroundColor Yellow
            foreach ($update in $regularUpdates) {
                Write-Host "  * $($update.Title)" -ForegroundColor White
                Write-Host "    - Grootte: $([math]::Round($update.Size / 1MB, 2)) MB" -ForegroundColor Gray
                Write-Host "    - KB Nummer: $($update.KBArticleIDs)" -ForegroundColor Gray
                Write-LogMessage "Update gevonden: $($update.Title) (KB$($update.KBArticleIDs))"
            }
        }

        if ($optionalCount -gt 0) {
            Write-Host "`nDetails van optionele updates:" -ForegroundColor Yellow
            foreach ($update in $optionalUpdates) {
                Write-Host "  * $($update.Title)" -ForegroundColor White
                Write-Host "    - Grootte: $([math]::Round($update.Size / 1MB, 2)) MB" -ForegroundColor Gray
                Write-Host "    - KB Nummer: $($update.KBArticleIDs)" -ForegroundColor Gray
                Write-LogMessage "Optionele update gevonden: $($update.Title) (KB$($update.KBArticleIDs))"
            }
        }

        # Create log directory if it doesn't exist
        $logDir = Join-Path $env:TEMP "WindowsUpdateLogs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Define log paths
        $regularUpdatesLog = Join-Path $logDir "Windows_Regular_Updates_Log.txt"
        $optionalUpdatesLog = Join-Path $logDir "Windows_Optional_Updates_Log.txt"

        # Install updates concurrently
        $jobs = @()

        # Start regular updates
        if ($regularCount -gt 0) {
            Write-Host "`nReguliere updates worden geinstalleerd..." -ForegroundColor Yellow
            $jobs += Start-Job -ScriptBlock {
                param($LogPath)
                try {
                    Import-Module PSWindowsUpdate
                    $result = Install-WindowsUpdate -AcceptAll -AutoReboot:$false -IgnoreReboot -Confirm:$false -Verbose *> $LogPath
                    if ($result) {
                        $result | ConvertTo-Json | Out-File "$LogPath.json"
                    }
                }
                catch {
                    "Error: $($_.Exception.Message)" | Out-File $LogPath -Append
                    throw $_
                }
            } -ArgumentList $regularUpdatesLog
        }

        # Start optional updates
        if ($optionalCount -gt 0) {
            Write-Host "Optionele updates worden geinstalleerd..." -ForegroundColor Yellow
            $jobs += Start-Job -ScriptBlock {
                param($LogPath)
                try {
                    Import-Module PSWindowsUpdate
                    $result = Install-WindowsUpdate -AcceptAll -AutoReboot:$false -IsHidden -IgnoreReboot -Confirm:$false -Verbose *> $LogPath
                    if ($result) {
                        $result | ConvertTo-Json | Out-File "$LogPath.json"
                    }
                }
                catch {
                    "Error: $($_.Exception.Message)" | Out-File $LogPath -Append
                    throw $_
                }
            } -ArgumentList $optionalUpdatesLog
        }

        # Monitor progress with enhanced status reporting
        while ($jobs.State -contains "Running") {
            foreach ($job in $jobs) {
                if ($job.State -eq "Running") {
                    $logPath = $job.ArgumentList
                    if ($logPath -and (Test-Path $logPath)) {
                        $latestLog = Get-Content $logPath -Tail 1 -ErrorAction SilentlyContinue
                        if ($latestLog) {
                            Write-Host "Status: $latestLog" -ForegroundColor Gray
                        }
                    }
                }
            }
            Start-Sleep -Seconds 10
        }

        # Process results
        foreach ($job in $jobs) {
            $logPath = $job.ArgumentList
            if ($logPath) {
                $jsonPath = "$logPath.json"
                
                # Check for errors in the log file
                if (Test-Path $logPath) {
                    $errorContent = Get-Content $logPath | Where-Object { $_ -like "*Error:*" }
                    if ($errorContent) {
                        Write-Host "Fout bij update installatie:" -ForegroundColor Red
                        Write-Host $errorContent -ForegroundColor Red
                        Write-LogMessage "Update fout: $errorContent"
                    }
                }
                
                # Process successful updates
                if (Test-Path $jsonPath) {
                    $updateResults = Get-Content $jsonPath | ConvertFrom-Json
                    Write-Host "`nGeinstalleerde updates:" -ForegroundColor Green
                    foreach ($update in $updateResults) {
                        Write-Host "  * $($update.Title) - Status: $($update.Result)" -ForegroundColor White
                        Write-LogMessage "Update geinstalleerd: $($update.Title) - Status: $($update.Result)"
                    }
                }
            }
            
            # Cleanup job
            Remove-Job $job -Force
        }

        # Cleanup log files
        if (Test-Path $logDir) {
            Get-ChildItem $logDir -Filter "Windows_*_Updates_Log*" | Remove-Item -Force
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
        
        # Firewall configuratie voor poort 3000
        try {
            # Verwijder bestaande regels (voorkomt dubbele regels)
            $existingInboundRule = Get-NetFirewallRule -DisplayName "Node.js Server Inkomend (Poort 3000)" -ErrorAction SilentlyContinue
            if ($existingInboundRule) {
                Remove-NetFirewallRule -DisplayName "Node.js Server Inkomend (Poort 3000)"
            }

            # Maak nieuwe inkomende firewallregel
            New-NetFirewallRule `
                -DisplayName "Node.js Server Inkomend (Poort 3000)" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort 3000 `
                -Action Allow `
                -Enabled True `
                -Profile Any `
                -Description "Inkomende verbinding voor Node.js server op poort 3000"

            # Maak ook een uitgaande regel
            $existingOutboundRule = Get-NetFirewallRule -DisplayName "Node.js Server Uitgaand (Poort 3000)" -ErrorAction SilentlyContinue
            if ($existingOutboundRule) {
                Remove-NetFirewallRule -DisplayName "Node.js Server Uitgaand (Poort 3000)"
            }

            New-NetFirewallRule `
                -DisplayName "Node.js Server Uitgaand (Poort 3000)" `
                -Direction Outbound `
                -Protocol TCP `
                -LocalPort 3000 `
                -Action Allow `
                -Enabled True `
                -Profile Any `
                -Description "Uitgaande verbinding voor Node.js server op poort 3000"
        }
        catch {
            Write-Host "Waarschuwing: Fout bij configureren firewall: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Start server.js in a new window
        $serverPath = Join-Path $PSScriptRoot "email-server.js"
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

# Function to restore default power settings
function Restore-DefaultPowerSettings {
    try {
        Write-Host "Energie-instellingen terugzetten naar standaard..." -ForegroundColor Yellow
        Write-LogMessage "Energie-instellingen terugzetten gestart"

        # Set power plan to Balanced
        $powerPlan = Get-WmiObject -Namespace root\cimv2\power -Class Win32_PowerPlan | Where-Object { $_.ElementName -eq "Balanced" }
        if ($powerPlan) {
            $powerPlan.Activate()
            Write-Host "Balanced energieplan geactiveerd" -ForegroundColor Green
        }

        # Restore default power settings using powercfg
        # Default display timeout (15 minutes when plugged in, 5 minutes on battery)
        powercfg /change monitor-timeout-ac 15
        powercfg /change monitor-timeout-dc 5
        # Default sleep settings (30 minutes when plugged in, 15 minutes on battery)
        powercfg /change standby-timeout-ac 30
        powercfg /change standby-timeout-dc 15
        # Default hard disk timeout (20 minutes)
        powercfg /change disk-timeout-ac 20
        powercfg /change disk-timeout-dc 20
        # Enable hibernate
        powercfg /hibernate on
        # Enable USB selective suspend
        powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
        # Apply changes
        powercfg /setactive scheme_current

        Write-Host "Energie-instellingen succesvol teruggezet naar standaard" -ForegroundColor Green
        Write-LogMessage "Energie-instellingen succesvol teruggezet naar standaard"
    }
    catch {
        Write-LogMessage "Energie-instellingen terugzetten mislukt: $($_.Exception.Message)"
        Write-Host "Energie-instellingen terugzetten mislukt" -ForegroundColor Red
    }
}

# Function to install Winget
function Install-Winget {
    try {
        # Check if we're on Windows 11
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem
        $windowsVersion = [System.Version]($osInfo.Version)
        $isWindows11 = $windowsVersion.Build -ge 22000

        # If on Windows 11 and winget is missing, try to repair App Installer first
        if ($isWindows11) {
            Write-Host "Windows 11 gedetecteerd, controleren op App Installer..." -ForegroundColor Yellow
            Write-LogMessage "Windows 11 gedetecteerd, App Installer controle"
            
            try {
                # Try to get App Installer from Microsoft Store
                $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"
                if (-not $appInstaller) {
                    Write-Host "App Installer niet gevonden, proberen te installeren via Microsoft Store..." -ForegroundColor Yellow
                    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
                    Write-Host "Microsoft Store geopend. Installeer de 'App Installer' en start dit script opnieuw." -ForegroundColor Cyan
                    return $false
                } else {
                    # Try to repair existing App Installer
                    Write-Host "App Installer gevonden, proberen te repareren..." -ForegroundColor Yellow
                    Add-AppxPackage -RegisterByFamilyName -MainPackage $appInstaller.PackageFamilyName -DisableDevelopmentMode
                }
            } catch {
                Write-Host "Fout bij App Installer controle: $($_.Exception.Message)" -ForegroundColor Red
                Write-LogMessage "Fout bij App Installer controle: $($_.Exception.Message)"
            }
        }

        Write-Host "`nWinget installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Winget installatie"
        
        Show-Progress -Activity "Winget Installatie" -Status "Voorbereiden..." -PercentComplete 0

        # Install prerequisites
        Show-Progress -Activity "Winget Installatie" -Status "Controleren vereisten..." -PercentComplete 10
        Write-Host "`nControleren en installeren van vereiste componenten..." -ForegroundColor Cyan
        Write-LogMessage "Controleren vereiste componenten"

        # Install VCLibs
        try {
            $vcLibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
            $vcLibsPath = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
            Write-Host "Downloaden VCLibs..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $vcLibsUrl -OutFile $vcLibsPath
            Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue
            Remove-Item $vcLibsPath -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "Waarschuwing: VCLibs installatie overgeslagen: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-LogMessage "VCLibs installatie overgeslagen: $($_.Exception.Message)"
        }

        # Install UI.Xaml
        try {
            $xamlUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.3"
            $xamlPath = "$env:TEMP\Microsoft.UI.Xaml.2.7.3.zip"
            $xamlExtractPath = "$env:TEMP\Microsoft.UI.Xaml"
            
            Write-Host "Downloaden UI.Xaml..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $xamlUrl -OutFile $xamlPath
            Expand-Archive -Path $xamlPath -DestinationPath $xamlExtractPath -Force
            Add-AppxPackage -Path "$xamlExtractPath\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx" -ErrorAction SilentlyContinue
            
            Remove-Item $xamlPath -ErrorAction SilentlyContinue
            Remove-Item $xamlExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "Waarschuwing: UI.Xaml installatie overgeslagen: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-LogMessage "UI.Xaml installatie overgeslagen: $($_.Exception.Message)"
        }

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
        
        $wingetPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
        $wingetUrls = @(
            "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle",
            "https://aka.ms/getwinget"
        )

        $downloadSuccess = $false
        foreach ($url in $wingetUrls) {
            try {
                Write-Host "Proberen te downloaden van: $url" -ForegroundColor Cyan
                Invoke-WebRequest -Uri $url -OutFile $wingetPath
                $downloadSuccess = $true
                break
            }
            catch {
                Write-Host "Download mislukt van $url : $($_.Exception.Message)" -ForegroundColor Yellow
                Write-LogMessage "Winget download mislukt van $url : $($_.Exception.Message)"
                continue
            }
        }

        if (-not $downloadSuccess) {
            throw "Kon Winget installer niet downloaden van alle beschikbare bronnen"
        }

        Show-Progress -Activity "Winget Installatie" -Status "Installeren..." -PercentComplete 60
        Write-Host "`nWinget installeren..." -ForegroundColor Cyan
        Write-LogMessage "Installeren Winget"
        
        try {
            Add-AppxPackage -Path $wingetPath -ErrorAction Stop
        }
        catch {
            Write-Host "Eerste installatie poging mislukt, proberen met alternatieve methode..." -ForegroundColor Yellow
            Write-LogMessage "Eerste installatie poging mislukt, proberen alternatief"
            
            # Try alternative installation method
            try {
                Start-Process "PowerShell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command Add-AppxPackage -Path `"$wingetPath`"" -Wait -NoNewWindow
            }
            catch {
                throw "Beide installatie methoden zijn mislukt: $($_.Exception.Message)"
            }
        }

        # Ruim het installatiebestand op
        Show-Progress -Activity "Winget Installatie" -Status "Opruimen..." -PercentComplete 80
        if (Test-Path $wingetPath) {
            Remove-Item $wingetPath -ErrorAction SilentlyContinue
        }

        # Ververs omgevingsvariabelen
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verifieer installatie
        Show-Progress -Activity "Winget Installatie" -Status "Verificatie..." -PercentComplete 90
        Write-Host "`nWinget installatie verifieren..." -ForegroundColor Cyan
        Write-LogMessage "Verifieren Winget installatie"
        
        $retryCount = 0
        $maxRetries = 3
        $wingetVersion = $null
        
        while ($retryCount -lt $maxRetries) {
            try {
                $wingetVersion = winget --version
                break
            }
            catch {
                $retryCount++
                if ($retryCount -eq $maxRetries) {
                    throw "Kon Winget versie niet verifieren na $maxRetries pogingen"
                }
                Write-Host "Wachten op Winget initialisatie... (poging $retryCount van $maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
        
        # Accept Microsoft Store agreements
        Show-Progress -Activity "Winget Installatie" -Status "Configureren..." -PercentComplete 95
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
    Write-Host "`nIndex bestand downloaden en openen..." -ForegroundColor Cyan
    
    try {
        Show-Progress -Activity "Index Bestand" -Status "Voorbereiden..." -PercentComplete 10
        
        Write-Host "`nVul de volgende klantgegevens in:" -ForegroundColor Yellow
        Write-Host "--------------------------------"
        Write-Host "* Klantnaam"
        Write-Host "* Telefoonnummer"
        Write-Host "* E-mailadres"
        Write-Host "--------------------------------`n"
        
        Show-Progress -Activity "Index Bestand" -Status "Downloaden..." -PercentComplete 30
        
        # Get system serial number
        $serialNumber = Get-WmiObject -Class Win32_BIOS | Select-Object -ExpandProperty SerialNumber
        Write-Host "PC Serienummer: $serialNumber" -ForegroundColor Cyan
        
        # Display client number if available
        if ($global:ClientNumber) {
            Write-Host "Klantnummer: $global:ClientNumber" -ForegroundColor Cyan
        }
        
        Show-Progress -Activity "Index Bestand" -Status "Chrome openen..." -PercentComplete 80
        
        # Open index.html in Chrome (minimized)
        $indexUrl = "file:///$PSScriptRoot/index_updated1.html?serial=$serialNumber"
        
        if ($global:ClientNumber) {
            $indexUrl += "&client=$global:ClientNumber"
        }
        
        $chromeParams = @{
            FilePath = "chrome.exe"
            ArgumentList = "--new-window", $indexUrl
            WindowStyle = "Minimized"
            PassThru = $true
        }
        Start-Process @chromeParams | Out-Null
        
        Show-Progress -Activity "Index Bestand" -Status "Gereed" -PercentComplete 100
        Write-Host "`nIndex bestand succesvol geopend in Chrome (geminimaliseerd)" -ForegroundColor Green
        Write-LogMessage "Index bestand geopend in Chrome"
        return $true
    }
    catch {
        Write-Host "Fout bij openen index bestand: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij openen index bestand: $_"
        Show-Progress -Activity "Index Bestand" -Status "Mislukt" -PercentComplete 100
        return $false
    }
}

# Function to focus PowerShell window
function Set-PowerShellWindowFocus {
    $PSWindow = [Window]::GetConsoleWindow()
    [Window]::ShowWindow($PSWindow, 5)
    [Window]::SetForegroundWindow($PSWindow)
}

# Function to handle Extra Software Pack installations
function Install-ExtraSoftwarePack {
    Write-Host "`nExtra Software Pack installatie starten..." -ForegroundColor Yellow
    Write-LogMessage "Start Extra Software Pack installatie"
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

# Function to install Microsoft Office
function Install-MicrosoftOffice {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('365business.xml', 'Office2021.xml', 'office2024.xml')]
        [string]$ConfigFile
    )

    try {
        Write-Host "`nMicrosoft Office installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Microsoft Office installatie met configuratie: $ConfigFile"

        # Check for admin rights
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            throw "Dit script moet als Administrator worden uitgevoerd voor Office installatie. Start PowerShell opnieuw als Administrator."
        }

        Show-Progress -Activity "Microsoft Office" -Status "ODT locatie zoeken..." -PercentComplete 10

        # First check USB drives
        $usbDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
        $fixedDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        
        $odtFound = $false
        $odtPath = $null

        # First try USB drives
        if ($usbDrives) {
            Write-Host "USB drive(s) gevonden, controleren op Office map..." -ForegroundColor Yellow
            foreach ($drive in $usbDrives) {
                $testPath = Join-Path $drive.DeviceID "Office"
                if (Test-Path $testPath) {
                    $odtPath = $testPath
                    $odtFound = $true
                    break
                }
            }
        }

        # If not found on USB, try fixed drives
        if (-not $odtFound) {
            Write-Host "Office niet gevonden op USB drives, controleren vaste schijven..." -ForegroundColor Yellow
            foreach ($drive in $fixedDrives) {
                $testPath = Join-Path $drive.DeviceID "Office"
                if (Test-Path $testPath) {
                    $odtPath = $testPath
                    $odtFound = $true
                    break
                }
            }
        }

        if (-not $odtFound) {
            throw "Office map niet gevonden. Sluit een USB drive aan met de Office map of maak deze aan op een vaste schijf."
        }

        Show-Progress -Activity "Microsoft Office" -Status "Configuratie controleren..." -PercentComplete 30

        # Verify config file exists
        $configPath = Join-Path $odtPath $ConfigFile
        if (-not (Test-Path $configPath)) {
            throw "Configuratie bestand $ConfigFile niet gevonden in Office map."
        }

        Show-Progress -Activity "Microsoft Office" -Status "Setup.exe controleren..." -PercentComplete 50

        # Start installation
        $setupPath = Join-Path $odtPath "setup.exe"
        if (-not (Test-Path $setupPath)) {
            throw "setup.exe niet gevonden in Office map."
        }

        Show-Progress -Activity "Microsoft Office" -Status "Installatie starten..." -PercentComplete 70
        Write-Host "Office installatie starten met $ConfigFile..." -ForegroundColor Yellow
        Write-LogMessage "Office installatie gestart met configuratie: $ConfigFile"

        # Execute ODT with configuration
        $process = Start-Process $setupPath -ArgumentList "/configure", $configPath -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Show-Progress -Activity "Microsoft Office" -Status "Installatie voltooid" -PercentComplete 100
            Write-Host "Microsoft Office installatie succesvol afgerond" -ForegroundColor Green
            Write-LogMessage "Microsoft Office installatie succesvol afgerond"
            return $true
        } else {
            throw "Office installatie mislukt met exit code: $($process.ExitCode)"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Microsoft Office installatie mislukt: $errorMsg" -ForegroundColor Red
        Write-LogMessage "Microsoft Office installatie mislukt: $errorMsg"
        Show-Progress -Activity "Microsoft Office" -Status "Installatie mislukt" -PercentComplete 100
        return $false
    }
}

function Get-ClientNumber {
    Write-Host "`nVoer het klantnummer in:" -ForegroundColor Cyan
    $clientNumber = Read-Host
    
    if ($clientNumber) {
        Write-LogMessage "Klantnummer ingevoerd: $clientNumber"
        return $clientNumber
    }
    
    Write-Host "Geen klantnummer ingevoerd. Script wordt voortgezet." -ForegroundColor Yellow
    Write-LogMessage "Geen klantnummer ingevoerd"
    return $null
}

# Function to install Notepad++
function Install-NotepadPlusPlus {
    $exePaths = @(
        "$env:ProgramFiles\Notepad++\notepad++.exe",
        "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    )
    
    # Check if already installed
    foreach ($exePath in $exePaths) {
        if (Test-Path $exePath) {
            Write-Host "Notepad++ is al geinstalleerd" -ForegroundColor Green
            Write-LogMessage "Notepad++ is al geinstalleerd"
            return $true
        }
    }

    Write-Host "Notepad++ installeren..." -ForegroundColor Yellow
    Write-LogMessage "Start Notepad++ installatie"

    $methods = @(
        @{
            Name = "Winget"
            Action = {
                try {
                    Write-Host "Proberen te installeren via Winget..." -ForegroundColor Yellow
                    Write-LogMessage "Poging tot installatie via Winget"
                    winget install --id Notepad++.Notepad++ --exact --silent --accept-source-agreements --accept-package-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Notepad++ succesvol geinstalleerd via Winget" -ForegroundColor Green
                        Write-LogMessage "Notepad++ installatie succesvol via Winget"
                        return $true
                    }
                    return $false
                }
                catch {
                    Write-LogMessage "Fout bij installatie via Winget: $_"
                    return $false
                }
            }
        }
    )
    
    foreach ($method in $methods) {
        Write-Host "`nProberen te installeren met $($method.Name)..." -ForegroundColor Yellow
        Write-LogMessage "Poging tot installatie met $($method.Name)"
        
        if (& $method.Action) {
            Write-Host "Notepad++ succesvol geinstalleerd met $($method.Name)" -ForegroundColor Green
            Write-LogMessage "Notepad++ installatie succesvol met $($method.Name)"
            return $true
        }
    }
    
    Write-Host "Notepad++ installatie mislukt" -ForegroundColor Red
    Write-LogMessage "Notepad++ installatie mislukt"
    return $false
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

# Function to detect system language
function Get-SystemLanguage {
    try {
        # Get system culture/language
        $culture = Get-Culture
        $languageCode = $culture.TwoLetterISOLanguageName.ToLower()
        
        Write-Host "Gedetecteerde systeemtaal/Detected system language: $languageCode" -ForegroundColor Cyan
        Write-LogMessage "Gedetecteerde systeemtaal/Detected system language: $languageCode"
        
        # Check if we support this language
        if ($script:Translations.ContainsKey($languageCode)) {
            return $languageCode
        }
        else {
            # Default to English if available, otherwise Dutch
            if ($script:Translations.ContainsKey('en')) {
                Write-Host "Taal niet ondersteund, Engels wordt gebruikt/Language not supported, using English" -ForegroundColor Yellow
                Write-LogMessage "Taal niet ondersteund, Engels wordt gebruikt/Language not supported, using English"
                return 'en'
            }
            else {
                Write-Host "Taal niet ondersteund, Nederlands wordt gebruikt/Language not supported, using Dutch" -ForegroundColor Yellow
                Write-LogMessage "Taal niet ondersteund, Nederlands wordt gebruikt/Language not supported, using Dutch"
                return 'nl'
            }
        }
    }
    catch {
        Write-Host "Fout bij detecteren taal/Error detecting language: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Fout bij detecteren taal/Error detecting language: $($_.Exception.Message)"
        return 'nl' # Default to Dutch on error
    }
}

# Function to get translated text
function Get-TranslatedText {
    param(
        [string]$Key,
        [array]$Parameters = @()
    )
    
    # Use the detected system language or default to Dutch
    $language = $script:DetectedLanguage
    
    # Check if the key exists in the selected language
    if ($script:Translations.ContainsKey($language) -and $script:Translations[$language].ContainsKey($Key)) {
        $text = $script:Translations[$language][$Key]
    }
    # Fallback to Dutch if the key doesn't exist in the selected language
    elseif ($script:Translations['nl'].ContainsKey($Key)) {
        $text = $script:Translations['nl'][$Key]
    }
    # Last resort fallback
    else {
        return "[$Key]"
    }
    
    # Replace parameters if provided
    if ($Parameters.Count -gt 0) {
        for ($i = 0; $i -lt $Parameters.Count; $i++) {
            $text = $text -replace "\{$i\}", $Parameters[$i]
        }
    }
    
    return $text
}

# Language settings and translations
$script:Translations = @{
    'nl' = @{
        'welcome' = "=== Windows PC Setup Script ==="
        'step1' = "Stap 1: Energiebeheer instellen..."
        'step2' = "Stap 2: Netwerk configureren..."
        'step3' = "Stap 3: Windows updates controleren..."
        'step4' = "Stap 4: Software installeren..."
        'step5' = "Stap 5: Node.js omgeving instellen..."
        'winget_installed' = "Winget is reeds geïnstalleerd, ga door naar volgende stap..."
        'winget_not_found' = "Winget is niet gevonden, start installatie..."
        'error_occurred' = "Er is een fout opgetreden: {0}"
    }
    'en' = @{
        'welcome' = "=== Windows PC Setup Script ==="
        'step1' = "Step 1: Setting up power management..."
        'step2' = "Step 2: Configuring network..."
        'step3' = "Step 3: Checking Windows Updates..."
        'step4' = "Step 4: Installing software..."
        'step5' = "Step 5: Setting up Node.js environment..."
        'winget_installed' = "Winget is already installed, proceeding to next step..."
        'winget_not_found' = "Winget not found, starting installation..."
        'error_occurred' = "An error occurred: {0}"
    }
}

# Main script execution
try {
    # Detect system language
    $script:DetectedLanguage = Get-SystemLanguage
    
    Write-Host (Get-TranslatedText 'welcome') -ForegroundColor Cyan
    Write-LogMessage "Script gestart"

    # Stap 1: Execution Policy
    Write-Host "`n" + (Get-TranslatedText 'step1') -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
    Write-LogMessage "Execution Policy ingesteld op Bypass"

    # Stap 2: Energie-instellingen optimaliseren
    Write-Host "`n" + (Get-TranslatedText 'step2') -ForegroundColor Yellow
    Set-OptimalPowerSettings

    # Stap 3: Netwerk verbinding
    Write-Host "`n" + (Get-TranslatedText 'step3') -ForegroundColor Yellow
    $networkParams = @{}
    if ($WifiSSID) { $networkParams['WifiSSID'] = $WifiSSID }
    if ($WifiPassword) { $networkParams['WifiPassword'] = $WifiPassword }
    Connect-Network @networkParams
    
    # Stap 3b: Klantnummer invoeren
    Write-Host "`n" + (Get-TranslatedText 'step4') -ForegroundColor Yellow
    $global:ClientNumber = Get-ClientNumber

    # Stap 4: Windows Updates
    if (-not $SkipWindowsUpdates) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Install-WindowsUpdateModule
        Install-WindowsUpdates
        
        Send-TextbeeSMS -Message (Get-TranslatedText 'error_occurred' -Parameters @("Windows Updates compleet voor client $global:ClientNumber"))
    } else {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Write-LogMessage "Windows Updates overgeslagen door SkipWindowsUpdates parameter"
    }

    # Stap 5: Microsoft Office installatie
    Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
    Write-Host (Get-TranslatedText 'welcome') -ForegroundColor Cyan
    Write-Host "1. Microsoft 365 Business"
    Write-Host "2. Office 2021"
    Write-Host "3. Office 2024"
    Write-Host "4. Geen Office installatie"
    Write-Host "(Automatisch overslaan na 30 seconden)" -ForegroundColor Gray
    
    $timeoutSeconds = 20
    $choice = $null
    $startTime = Get-Date
    
    while (-not $choice -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -match '[1-4]') {
                $choice = $key.KeyChar
                Write-Host "Keuze: $choice"
            }
        }
        Start-Sleep -Milliseconds 100
    }
    
    switch ($choice) {
        "1" { 
            Install-MicrosoftOffice -ConfigFile "365business.xml"
        }
        "2" { 
            Install-MicrosoftOffice -ConfigFile "Office2021.xml"
        }
        "3" { 
            Install-MicrosoftOffice -ConfigFile "office2024.xml"
        }
        default {
            if ($choice) {
                Write-Host (Get-TranslatedText 'error_occurred' -Parameters @("Office installatie overgeslagen")) -ForegroundColor Yellow
                Write-LogMessage "Office installatie overgeslagen door gebruiker"
            } else {
                Write-Host (Get-TranslatedText 'error_occurred' -Parameters @("Geen keuze gemaakt binnen 30 seconden. Office installatie overgeslagen")) -ForegroundColor Yellow
                Write-LogMessage "Office installatie overgeslagen: timeout"
            }
        }
    }

    # Stap 6: Winget installatie
    Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host (Get-TranslatedText 'winget_installed') -ForegroundColor Green
        Write-LogMessage "Winget is reeds geinstalleerd"
    } else {
        Write-Host (Get-TranslatedText 'winget_not_found') -ForegroundColor Yellow
        if (-not (Install-Winget)) {
            Write-Host (Get-TranslatedText 'error_occurred' -Parameters @("Winget installatie mislukt")) -ForegroundColor Yellow
            Write-LogMessage "Winget installatie mislukt, script gaat door"
        }
    }

    # Stap 6b: Notepad++ installatie
    Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Cyan
    Write-LogMessage "Start Stap 6b: Notepad++ installatie"
    if (-not (Install-NotepadPlusPlus)) {
        Write-Host (Get-TranslatedText 'error_occurred' -Parameters @("Notepad++ installatie mislukt")) -ForegroundColor Yellow
        Write-LogMessage "Notepad++ installatie mislukt, script gaat door"
    }
    
    # Stap 7: Winget software installatie
    Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
    Install-WingetSoftware

    # Stap 8: Adobe Reader installeren
    Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
    $softwareList = @(
        @{
            Id = "Adobe.Acrobat.Reader.64-bit"
            RegPaths = @(
                "HKLM:\SOFTWARE\Adobe\Acrobat Reader",
                "HKLM:\SOFTWARE\Wow6432Node\Adobe\Acrobat Reader"
            )
        }
    )
    foreach ($software in $softwareList) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Cyan
        Write-LogMessage "Start controle van $($software.Id)"
        
        # Check if already installed through registry or file paths
        $isInstalled = $false
        
        # Check registry paths
        foreach ($regPath in $software.RegPaths) {
            if (Test-Path $regPath) {
                $isInstalled = $true
                break
            }
        }
        
        # Check exe paths if defined
        if (-not $isInstalled -and $software.ExePaths) {
            foreach ($exePath in $software.ExePaths) {
                if (Test-Path $exePath) {
                    $isInstalled = $true
                    break
                }
            }
        }
        
        # Double check with winget if not found in registry/files
        if (-not $isInstalled) {
            $null = winget list --id $software.Id --exact
            $isInstalled = $LASTEXITCODE -eq 0
        }
        
        if ($isInstalled) {
            Write-Host "$($software.Id) is al geinstalleerd en up-to-date" -ForegroundColor Green
            Write-LogMessage "$($software.Id) is up-to-date"
        } else {
            # Install if not present
            Write-Host "$($software.Id) wordt geinstalleerd..." -ForegroundColor Yellow
            
            $retryCount = 0
            $maxRetries = if ($software.RetryCount) { $software.RetryCount } else { 1 }
            $success = $false
            
            while (-not $success -and $retryCount -lt $maxRetries) {
                if ($retryCount -gt 0) {
                    Write-Host "Poging $($retryCount + 1) van $maxRetries..." -ForegroundColor Yellow
                }
                
                if ($software.WingetArgs) {
                    winget install --id $software.Id --exact --silent --accept-source-agreements --accept-package-agreements @($software.WingetArgs)
                } else {
                    winget install --id $software.Id --exact --silent --accept-source-agreements --accept-package-agreements
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                    Write-Host "$($software.Id) succesvol geinstalleerd" -ForegroundColor Green
                    Write-LogMessage "$($software.Id) installatie succesvol"
                } else {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "Installatie mislukt, opnieuw proberen..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    }
                }
            }
            
            if (-not $success) {
                Write-Host "Waarschuwing: $($software.Id) installatie mislukt na $maxRetries pogingen" -ForegroundColor Yellow
                Write-LogMessage "$($software.Id) installatie mislukt na $maxRetries pogingen"
            }
        }
    }

    # Stap 9: Node.js installatie
    if ($SkipNodeJSInstallation) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Write-LogMessage "Node.js installatie overgeslagen door SkipNodeJSInstallation parameter"
    } else {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
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
    }

    # Extra Node.js installatie indien RunNodeJSInstallation is ingesteld
    if ($RunNodeJSInstallation) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Green
        Write-LogMessage "Extra Node.js installatie geforceerd"
        if (-not (Install-NodeJS)) {
            throw "Extra Node.js installatie mislukt"
        }
        
        # Controleer opnieuw na installatie
        if (-not (Test-NodeJS)) {
            throw "Extra Node.js installatie verificatie mislukt"
        }
    }

    # Stap 10: NPM packages installeren
    if ($SkipNpmPackages) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Write-LogMessage "NPM packages installatie overgeslagen door SkipNpmPackages parameter"
    } else {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        if (-not (Install-NpmPackages)) {
            throw "NPM packages installatie mislukt"
        }
    }

    # Extra NPM packages indien RunNpmPackages is ingesteld
    if ($RunNpmPackages) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Green
        Write-LogMessage "Extra NPM packages installatie geforceerd"
        if (-not (Install-NpmPackages)) {
            throw "Extra NPM packages installatie mislukt"
        }
    }

    # Stap 11: Server starten
    if ($SkipNodeServer) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Write-LogMessage "Node.js server starten overgeslagen door SkipNodeServer parameter"
    } else {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        if (-not (Start-NodeServer)) {
            throw "Server starten mislukt"
        }
    }

    # Extra Node.js server start indien RunNodeServer is ingesteld
    if ($RunNodeServer) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Green
        Write-LogMessage "Extra Node.js server start geforceerd"
        if (-not (Start-NodeServer)) {
            throw "Extra server starten mislukt"
        }
    }

    # Stap 12: Index openen
    if ($SkipIndexOpen) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Write-LogMessage "Index openen overgeslagen door SkipIndexOpen parameter"
    } else {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
        Open-IndexFile
    }

    # Extra Index openen indien RunIndexOpen is ingesteld
    if ($RunIndexOpen) {
        Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Green
        Write-LogMessage "Extra Index openen geforceerd"
        Open-IndexFile
    }

    # Stap 13: Energie-instellingen terugzetten
    Write-Host "`n" + (Get-TranslatedText 'step5') -ForegroundColor Yellow
    Restore-DefaultPowerSettings

    Write-Host "`n" + (Get-TranslatedText 'welcome') -ForegroundColor Green
    Write-LogMessage "Script succesvol afgerond"

    # Success notification
    Write-Host "`n" + (Get-TranslatedText 'welcome') -ForegroundColor Green
    Write-LogMessage "Script succesvol afgerond"
    
    # Send success SMS if configured
    Send-TextbeeSMS -Message (Get-TranslatedText 'error_occurred' -Parameters @("PC Setup Script voltooid voor client $global:ClientNumber"))
}
catch {
    Write-Host "`n" + (Get-TranslatedText 'error_occurred' -Parameters @($_.Exception.Message)) -ForegroundColor Red
    Write-Host (Get-TranslatedText 'welcome') -ForegroundColor Yellow
    Write-LogMessage "Script gefaald: $($_.Exception.Message)"
    
    # Send failure SMS if configured
    Send-TextbeeSMS -Message (Get-TranslatedText 'error_occurred' -Parameters @("PC Setup Script MISLUKT voor client $global:ClientNumber. Controleer logs."))
    
    exit 1
}
