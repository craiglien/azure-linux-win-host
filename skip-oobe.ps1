# Skip Windows 10 OOBE (Out of Box Experience) prompts
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Registry path for OOBE settings
$oobePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'

# Create registry keys to skip OOBE prompts
New-ItemProperty -Path $oobePath -Name 'SkipUserOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $oobePath -Name 'SkipMachineOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $oobePath -Name 'SkipPrivacySettings' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $oobePath -Name 'SkipNetworkSetup' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $oobePath -Name 'SkipEULA' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue

# Skip Cortana and other first-run prompts
$cortanaPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $cortanaPath -Name 'AllowCortana' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue

# Disable telemetry
$telemetryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
New-Item -Path $telemetryPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $telemetryPath -Name 'AllowTelemetry' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue

Write-Host "OOBE skip settings configured successfully"
