# Windows PC Setup Script

Een PowerShell script voor het automatisch installeren en configureren van nieuwe PC's.

## Beschrijving

Dit PowerShell-script is ontworpen om een nieuwe Windows-computer snel en geautomatiseerd in te stellen met de volgende functies:
- Netwerk verbinding configureren
- Systeeminstellingen optimaliseren
- Software installeren
- Windows updates beheren

## Gebruik van het Script

### Scriptparameters

Het script ondersteunt verschillende opdrachtregelparameters om het gedrag aan te passen:

```powershell
.\newpc_fixed.ps1 [Opties]
```

#### Beschikbare Opties:
- `-WifiSSID`: Specificeer WiFi-netwerknaam
- `-WifiWachtwoord`: Verstrek WiFi-wachtwoord
- `-WindowsUpdatesOverslaan`: Sla Windows Update proces over
- `-Uitgebreid`: Schakel gedetailleerde logging en uitgebreide uitvoer in
- `-DroogDraaien`: Voer script uit in simulatiemodus (geen wijzigingen)

### Voorbeelden van Gebruik

```powershell
# Standaard uitvoering
.\newpc_fixed.ps1

# WiFi-credentials verstrekken
.\newpc_fixed.ps1 -WifiSSID "MijnNetwerk" -WifiWachtwoord "VeiligWachtwoord"

# Windows Updates overslaan
.\newpc_fixed.ps1 -WindowsUpdatesOverslaan

# Uitgebreide logging voor probleemoplossing
.\newpc_fixed.ps1 -Uitgebreid

# Droog draaien (simulatiemodus)
.\newpc_fixed.ps1 -DroogDraaien
```

### Netwerkverbinding

#### Verbeterde Verbindingsdetectie
- Gebruikt parallelle tests van meerdere DNS-servers
- Ondersteunt LAN- en WiFi-verbindingen
- Snellere en betrouwbaardere netwerkdetectie
- Controleert Google, Cloudflare en Quad9 DNS-servers

#### Verbindingsprioriteiten
1. Controleer op actieve LAN-verbinding
2. Test internetconnectiviteit via meerdere DNS-servers
3. Probeer WiFi-verbinding indien geen netwerk gevonden
4. Vraag om WiFi-credentials indien nodig

### Logging en Foutopsporing

#### Log Niveaus
- Standaard uitvoer
- Uitgebreide modus voor gedetailleerde logging
- Kleur-gecodeerde console-berichten
- Permanente logbestanden voor het volgen van scriptuitvoering

#### Foutafhandeling
- Uitgebreide fout-logging
- Gedetailleerde foutmeldingen
- Voorkomt scriptuitvoering bij ontbrekende afhankelijkheden

### Systeemvereisten

#### Minimale Vereisten
- PowerShell 5.1 of hoger
- Windows 10 of Windows 11
- Beheerdersbevoegdheden

#### Vereiste Hulpmiddelen
- Winget
- NetSh
- Optioneel: PSWindowsUpdate module

### Probleemoplossing

- Gebruik de `-Uitgebreid` vlag voor gedetailleerde diagnostiek
- Controleer logbestanden voor specifieke foutinformatie
- Zorg ervoor dat alle afhankelijkheden zijn geïnstalleerd
- Voer het script uit met beheerdersbevoegdheden

## Installatie-instructies

1. Zorg dat PowerShell is ingesteld op het uitvoeren van scripts
2. Download het script
3. Open PowerShell als beheerder
4. Navigeer naar de scriptlocatie
5. Voer het script uit met de gewenste opties

## Disclaimer

Dit script wordt geleverd "zoals het is" zonder enige garantie. Gebruik het script op eigen risico en maak altijd een back-up van uw systeem voordat u grote wijzigingen aanbrengt.

## Parameters

| Parameter | Type | Beschrijving |
|-----------|------|--------------|
| `-WindowsUpdatesOverslaan` | Switch | Optionele parameter om de Windows Updates installatie over te slaan. Handig voor test doeleinden of wanneer updates later uitgevoerd moeten worden. |

## Gedetailleerde Stappen

Het script voert de volgende stappen automatisch uit:

1. **Execution Policy Instellen**
   - Configureert PowerShell execution policy voor de huidige gebruiker
   - Stelt in op Bypass voor scriptuitvoering

2. **Energie-instellingen Optimaliseren**
   - Configureert optimale energie-instellingen voor prestaties
   - Past slaapstand en schermtimeouts aan

3. **Netwerk Verbinding**
   - Controleert eerst op actieve LAN verbinding
   - Als LAN beschikbaar is, wordt deze gebruikt
   - Alleen als er geen LAN verbinding is:
     - Maakt automatisch verbinding met WiFi netwerk
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

## Python Script Usage Instructions

### Prerequisites

- Python 3.8+
- Windows 10/11
- Administrator privileges

### Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

### Usage

Run the script with various options:

```bash
python newpc_setup.py [options]
```

### Options

- `--skip-updates`: Skip Windows updates
- `--wifi-ssid SSID`: Specify WiFi network name
- `--wifi-password PASSWORD`: Specify WiFi network password
- `--verbose`: Enable detailed logging
- `--dry-run`: Perform a dry run without making changes

### Examples

```bash
# Basic usage
python newpc_setup.py

# Connect to WiFi and skip updates
python newpc_setup.py --wifi-ssid MyNetwork --wifi-password MyPassword --skip-updates

# Verbose mode
python newpc_setup.py --verbose
```

### Logging

Logs are saved to `setup_log.txt` in the script directory.