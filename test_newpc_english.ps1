# Test script to run newpc.ps1 with English language
# This script temporarily modifies the system language detection in newpc.ps1 to test English language

# Path to the original script
$originalScript = Join-Path $PSScriptRoot "newpc.ps1"

# Read the content of the original script
$scriptContent = Get-Content -Path $originalScript -Raw

# Create a modified version that forces English language
$modifiedContent = $scriptContent -replace 'function Get-SystemLanguage \{(?:.|\n)+?\}', @'
function Get-SystemLanguage {
    try {
        # Get system culture/language
        $culture = Get-Culture
        $languageCode = $culture.TwoLetterISOLanguageName.ToLower()
        
        Write-Host "Actual system language detected: $languageCode" -ForegroundColor Cyan
        
        # Force English for testing
        $languageCode = 'en'
        Write-Host "TESTING: Forcing language to English" -ForegroundColor Yellow
        
        return $languageCode
    }
    catch {
        Write-Host "Error detecting language: $($_.Exception.Message)" -ForegroundColor Red
        return 'en' # Default to English on error
    }
}
'@

# Create a temporary script file
$tempScriptPath = Join-Path $env:TEMP "newpc_english_test.ps1"
$modifiedContent | Set-Content -Path $tempScriptPath -Force

# Inform the user
Write-Host "Created temporary script with English language at: $tempScriptPath" -ForegroundColor Green
Write-Host "Running script with -DryRun parameter to prevent actual changes..." -ForegroundColor Yellow

# Run the script with DryRun parameter to prevent actual changes
& $tempScriptPath -DryRun

# Clean up
Write-Host "`nTest completed. Removing temporary script..." -ForegroundColor Green
Remove-Item -Path $tempScriptPath -Force
