# TechStick PC Setup Script

Een PowerShell script voor het automatisch installeren en configureren van nieuwe PC's.

## Functies

- Automatische installatie van essentiële software:
  - Adobe Reader DC
  - MLPACK software pakket
  - Windows Updates
  - Node.js en NPM pakketten
- Professionele voortgangsindicator voor alle installaties
- Automatische configuratie van standaard programma's
- Foutafhandeling en logging van alle acties

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

## Functionaliteiten

Het script voert de volgende taken automatisch uit:

1. **Systeem Voorbereiding**
   - Controleert administrator rechten
   - Initialiseert logging

2. **Software Installaties**
   - Adobe Reader DC (met controle op bestaande installatie)
   - MLPACK software pakket
   - Windows Updates
   - Node.js en benodigde NPM pakketten

3. **Configuratie**
   - Instellen van Adobe Reader als standaard PDF viewer
   - Automatisch openen van index bestand in Chrome (geminimaliseerd)
   - Server configuratie en opstarten

## Logging

Het script houdt een gedetailleerd logbestand bij van alle uitgevoerde acties en eventuele fouten.

## Beveiliging

- Controleert op administrator rechten
- Veilige downloads van officiële bronnen
- Cleanup van tijdelijke bestanden

## Licentie

 2024 TechStick. Alle rechten voorbehouden.
