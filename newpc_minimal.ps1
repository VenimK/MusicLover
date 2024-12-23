# Minimal Windows PC Setup Script

# Required Configuration and Logging Functions
$ErrorActionPreference = 'Stop'

# Logging Function
function Write-LogMessage {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $env:TEMP "newpc_minimal_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    try {
        $logMessage = "[$timestamp] $Message"
        Add-Content -Path $logFile -Value $logMessage
        Write-Host $logMessage -ForegroundColor Green
    }
    catch {
        Write-Host "Logging failed: $_" -ForegroundColor Red
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Execution Policy Function (Stap 1)
function Set-ScriptExecutionPolicy {
    try {
        Write-Host "Stap 1: Execution Policy instellen..." -ForegroundColor Yellow
        Write-LogMessage "Start Execution Policy configuratie"
        
        # Set execution policy for current user
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
        
        Write-Host "Execution Policy succesvol ingesteld" -ForegroundColor Green
        Write-LogMessage "Execution Policy succesvol geconfigureerd"
    }
    catch {
        Write-Host "Fout bij instellen Execution Policy: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij Execution Policy configuratie: $_"
        throw
    }
}

# Function to install Winget (Stap 3)
function Install-Winget {
    try {
        Write-Host "Stap 3: Winget installatie controleren..." -ForegroundColor Yellow
        Write-LogMessage "Start Winget installatie controle"
        
        # Check if Winget is already installed
        $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCommand) {
            Write-Host "Winget is al geïnstalleerd" -ForegroundColor Green
            Write-LogMessage "Winget is al geïnstalleerd"
            return $true
        }
        
        # Download and install Winget
        $wingetInstallerUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $installerPath = "$env:TEMP\WingetInstaller.msixbundle"
        
        Write-Host "Downloading Winget..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $wingetInstallerUrl -OutFile $installerPath
        
        Write-Host "Installing Winget..." -ForegroundColor Yellow
        Add-AppxPackage -Path $installerPath -ForceApplicationShutdown
        
        Write-Host "Winget succesvol geïnstalleerd" -ForegroundColor Green
        Write-LogMessage "Winget succesvol geïnstalleerd"
        return $true
    }
    catch {
        Write-Host "Fout bij Winget installatie: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij Winget installatie: $_"
        throw
    }
}

# Function to configure Winget (Stap 3b)
function Set-WingetConfiguration {
    try {
        Write-Host "Stap 3b: Winget configuratie..." -ForegroundColor Yellow
        Write-LogMessage "Start Winget configuratie"
        
        # Accept Microsoft Store agreements
        winget settings --enable LocalManifestFiles
        winget settings --enable MSStore
        winget source reset --force msstore
        
        Write-Host "Winget configuratie succesvol" -ForegroundColor Green
        Write-LogMessage "Winget configuratie succesvol"
    }
    catch {
        Write-Host "Fout bij Winget configuratie: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij Winget configuratie: $_"
        throw
    }
}

# Function to check Node.js installation (Stap 10)
function Test-NodeJS {
    try {
        Write-Host "Stap 10: Node.js installatie controleren..." -ForegroundColor Yellow
        Write-LogMessage "Start Node.js installatie controle"
        
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-Host "Node.js is geïnstalleerd: $nodeVersion" -ForegroundColor Green
            Write-LogMessage "Node.js is geïnstalleerd: $nodeVersion"
            return $true
        }
        
        Write-Host "Node.js niet gevonden. Installatie vereist." -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Host "Fout bij Node.js controle: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij Node.js controle: $_"
        return $false
    }
}

# Function to install Node.js
function Install-NodeJS {
    try {
        Write-Host "Node.js installatie starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Node.js installatie"
        
        # Use Winget to install Node.js LTS
        winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements
        
        # Verify installation
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-Host "Node.js succesvol geïnstalleerd: $nodeVersion" -ForegroundColor Green
            Write-LogMessage "Node.js succesvol geïnstalleerd: $nodeVersion"
            return $true
        }
        
        throw "Node.js installatie verificatie mislukt"
    }
    catch {
        Write-Host "Fout bij Node.js installatie: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij Node.js installatie: $_"
        throw
    }
}

# Function to install NPM packages (Stap 11)
function Install-NpmPackages {
    try {
        Write-Host "Stap 11: NPM packages installeren..." -ForegroundColor Yellow
        Write-LogMessage "Start NPM packages installatie"
        
        # Navigate to the server directory
        Push-Location "h:/TECHSTICK/server"
        
        # Install dependencies from package.json
        npm install
        
        Write-Host "NPM packages succesvol geïnstalleerd" -ForegroundColor Green
        Write-LogMessage "NPM packages succesvol geïnstalleerd"
        
        Pop-Location
        return $true
    }
    catch {
        Write-Host "Fout bij NPM packages installatie: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij NPM packages installatie: $_"
        Pop-Location
        throw
    }
}

# Function to start Node.js server (Stap 12)
function Start-NodeServer {
    try {
        Write-Host "Stap 12: Node.js server starten..." -ForegroundColor Yellow
        Write-LogMessage "Start Node.js server"
        
        # Start the server in a separate process
        $serverProcess = Start-Process node -ArgumentList "server.js" -WorkingDirectory "h:/TECHSTICK/server" -PassThru
        
        Write-Host "Node.js server gestart (Proces ID: $($serverProcess.Id))" -ForegroundColor Green
        Write-LogMessage "Node.js server gestart (Proces ID: $($serverProcess.Id))"
        
        return $true
    }
    catch {
        Write-Host "Fout bij starten Node.js server: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij starten Node.js server: $_"
        throw
    }
}

# Function to open index file (Stap 13)
function Open-IndexFile {
    try {
        Write-Host "Stap 13: Index openen..." -ForegroundColor Yellow
        Write-LogMessage "Start openen index bestand"
        
        # Open index file in default browser
        Start-Process "http://localhost:3000"
        
        Write-Host "Index bestand geopend" -ForegroundColor Green
        Write-LogMessage "Index bestand succesvol geopend"
        return $true
    }
    catch {
        Write-Host "Fout bij openen index bestand: $_" -ForegroundColor Red
        Write-LogMessage "Fout bij openen index bestand: $_"
        throw
    }
}

# Main script execution
try {
    # Check administrator rights
    if (-not (Test-Administrator)) {
        Write-Host "Dit script vereist Administrator rechten." -ForegroundColor Red
        Write-Host "Start PowerShell als Administrator en probeer opnieuw." -ForegroundColor Red
        exit 1
    }

    # Execute specified steps
    Set-ScriptExecutionPolicy
    Install-Winget
    Set-WingetConfiguration
    
    # Node.js related steps
    if (-not (Test-NodeJS)) {
        Install-NodeJS
    }
    Install-NpmPackages
    Start-NodeServer
    Open-IndexFile

    Write-Host "`nScript succesvol voltooid!" -ForegroundColor Green
    Write-LogMessage "Alle stappen succesvol uitgevoerd"
}
catch {
    Write-Host "`nFout opgetreden: $_" -ForegroundColor Red
    Write-LogMessage "Script gefaald: $_"
    exit 1
}
