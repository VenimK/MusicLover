# WiFi Configuration Template
# Rename this file to 'config.ps1' and update the values with your actual credentials
# DO NOT commit the actual config.ps1 file to version control!

$Global:WifiConfig = @{
    SSID = "YourWiFiNetworkName"        # Change this to your WiFi SSID
    Password = "YourWiFiPassword"        # Change this to your WiFi password
}

# Example:
# $Global:WifiConfig = @{
#     SSID = "Office_Network"
#     Password = "SecurePass123"
# }
