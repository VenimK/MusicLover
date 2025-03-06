# Standalone test script for language detection functionality

# Clear the screen for better readability
Clear-Host

Write-Host "=== Language Detection Test ===" -ForegroundColor Cyan
Write-Host "Testing language detection functionality..." -ForegroundColor Yellow

# Function to detect system language
function Get-SystemLanguage {
    try {
        # Get system culture/language
        $culture = Get-Culture
        $languageCode = $culture.TwoLetterISOLanguageName.ToLower()
        
        Write-Host "Detected system language: $languageCode" -ForegroundColor Green
        
        # For testing purposes, force English
        $languageCode = 'en'
        Write-Host "TESTING: Forcing language to English" -ForegroundColor Yellow
        
        # Check if we support this language (in this test we support 'nl' and 'en')
        if ($languageCode -eq 'nl' -or $languageCode -eq 'en') {
            return $languageCode
        }
        else {
            # Default to English if not Dutch
            Write-Host "Language not supported, using English as fallback" -ForegroundColor Yellow
            return 'en'
        }
    }
    catch {
        Write-Host "Error detecting language: $($_.Exception.Message)" -ForegroundColor Red
        return 'en' # Default to English on error
    }
}

# Define translations
$translations = @{
    'nl' = @{
        'welcome' = "=== Windows PC Setup Script ==="
        'step1' = "Stap 1: Energiebeheer instellen..."
        'step2' = "Stap 2: Netwerk configureren..."
        'admin_required' = "Dit script vereist Administrator rechten."
        'network_checking' = "Netwerkverbinding controleren..."
        'wu_checking' = "Windows Update PowerShell module controleren..."
        'software_start' = "Winget software installatie starten..."
        'nodejs_checking' = "Node.js installatie controleren..."
    }
    'en' = @{
        'welcome' = "=== Windows PC Setup Script ==="
        'step1' = "Step 1: Setting up power management..."
        'step2' = "Step 2: Configuring network..."
        'admin_required' = "This script requires Administrator privileges."
        'network_checking' = "Checking network connection..."
        'wu_checking' = "Checking Windows Update PowerShell module..."
        'software_start' = "Starting Winget software installation..."
        'nodejs_checking' = "Checking Node.js installation..."
    }
}

# Function to get translated text
function Get-TranslatedText {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Key
    )
    
    # Use the detected system language
    $language = $detectedLanguage
    
    # Check if the key exists in the selected language
    if ($translations.ContainsKey($language) -and $translations[$language].ContainsKey($Key)) {
        return $translations[$language][$Key]
    }
    # Fallback to English if the key doesn't exist in the selected language
    elseif ($translations['en'].ContainsKey($Key)) {
        return $translations['en'][$Key]
    }
    # Last resort fallback
    else {
        return "[$Key]"
    }
}

# Detect system language
$detectedLanguage = Get-SystemLanguage
Write-Host "Detected language code: $detectedLanguage" -ForegroundColor Cyan

# Display system information
$culture = Get-Culture
Write-Host "`nSystem culture information:" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
Write-Host "Culture name: $($culture.Name)"
Write-Host "Display name: $($culture.DisplayName)"
Write-Host "English name: $($culture.EnglishName)"
Write-Host "Two-letter ISO language name: $($culture.TwoLetterISOLanguageName)"

# Display some sample translated messages
Write-Host "`nSample translated messages:" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan

$messages = @(
    'welcome',
    'step1',
    'step2',
    'admin_required',
    'network_checking',
    'wu_checking',
    'software_start',
    'nodejs_checking'
)

foreach ($message in $messages) {
    $translation = Get-TranslatedText $message
    Write-Host "$message : $translation"
}

Write-Host "`nTest completed." -ForegroundColor Green
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
