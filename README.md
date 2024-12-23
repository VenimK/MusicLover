# Windows PC Setup Script

Een geautomatiseerd PowerShell script voor het installeren en configureren van nieuwe Windows PC's.

## Features

### Automatische Installaties
1. **Microsoft Office**
   - Microsoft 365 Business
   - Office 2021
   - Office 2024
   - Interactieve keuze met 30 seconden timeout

2. **Standaard Software via Winget**
   - Google Chrome
   - 7-Zip
   - VLC Media Player
   - Belgische eID software
   - eID Viewer
   - Notepad++
   - Adobe Reader DC

3. **Ontwikkeltools**
   - Node.js (LTS versie)
   - NPM packages

### Systeem Configuratie
1. **Netwerk Setup**
   - Automatische WiFi configuratie
   - Netwerk connectiviteit check
   - Firewall regels voor Node.js server

2. **Windows Updates**
   - Installatie van reguliere updates
   - Optionele updates
   - Mogelijkheid om updates over te slaan met `-SkipWindowsUpdates`

3. **Energie-instellingen**
   - Optimalisatie tijdens installatie
   - Automatisch herstel naar standaard instellingen na afloop

### Monitoring & Notificaties
1. **SMS Notificaties via Textbee API**
   - Installatie status updates
   - Foutmeldingen
   - Configureerbaar via `sms_config.ps1`

2. **Uitgebreide Logging**
   - Gedetailleerde logbestanden
   - Voortgangsindicatoren
   - Foutrapportage

## Configuratie

### WiFi Configuratie (config.ps1)
Maak een `config.ps1` bestand aan voor WiFi instellingen:
```powershell
# WiFi Configuration
$Global:WifiConfig = @{
    SSID = "JouwWiFiNetwerk"
    Password = "JouwWiFiWachtwoord"
}
```

Voor het configureren van de WiFi-verbinding zijn er drie opties:

1. **Configuratiebestand gebruiken (aanbevolen voor herhaald gebruik):**
   - Kopieer `config.template.ps1` naar `config.ps1`
   - Bewerk `config.ps1` met je WiFi-gegevens
   - `config.ps1` wordt automatisch genegeerd door Git voor veiligheid

2. **Parameters gebruiken (voor eenmalig gebruik):**
   ```powershell
   .\newpc_fixed.ps1 -WifiSSID "JouwWiFiNetwerk" -WifiPassword "JouwWiFiWachtwoord"
   ```

3. **Interactieve invoer:**
   - Start het script zonder parameters
   - Voer de WiFi-gegevens in wanneer daarom wordt gevraagd

### Email Configuratie (config.js)
Voor het verzenden van emails heeft de server een `config.js` bestand nodig:

```javascript
module.exports = {
    email: {
        user: 'jouw-email@gmail.com',
        pass: 'jouw-app-wachtwoord',    // Gebruik een app-specifiek wachtwoord
        host: 'smtp.gmail.com',
        port: 587,
        secure: false
    },
    server: {
        port: 3000
    }
};
```

**Belangrijke Notities voor Email Configuratie:**
- Gebruik NOOIT je gewone Gmail wachtwoord
- Maak een App-specifiek wachtwoord aan in je Google Account instellingen
- Het bestand staat in `.gitignore` en wordt niet meegestuurd bij commits

### SMS Configuratie (sms_config.ps1)
Maak een `sms_config.ps1` bestand aan met de volgende inhoud:
```powershell
# Textbee API Configuration
$TEXTBEE_DEVICE_ID = "your_device_id"
$TEXTBEE_API_KEY = "your_api_key"
$TEXTBEE_NOTIFICATION_PHONE = "your_phone_number"
```

### Script Parameters

#### Basis Parameters
- `-SkipWindowsUpdates`: Slaat Windows Updates over
- `-WifiSSID`: WiFi netwerk naam
- `-WifiPassword`: WiFi wachtwoord
- `-Verbose`: Toont extra debug informatie
- `-DryRun`: Simuleert uitvoering zonder wijzigingen

#### Nieuwe Uitvoeringsparameters
- `-RunNodeJSInstallation`: Forceert Node.js installatie
- `-RunNpmPackages`: Forceert NPM packages installatie
- `-RunNodeServer`: Forceert Node.js server start
- `-RunIndexOpen`: Forceert openen van index bestand

#### Voorbeelden van Geavanceerd Gebruik
```powershell
# Alleen Node.js installeren
.\newpc_fixed.ps1 -RunNodeJSInstallation

# Node.js installeren, NPM packages, server starten en index openen
.\newpc_fixed.ps1 -RunNodeJSInstallation -RunNpmPackages -RunNodeServer -RunIndexOpen

# Combinatie met andere parameters
.\newpc_fixed.ps1 -WifiSSID "NetworkName" -RunNodeServer
```

**Opmerking:** 
- De `-Run*` parameters worden NAAST de normale scriptuitvoering uitgevoerd
- Ze dwingen de uitvoering van specifieke stappen af, zelfs als deze al eerder zijn uitgevoerd
- Ideaal voor herhaalde of geforceerde installaties

## Beveiliging van Configuratiebestanden

### Veiligheidsmaatregelen
1. **Git Beveiliging**
   - Alle configuratiebestanden (`config.ps1`, `config.js`, `sms_config.ps1`) staan in `.gitignore`
   - Voorkomt per ongeluk delen van gevoelige informatie
   - Template bestanden worden wel meegeleverd

2. **Wachtwoordbeveiliging**
   - Gebruik app-specifieke wachtwoorden voor Gmail
   - WiFi wachtwoorden alleen lokaal opgeslagen
   - API keys veilig opgeslagen in configuratiebestanden

3. **Fallback Mechanismen**
   - Automatische fallback naar omgevingsvariabelen als configuratiebestanden ontbreken
   - Interactieve modus als backup voor ontbrekende instellingen

## Gebruik

1. Start PowerShell als Administrator
2. Navigeer naar de script directory
3. Voer het script uit:
```powershell
.\newpc_fixed.ps1
```

Met parameters:
```powershell
.\newpc_fixed.ps1 -WifiSSID "NetworkName" -WifiPassword "NetworkPassword"
```

## Vereisten

- Windows 10/11
- PowerShell 5.1 of hoger
- Administrator rechten
- Internet verbinding

## Veiligheid

- Gevoelige informatie wordt opgeslagen in configuratiebestanden (uitgesloten van git)
- Automatische fallback naar omgevingsvariabelen
- Veilige opslag van credentials

## Foutafhandeling

- Uitgebreide logging van fouten
- SMS notificaties bij problemen
- Automatische hervatting waar mogelijk
- Duidelijke foutmeldingen in console

## Server Functionaliteit

- Automatische Node.js server setup
- Poort 3000 configuratie
- Firewall regels worden automatisch aangemaakt
- Server start automatisch na installatie


 2024 TechStick. Alle rechten voorbehouden. Contact: @ techmusiclover@outlook.be