# Windows PC Setup Automatisering

Dit script automatiseert de installatie en configuratie van nieuwe Windows PC's in een bedrijfsomgeving. Het script regelt alles van energie-instellingen tot software-installatie, waardoor het installatieproces consistent en efficiënt verloopt.

## Functionaliteiten

- **Taaldetectie en Vertalingen**
  - Automatische detectie van systeemtaal
  - Ondersteuning voor Nederlands en Engels
  - Vertaalde gebruikersberichten

- **SMS Notificaties**
  - Integratie met Textbee API
  - Automatische notificaties bij belangrijke gebeurtenissen
  - Configureerbare ontvanger voor notificaties

- **Energie-instellingen**
  - Optimaliseert energie-instellingen voor desktop gebruik
  - Voorkomt slaapstand tijdens installatie

- **Netwerk Configuratie**
  - Automatische WiFi verbinding
  - Veilige wachtwoordverwerking
  - Netwerkverbinding verificatie

- **Windows Updates**
  - Automatische Windows Updates installatie
  - Voortgangsindicatie
  - Foutafhandeling en herhaalpogingen

- **Software Installatie**
  - Winget pakketbeheer installatie
  - Notepad++ met alternatieve installatiemethoden
  - Belgische eID software
  - Adobe Reader
  - Aanvullende software via Winget

- **Ontwikkelomgeving**
  - Node.js installatie
  - NPM packages configuratie
  - Server instellingen

## Vereisten

- Windows 10 of hoger
- PowerShell 5.1 of hoger
- Administratieve rechten
- Internetverbinding

## Snelle Start


1. Voer het script uit met standaardinstellingen:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1"
   ```

## Gebruiksvoorbeelden

### Basis Gebruik
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1"
```

### Met WiFi Configuratie
```powershell
$wachtwoord = Read-Host -AsSecureString "Voer WiFi wachtwoord in"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1" -WifiSSID "BedrijfsWiFi" -WifiPassword $wachtwoord
```

### Specifieke Stappen Overslaan
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1" -SkipWindowsUpdates -SkipNodeJSInstallation
```

## Parameters

| Parameter | Beschrijving |
|-----------|--------------|
| `-SkipWindowsUpdates` | Sla Windows Updates over |
| `-WifiSSID` | WiFi netwerknaam |
| `-WifiPassword` | WiFi wachtwoord (als SecureString) |
| `-Verbose` | Toon gedetailleerde logging |
| `-DryRun` | Test modus - geen echte wijzigingen |
| `-SkipNodeJSInstallation` | Sla Node.js installatie over |
| `-SkipSMSNotification` | Sla SMS notificaties over |

## Taalondersteuning

Het script detecteert automatisch de systeemtaal en toont berichten in de juiste taal:

- **Nederlands (nl)**: Standaardtaal
- **Engels (en)**: Automatisch gebruikt op Engelstalige systemen

Als de systeemtaal niet wordt ondersteund, valt het script terug op Engels.

## SMS Configuratie

Het script kan SMS notificaties versturen via de Textbee API bij belangrijke gebeurtenissen:

- Installatie gestart
- Installatie voltooid
- Kritieke fouten

De configuratie wordt beheerd in het `sms_config.ps1` bestand:
```powershell
# Textbee API configuratie
$TEXTBEE_DEVICE_ID = "jouw_device_id"
$TEXTBEE_API_KEY = "jouw_api_key"
$TEXTBEE_NOTIFICATION_PHONE = "+32xxxxxxxxx"
```

Om deze functie te gebruiken, moet je:
1. Een Textbee account hebben
2. De juiste API gegevens invullen in het configuratiebestand
3. Het script uitvoeren zonder de `-SkipSMSNotification` parameter

## Logging

Het script maakt gedetailleerde logbestanden aan op:
```
%TEMP%\newpc_setup_[Klantnummer]_[Datum].log
```

## Probleemoplossing

### Veelvoorkomende Problemen

1. **Winget Installatie Mislukt**
   - Script probeert automatisch alternatieve installatiemethoden
   - Controleer Windows App Installer vereisten

2. **Netwerkverbinding Problemen**
   - Verifieer WiFi gegevens
   - Controleer netwerkbeschikbaarheid
   - Script bevat herhaalpogingen

3. **Software Installatie Fouten**
   - Controleer internetverbinding
   - Verifieer of Windows Update service draait
   - Bekijk logbestanden voor specifieke foutmeldingen

## Beveiligingsfuncties

- Veilige wachtwoordverwerking met SecureString
- Opschoning van gevoelige gegevens
- Veilige software download verificatie
- Beschermde logbestanden

## Bijdragen

1. Fork de repository
2. Maak een feature branch
3. Dien een pull request in

## Licentie

[Jouw Licentie Hier]

## Ondersteuning

Voor ondersteuning, [maak een issue aan](https://github.com/VenimK/MusicLover/issues) of neem contact op met je systeembeheerder.

## Wijzigingslog

### Versie 2.1 (2025-03-06)
- Toegevoegd: Automatische taaldetectie (Nederlands/Engels)
- Toegevoegd: Vertaalsysteem voor gebruikersberichten
- Verbeterd: Gebruikerservaring in verschillende talen

### Versie 2.0 (2025-01-17)
- Toegevoegd: veilige wachtwoordverwerking
- Verbeterd: Notepad++ installatie betrouwbaarheid
- Verbeterd: foutafhandeling en logging
- Toegevoegd: meerdere software installatiemethoden

### Versie 1.0
- Eerste uitgave

 2025 TechStick. Alle rechten voorbehouden. Contact: techmusiclover@outlook.be