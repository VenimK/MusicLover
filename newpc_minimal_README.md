# Minimal Windows PC Setup Script

## Overzicht

Dit script automatiseert de volgende stappen voor PC setup:

1. **Stap 1**: Execution Policy instellen
2. **Stap 3**: Winget installatie
3. **Stap 3b**: Winget configuratie
4. **Stap 10**: Node.js installatie controleren
5. **Stap 11**: NPM packages installeren
6. **Stap 12**: Node.js server starten
7. **Stap 13**: Index bestand openen

## Vereisten

- Windows 10/11
- PowerShell 5.1 of hoger
- Administrator rechten
- Stabiele internetverbinding

## Gebruik

```powershell
# Script uitvoeren
.\newpc_minimal.ps1
```

## Functies

### Logging
- Gedetailleerde logging naar tijdelijk logbestand
- Console-uitvoer met kleurcodering
- Foutafhandeling met gedetailleerde berichten

### Stap Details

#### Stap 1: Execution Policy
- Stelt ExecutionPolicy in voor huidige gebruiker
- Bypass-modus voor script-uitvoering

#### Stap 3: Winget Installatie
- Controleert of Winget geïnstalleerd is
- Downloadt en installeert indien nodig

#### Stap 3b: Winget Configuratie
- Accepteert Microsoft Store overeenkomsten
- Configureert Winget-instellingen

#### Stap 10: Node.js Installatie
- Controleert bestaande Node.js installatie
- Installeert Node.js LTS via Winget indien nodig

#### Stap 11: NPM Packages
- Installeert NPM packages uit package.json
- Werkt in de server directory

#### Stap 12: Node.js Server
- Start de Node.js server
- Toont proces-ID voor verificatie

#### Stap 13: Index Openen
- Opent index bestand in standaard browser
- Controleert server beschikbaarheid

## Foutafhandeling

- Stopt bij kritieke fouten
- Gedetailleerde foutmeldingen
- Logging van alle stappen en fouten

## Veiligheid

- Vereist Administrator rechten
- Veilige installatiemethoden
- Minimale systeemwijzigingen

## Troubleshooting

- Controleer internetverbinding
- Zorg voor Administrator rechten
- Raadpleeg logbestanden bij problemen

## Licentie

© 2024 TechStick. Alle rechten voorbehouden.

## Contact

E-mail: techmusiclover@outlook.be
