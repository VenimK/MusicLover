# Test script for language detection functionality
# This script tests the language detection from the newpc.ps1 script

# Import functions from the main script
. "$PSScriptRoot\newpc.ps1" -DryRun

# Clear the screen for better readability
Clear-Host

Write-Host "=== Language Detection Test ===" -ForegroundColor Cyan
Write-Host "Testing language detection functionality..." -ForegroundColor Yellow

# The main script already detected the language and stored it in $script:DetectedLanguage
Write-Host "Detected language code: $script:DetectedLanguage" -ForegroundColor Green

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
