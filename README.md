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
powershell.exe -ExecutionPolicy Bypass -File newpc_fixed.ps1
```

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

4. **Winget Installatie**
   - Installeert Windows Package Manager (winget)
   - Essentieel voor andere software installaties

5. **Belgische eID Software**
   - Installeert de officiële Belgische eID software
   - Configureert noodzakelijke componenten

6. **MLPACK Software Pakket**
   - Download en installeert het MLPACK software pakket
   - Automatische installatie van essentiële programma's

7. **Index Bestand**
   - Download het index configuratiebestand
   - Opent automatisch in Chrome (geminimaliseerd)

8. **Adobe Reader**
   - Controleert op bestaande Adobe Reader installatie
   - Installeert indien nodig de laatste versie
   - Configureert als standaard PDF viewer

9. **Windows Updates**
   - Controleert op beschikbare Windows updates
   - Downloadt en installeert belangrijke updates
   - Toont voortgang van de installatie

10. **Node.js Installatie**
    - Controleert op bestaande Node.js installatie
    - Installeert de laatste versie indien nodig
    - Verifieert succesvolle installatie

11. **NPM Packages**
    - Installeert benodigde NPM packages
    - Configureert development omgeving

12. **Server Start**
    - Start de Node.js server
    - Configureert voor automatische opstart

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

 2024 TechStick. Alle rechten voorbehouden.
