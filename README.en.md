# Windows PC Setup Automation

This script automates the installation and configuration of new Windows PCs in a business environment. The script handles everything from power settings to software installation, making the installation process consistent and efficient.

## Features

- **Language Detection and Translations**
  - Automatic detection of system language
  - Support for Dutch and English
  - Translated user messages

- **SMS Notifications**
  - Integration with Textbee API
  - Automatic notifications for important events
  - Configurable notification recipient

- **Power Settings**
  - Optimizes power settings for desktop use
  - Prevents sleep mode during installation

- **Network Configuration**
  - Automatic WiFi connection
  - Secure password handling
  - Network connection verification

- **Windows Updates**
  - Automatic Windows Updates installation
  - Progress indication
  - Error handling and retry attempts

- **Software Installation**
  - Winget package manager installation
  - Notepad++ with alternative installation methods
  - Belgian eID software
  - Adobe Reader
  - Additional software via Winget

- **Development Environment**
  - Node.js installation
  - NPM packages configuration
  - Server settings

## Requirements

- Windows 10 or higher
- PowerShell 5.1 or higher
- Administrative rights
- Internet connection

## Quick Start

1. Run the script with default settings:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1"
   ```

## Usage Examples

### Basic Usage
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1"
```

### With WiFi Configuration
```powershell
$password = Read-Host -AsSecureString "Enter WiFi password"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1" -WifiSSID "CompanyWiFi" -WifiPassword $password
```

### Skip Specific Steps
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\newpc.ps1" -SkipWindowsUpdates -SkipNodeJSInstallation
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-SkipWindowsUpdates` | Skip Windows Updates |
| `-WifiSSID` | WiFi network name |
| `-WifiPassword` | WiFi password (as SecureString) |
| `-Verbose` | Show detailed logging |
| `-DryRun` | Test mode - no actual changes |
| `-SkipNodeJSInstallation` | Skip Node.js installation |
| `-SkipSMSNotification` | Skip SMS notifications |

## Language Support

The script automatically detects the system language and displays messages in the appropriate language:

- **Dutch (nl)**: Default language
- **English (en)**: Automatically used on English systems

If the system language is not supported, the script falls back to English.

## SMS Configuration

The script can send SMS notifications via the Textbee API for important events:

- Installation started
- Installation completed
- Critical errors

The configuration is managed in the `sms_config.ps1` file:
```powershell
# Textbee API configuration
$TEXTBEE_DEVICE_ID = "your_device_id"
$TEXTBEE_API_KEY = "your_api_key"
$TEXTBEE_NOTIFICATION_PHONE = "+32xxxxxxxxx"
```

To use this feature, you must:
1. Have a Textbee account
2. Fill in the correct API details in the configuration file
3. Run the script without the `-SkipSMSNotification` parameter

## Logging

The script creates detailed log files at:
```
%TEMP%\newpc_setup_[ClientNumber]_[Date].log
```

## Troubleshooting

### Common Issues

1. **Winget Installation Fails**
   - Script automatically tries alternative installation methods
   - Check Windows App Installer requirements

2. **Network Connection Problems**
   - Verify WiFi credentials
   - Check network availability
   - Script includes retry attempts

3. **Software Installation Errors**
   - Check internet connection
   - Verify Windows Update service is running
   - Review log files for specific error messages

## Security Features

- Secure password handling with SecureString
- Cleanup of sensitive data
- Secure software download verification
- Protected log files

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

[Your License Here]

## Support

For support, [create an issue](https://github.com/VenimK/MusicLover/issues) or contact your system administrator.

## Changelog

### Version 2.1 (2025-03-06)
- Added: Automatic language detection (Dutch/English)
- Added: Translation system for user messages
- Improved: User experience in different languages

### Version 2.0 (2025-01-17)
- Added: secure password handling
- Improved: Notepad++ installation reliability
- Improved: error handling and logging
- Added: multiple software installation methods

### Version 1.0
- Initial release

© 2025 TechStick. All rights reserved. Contact: techmusiclover@outlook.be
