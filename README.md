# TechStick PC Setup Script

Een PowerShell script voor het automatisch installeren en configureren van nieuwe PC's.

## Functies

- Automatische installatie van essentiële software
- Professionele voortgangsindicator voor alle installaties
- Uitgebreide foutafhandeling en logging
- Automatische configuratie van systeem- en programma-instellingen

## Installatie

1. Download het script:
```powershell
# Clone de repository
git clone [repository-url]
cd TechStick
```

2. Start het script met administrator rechten:
```powershell
# Standaard uitvoering
powershell.exe -ExecutionPolicy Bypass -File newpc_fixed.ps1

# Uitvoering zonder Windows Updates
powershell.exe -ExecutionPolicy Bypass -File newpc_fixed.ps1 -SkipWindowsUpdates
```

## Parameters

| Parameter | Type | Beschrijving |
|-----------|------|--------------|
| `-SkipWindowsUpdates` | Switch | Optionele parameter om de Windows Updates installatie over te slaan. Handig voor test doeleinden of wanneer updates later uitgevoerd moeten worden. |

## Gedetailleerde Stappen

Het script voert de volgende stappen automatisch uit:

1. **Execution Policy Instellen**
   - Configureert PowerShell execution policy voor de huidige gebruiker
   - Stelt in op Bypass voor scriptuitvoering

2. **Energie-instellingen Optimaliseren**
   - Configureert optimale energie-instellingen voor prestaties
   - Past slaapstand en schermtimeouts aan

3. **WiFi Verbinding**
   - Maakt automatisch verbinding met het geconfigureerde WiFi netwerk
   - Gaat door met script bij verbindingsproblemen

3b. **Klantnummer Invoer**
    - Vraagt om klantnummer
    - Optionele invoer
    - Gaat door met script na invoer

4. **Microsoft Office Installatie**
   - Biedt keuze uit verschillende Office versies:
     - Microsoft 365 Business
     - Office 2021
     - Office 2024
     - Geen Office installatie
   - 30 seconden timeout voor automatisch overslaan
   - Gebruikt Office Deployment Tool (ODT) voor installatie

5. **Extra Software Pack**
   - Installeert aanvullende essentiële software
   - Configureert standaard instellingen

6. **Winget Installatie**
   - Verwijdert oude Winget versies indien aanwezig
   - Downloadt en installeert nieuwste Winget versie
   - Accepteert Microsoft Store voorwaarden
   - Verifieert succesvolle installatie

7. **Winget Software Installatie**
   - Installeert essentiële software via Winget:
     - Google Chrome
     - 7-Zip
     - VLC Media Player
     - eID Middleware
     - eID Viewer
   - Controleert op bestaande installaties
   - Update bestaande software indien nodig

8. **Adobe Reader**
   - Controleert op bestaande Adobe Reader installatie
   - Installeert indien nodig de laatste versie
   - Configureert als standaard PDF viewer

9. **Windows Updates**
   - Controleert op beschikbare Windows updates
   - Downloadt en installeert belangrijke updates
   - Toont voortgang van de installatie
   - Gaat door bij updatefouten

10. **Node.js Installatie**
    - Controleert op bestaande Node.js installatie
    - Installeert de laatste versie indien nodig
    - Verifieert succesvolle installatie

11. **NPM Packages**
    - Installeert benodigde NPM packages
    - Configureert development omgeving
    - Verifieert succesvolle installatie

12. **Node.js Server**
    - Start de Node.js server
    - Verifieert server status
    - Configureert voor lokale toegang (http://localhost:3000)

13. **Index Bestand**
    - Opent index_updated.html in Chrome (geminimaliseerd)
    - Vult automatisch in:
      - PC Serienummer (uit BIOS)
      - Klantnummer (indien ingevoerd)
    - Vraagt om aanvullende klantgegevens:
      - Klantnaam
      - Telefoonnummer
      - E-mailadres

14. **Energie-instellingen Terugzetten**
    - Zet alle energie-instellingen terug naar Windows standaardwaarden
    - Activeert het 'Balanced' energieplan
    - Herstelt standaard timeouts voor:
      - Beeldscherm (15 min op netstroom, 5 min op batterij)
      - Slaapstand (30 min op netstroom, 15 min op batterij)
      - Harde schijf (20 min)
    - Schakelt slaapstand weer in
    - Herstelt USB energiebeheer

## Configuratie

### WiFi Instellingen
Voor het configureren van de WiFi-verbinding zijn er drie opties:

1. **Configuratiebestand gebruiken (aanbevolen voor herhaald gebruik):**
   - Kopieer `config.template.ps1` naar `config.ps1`
   - Bewerk `config.ps1` met je WiFi-gegevens:
   ```powershell
   $Global:WifiConfig = @{
       SSID = "JouwWiFiNetwerk"
       Password = "JouwWiFiWachtwoord"
   }
   ```
   - `config.ps1` wordt automatisch genegeerd door Git voor veiligheid

2. **Parameters gebruiken (voor eenmalig gebruik):**
   ```powershell
   .\newpc_fixed.ps1 -WifiSSID "JouwWiFiNetwerk" -WifiPassword "JouwWiFiWachtwoord"
   ```

3. **Interactieve invoer:**
   - Start het script zonder parameters
   - Voer de WiFi-gegevens in wanneer daarom wordt gevraagd

**Veiligheidsnotities:**
- Deel NOOIT je `config.ps1` bestand met anderen
- Voeg het NOOIT toe aan version control
- Het bestand staat in `.gitignore` en wordt niet meegestuurd bij commits
- Gebruik bij voorkeur een apart netwerk voor setup doeleinden

### Email Instellingen
Voor het verzenden van emails heeft de server een `config.js` bestand nodig met de juiste credentials:

1. Maak een `config.js` bestand aan in de root directory
2. Voeg de volgende code toe:
```javascript
module.exports = {
    email: {
        user: 'jouw-email@gmail.com',
        pass: 'jouw-app-wachtwoord'
    }
};
```
3. Vervang de credentials met je eigen Gmail gegevens
4. Het bestand wordt automatisch genegeerd door Git voor veiligheid

**Let op:** 
- Gebruik nooit je gewone Gmail wachtwoord
- Maak een App-specifiek wachtwoord aan in je Google Account instellingen
- Deel het `config.js` bestand nooit met anderen
- Het bestand staat in `.gitignore` en wordt niet meegestuurd bij commits

## Logging

Het script houdt een gedetailleerd logbestand bij in:
```
%TEMP%\newpc_setup.log
```

Alle acties, waarschuwingen en fouten worden hier geregistreerd voor troubleshooting.

## Foutafhandeling

- Controleert elke stap op succesvolle uitvoering
- Gaat door met volgende stappen bij niet-kritieke fouten
- Geeft duidelijke foutmeldingen en logging
- Biedt troubleshooting informatie bij problemen

## Beveiliging

- Controleert op administrator rechten
- Gebruikt veilige download bronnen
- Verifieert software installaties
- Ruimt tijdelijke bestanden op

## Systeemvereisten

- Windows 10/11
- PowerShell 5.1 of hoger
- Internetverbinding
- Administrator rechten

## Licentie

2024 TechStick. Alle rechten voorbehouden. Contact: @ techmusiclover@outlook.be