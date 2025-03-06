# Simplified test script for newpc.ps1 with English language
# This script tests the language detection and translation functionality

[CmdletBinding()]
param(
    [switch]$DryRun = $true  # Force dry run mode to prevent actual changes
)

# Create log file
$logFile = Join-Path $env:TEMP "NewPC_Setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
New-Item -ItemType File -Path $logFile -Force | Out-Null

# Enhanced logging function
function Write-LogMessage {
    param(
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # File logging
    Add-Content -Path $logFile -Value $logMessage
}

# Function to detect system language - FORCED TO ENGLISH FOR TESTING
function Get-SystemLanguage {
    try {
        # Get system culture/language
        $culture = Get-Culture
        $languageCode = $culture.TwoLetterISOLanguageName.ToLower()
        
        Write-Host "Actual system language detected: $languageCode" -ForegroundColor Cyan
        Write-LogMessage "Actual system language detected: $languageCode"
        
        # Force English for testing
        $languageCode = 'en'
        Write-Host "TESTING: Forcing language to English" -ForegroundColor Yellow
        Write-LogMessage "TESTING: Forcing language to English"
        
        return $languageCode
    }
    catch {
        Write-Host "Error detecting language: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Error detecting language: $($_.Exception.Message)"
        return 'en' # Default to English on error
    }
}

# Function to get translated text
function Get-TranslatedText {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Key,
        
        [Parameter(Mandatory=$false)]
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
        'step3' = "Stap 3: Windows Updates installeren..."
        'step4' = "Stap 4: Winget installeren..."
        'step5' = "Stap 5: Software installeren..."
        'step6' = "Stap 6: Node.js omgeving opzetten..."
        'step7' = "Stap 7: Node.js server starten..."
        'step8' = "Stap 8: Index bestand openen..."
        'step9' = "Stap 9: Opruimen..."
        'completed' = "Setup succesvol afgerond!"
        'error_occurred' = "Er is een fout opgetreden: {0}"
        'check_log' = "Controleer het logbestand voor details: {0}"
        'press_any_key' = "Druk op een toets om af te sluiten..."
        'admin_required' = "Dit script vereist Administrator rechten."
        'restart_as_admin' = "Start PowerShell als Administrator en probeer opnieuw."
        'admin_restart_failed' = "Kon script niet opnieuw starten met Administrator rechten."
        'ps_version_error' = "Fout: PowerShell versie {0} is niet ondersteund."
        'ps_min_version' = "Minimaal vereiste versie: {0}"
        'enter_client_number' = "Voer het klantnummer in:"
        'nodejs_checking' = "Node.js installatie controleren..."
        'nodejs_installed' = "Node.js is geïnstalleerd (versie: {0})."
        'winget_installed' = "Winget is reeds geïnstalleerd, doorgaan naar volgende stap..."
        'winget_not_found' = "Winget niet gevonden, installatie starten..."
        
        # Network messages
        'network_checking' = "Netwerkverbinding controleren..."
        'network_connected' = "Netwerkverbinding OK."
        'network_not_connected' = "Geen netwerkverbinding gedetecteerd."
        'wifi_setup' = "WiFi verbinding opzetten..."
        'wifi_connected' = "WiFi verbinding succesvol."
        'wifi_failed' = "WiFi verbinding mislukt: {0}"
        'enter_wifi_ssid' = "Voer WiFi netwerknaam (SSID) in:"
        'enter_wifi_password' = "Voer WiFi wachtwoord in:"
        
        # Windows Update messages
        'wu_checking' = "Windows Update PowerShell module controleren..."
        'wu_installing_module' = "Windows Update PowerShell module installeren..."
        'wu_module_installed' = "Windows Update PowerShell module geïnstalleerd."
        'wu_module_failed' = "Windows Update PowerShell module installatie mislukt: {0}"
        'wu_module_failed_general' = "Kon Windows Update PowerShell module niet installeren."
        'wu_start' = "Windows Updates installeren..."
        'wu_searching' = "Zoeken naar updates..."
        'wu_found' = "{0} updates gevonden."
        'wu_no_updates' = "Geen updates gevonden."
        'wu_installing' = "Updates worden geïnstalleerd..."
        'wu_optional' = "Optionele updates worden geïnstalleerd..."
        'wu_complete' = "Windows Updates installatie voltooid."
        'wu_error' = "Fout bij Windows Updates: {0}"
        
        # Software installation messages
        'software_start' = "Winget software installatie starten..."
        'software_checking' = "Controleren {0}..."
        'software_installing' = "{0} wordt geïnstalleerd..."
        'software_installed' = "{0} is al geïnstalleerd."
        'software_complete' = "Alle software installaties voltooid"
        'software_failed' = "Software installatie mislukt: {0}"
        
        # General messages
        'preparing' = "Voorbereiden..."
        'test_message' = "Dit is een test bericht in het Nederlands."
    }
    'en' = @{
        'welcome' = "=== Windows PC Setup Script ==="
        'step1' = "Step 1: Setting up power management..."
        'step2' = "Step 2: Configuring network..."
        'step3' = "Step 3: Installing Windows Updates..."
        'step4' = "Step 4: Installing Winget..."
        'step5' = "Step 5: Installing software..."
        'step6' = "Step 6: Setting up Node.js environment..."
        'step7' = "Step 7: Starting Node.js server..."
        'step8' = "Step 8: Opening index file..."
        'step9' = "Step 9: Cleaning up..."
        'completed' = "Setup completed successfully!"
        'error_occurred' = "An error occurred: {0}"
        'check_log' = "Check the log file for details: {0}"
        'press_any_key' = "Press any key to exit..."
        'admin_required' = "This script requires Administrator privileges."
        'restart_as_admin' = "Start PowerShell as Administrator and try again."
        'admin_restart_failed' = "Could not restart script with Administrator privileges."
        'ps_version_error' = "Error: PowerShell version {0} is not supported."
        'ps_min_version' = "Minimum required version: {0}"
        'enter_client_number' = "Enter the client number:"
        'nodejs_checking' = "Checking Node.js installation..."
        'nodejs_installed' = "Node.js is installed (version: {0})."
        'winget_installed' = "Winget is already installed, proceeding to next step..."
        'winget_not_found' = "Winget not found, starting installation..."
        
        # Network messages
        'network_checking' = "Checking network connection..."
        'network_connected' = "Network connection OK."
        'network_not_connected' = "No network connection detected."
        'wifi_setup' = "Setting up WiFi connection..."
        'wifi_connected' = "WiFi connection successful."
        'wifi_failed' = "WiFi connection failed: {0}"
        'enter_wifi_ssid' = "Enter WiFi network name (SSID):"
        'enter_wifi_password' = "Enter WiFi password:"
        
        # Windows Update messages
        'wu_checking' = "Checking Windows Update PowerShell module..."
        'wu_installing_module' = "Installing Windows Update PowerShell module..."
        'wu_module_installed' = "Windows Update PowerShell module installed."
        'wu_module_failed' = "Windows Update PowerShell module installation failed: {0}"
        'wu_module_failed_general' = "Could not install Windows Update PowerShell module."
        'wu_start' = "Installing Windows Updates..."
        'wu_searching' = "Searching for updates..."
        'wu_found' = "Found {0} updates."
        'wu_no_updates' = "No updates found."
        'wu_installing' = "Installing updates..."
        'wu_optional' = "Installing optional updates..."
        'wu_complete' = "Windows Updates installation complete."
        'wu_error' = "Error with Windows Updates: {0}"
        
        # Software installation messages
        'software_start' = "Starting Winget software installation..."
        'software_checking' = "Checking {0}..."
        'software_installing' = "Installing {0}..."
        'software_installed' = "{0} is already installed."
        'software_complete' = "All software installations completed"
        'software_failed' = "Software installation failed: {0}"
        
        # General messages
        'preparing' = "Preparing..."
        'test_message' = "This is a test message in English."
    }
}

# Main script execution
try {
    Clear-Host
    Write-Host "=== Testing newpc.ps1 with English Language ===" -ForegroundColor Cyan
    
    # Detect system language (forced to English)
    $script:DetectedLanguage = Get-SystemLanguage
    
    Write-Host "`nSystem Information:" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    $culture = Get-Culture
    Write-Host "Culture name: $($culture.Name)"
    Write-Host "Display name: $($culture.DisplayName)"
    Write-Host "English name: $($culture.EnglishName)"
    Write-Host "Two-letter ISO language name: $($culture.TwoLetterISOLanguageName)"
    Write-Host "Selected language for script: $script:DetectedLanguage"
    
    Write-Host "`nTesting translations:" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    Write-Host (Get-TranslatedText 'welcome') -ForegroundColor Green
    
    # Test all steps
    for ($i = 1; $i -le 9; $i++) {
        Write-Host (Get-TranslatedText "step$i") -ForegroundColor Yellow
    }
    
    # Test parameter formatting
    $errorMessage = "Test error message"
    Write-Host (Get-TranslatedText 'error_occurred' -Parameters @($errorMessage)) -ForegroundColor Red
    
    # Test network messages
    Write-Host "`nNetwork messages:" -ForegroundColor Cyan
    Write-Host (Get-TranslatedText 'network_checking') -ForegroundColor Yellow
    Write-Host (Get-TranslatedText 'network_connected') -ForegroundColor Green
    Write-Host (Get-TranslatedText 'wifi_setup') -ForegroundColor Yellow
    
    # Test Windows Update messages
    Write-Host "`nWindows Update messages:" -ForegroundColor Cyan
    Write-Host (Get-TranslatedText 'wu_checking') -ForegroundColor Yellow
    Write-Host (Get-TranslatedText 'wu_installing_module') -ForegroundColor Yellow
    Write-Host (Get-TranslatedText 'wu_found' -Parameters @(5)) -ForegroundColor Cyan
    
    # Test software installation messages
    Write-Host "`nSoftware installation messages:" -ForegroundColor Cyan
    Write-Host (Get-TranslatedText 'software_start') -ForegroundColor Yellow
    Write-Host (Get-TranslatedText 'software_installing' -Parameters @("Notepad++")) -ForegroundColor Yellow
    Write-Host (Get-TranslatedText 'software_complete') -ForegroundColor Green
    
    # Test specific message
    Write-Host "`n" + (Get-TranslatedText 'test_message') -ForegroundColor Magenta
    
    # Show log file location
    Write-Host "`nLog file: $logFile" -ForegroundColor Cyan
    
    Write-Host "`nTest completed successfully!" -ForegroundColor Green
    Write-Host (Get-TranslatedText 'press_any_key')
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Host "`n" + (Get-TranslatedText 'error_occurred' -Parameters @($_.Exception.Message)) -ForegroundColor Red
    Write-Host (Get-TranslatedText 'check_log' -Parameters @($logFile)) -ForegroundColor Yellow
    Write-LogMessage "Script failed: $($_.Exception.Message)"
    
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
