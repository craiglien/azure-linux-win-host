# Configure Windows 10 to skip OOBE and set privacy/network settings
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Skip OOBE prompts - these must be set before first login
$oobePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'
New-Item -Path $oobePath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $oobePath -Name 'SkipUserOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $oobePath -Name 'SkipMachineOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $oobePath -Name 'SkipPrivacySettings' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $oobePath -Name 'SkipNetworkSetup' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $oobePath -Name 'SkipEULA' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Disable privacy settings via Group Policy and Registry
# Location Services
$locationPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
New-Item -Path $locationPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $locationPath -Name 'Value' -Value 'Deny' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
$locationPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
New-Item -Path $locationPolicy -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $locationPolicy -Name 'DisableLocation' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Inking and Typing (User Data Tasks)
$inkPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks'
New-Item -Path $inkPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $inkPath -Name 'Value' -Value 'Deny' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

# Advertising ID
$advertisingPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
New-Item -Path $advertisingPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $advertisingPath -Name 'Enabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
$advertisingPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
New-Item -Path $advertisingPolicy -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $advertisingPolicy -Name 'DisabledByGroupPolicy' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Find My Device
$findDevicePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E6AD100E-5F4E-44CD-BE0F-2265D88D14F7}'
New-Item -Path $findDevicePath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $findDevicePath -Name 'Value' -Value 'Deny' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

# Tailored Experiences
$tailoredPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'
New-Item -Path $tailoredPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $tailoredPath -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Set network profile to Private (0 = Private/Discoverable, but we want to set it to not discoverable)
# First, set all networks to Private profile
$networkPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles'
Get-ChildItem -Path $networkPath -ErrorAction SilentlyContinue | ForEach-Object {
    $profilePath = Join-Path $_.PSPath 'Category'
    if (Test-Path $profilePath) {
        Set-ItemProperty -Path $profilePath -Name '(default)' -Value 0 -Force -ErrorAction SilentlyContinue
    }
}

# Disable network discovery via Group Policy
$networkDiscoveryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections'
New-Item -Path $networkDiscoveryPath -Force -ErrorAction SilentlyContinue | Out-Null
$ncPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections\NC_ShowSharedAccessUI'
New-Item -Path $ncPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $ncPath -Name '(default)' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Also set via firewall profile
$firewallPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile'
New-ItemProperty -Path $firewallPath -Name 'EnableDiscovery' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
$firewallPrivatePath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile'
New-ItemProperty -Path $firewallPrivatePath -Name 'EnableDiscovery' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Disable browser promotion
$browserPath = 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main'
New-Item -Path $browserPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $browserPath -Name 'PreventFirstRunPage' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

$edgePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
New-Item -Path $edgePath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $edgePath -Name 'HideFirstRunExperience' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Set privacy settings for default user profile using Windows Settings API approach
# These registry keys are checked by Windows 10 OOBE
$privacySettingsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'
New-Item -Path $privacySettingsPath -Force -ErrorAction SilentlyContinue | Out-Null

# Location - set to 0 to disable
New-ItemProperty -Path $privacySettingsPath -Name 'AllowLocation' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Inking and Typing - set to 0 to disable  
New-ItemProperty -Path $privacySettingsPath -Name 'AllowInputPersonalization' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# Advertising ID - already set above, but ensure it's disabled
# Find My Device - already set above

# Tailored Experiences - already set above

# Use PowerShell to set privacy settings via Windows Settings (if available)
try {
    # Try to use Windows Settings API if available
    $privacyModule = Get-Module -Name WindowsPrivacy -ListAvailable -ErrorAction SilentlyContinue
    if ($privacyModule) {
        Import-Module WindowsPrivacy -ErrorAction SilentlyContinue
        Set-WindowsPrivacySetting -Setting Location -Value Disable -ErrorAction SilentlyContinue
        Set-WindowsPrivacySetting -Setting InkingAndTyping -Value Disable -ErrorAction SilentlyContinue
        Set-WindowsPrivacySetting -Setting AdvertisingId -Value Disable -ErrorAction SilentlyContinue
    }
} catch {
    # Module not available, continue with registry approach
}

# Set timezone to Eastern Time
tzutil /s "Eastern Standard Time"

# Disable Cortana and Telemetry
$cortanaPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $cortanaPath -Name 'AllowCortana' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

$telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
New-Item -Path $telemetryPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $telemetryPath -Name 'AllowTelemetry' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

Write-Host "Windows configuration completed successfully"
