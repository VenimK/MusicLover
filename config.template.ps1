# WiFi Configuratie Sjabloon
# Hernoem dit bestand naar 'config.ps1' en werk de waarden bij met uw eigen gegevens
# NIET het echte config.ps1 bestand committen naar versiebeheer!

$Global:WifiConfig = @{
    SSID = "JouwWiFiNetwerknaam"        # Vervang dit door je WiFi netwerknaam
    Password = "JouwWiFiWachtwoord"      # Vervang dit door je WiFi wachtwoord
}

# Voorbeeld:
# $Global:WifiConfig = @{
#     SSID = "Kantoor_Netwerk"
#     Password = "VeiligWachtwoord123"
# }
