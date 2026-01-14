# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg-tf-demo" {
  name     = "DemoRG"
  location = "centralus"
}

# Create virtual network
resource "azurerm_virtual_network" "vnet-terraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "centralus"
  resource_group_name = azurerm_resource_group.rg-tf-demo.name
}

# Create application subnet
resource "azurerm_subnet" "snet-terraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg-tf-demo.name
  virtual_network_name = azurerm_virtual_network.vnet-terraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Bastion subnet (required name and /27 or larger)
resource "azurerm_subnet" "snet-bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg-tf-demo.name
  virtual_network_name = azurerm_virtual_network.vnet-terraformnetwork.name
  address_prefixes     = ["10.0.2.0/27"]
}

# Public IP for Azure Bastion (must be Standard & Static)
resource "azurerm_public_ip" "bastion" {
  name                = "bastion-ip"
  location            = "centralus"
  resource_group_name = azurerm_resource_group.rg-tf-demo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Bastion host to connect to VMs from the portal
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  location            = "centralus"
  resource_group_name = azurerm_resource_group.rg-tf-demo.name

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.snet-bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# Create network interface
resource "azurerm_network_interface" "nic-forwindowshost" {
  name                = "myWindowsNIC"
  location            = "centralus"
  resource_group_name = azurerm_resource_group.rg-tf-demo.name

  ip_configuration {
    name                          = "WindowsNicConfiguration"
    subnet_id                     = azurerm_subnet.snet-terraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg-forwindowshost" {
  name                = "nsg-forWindowsHost"
  location            = "centralus"
  resource_group_name = azurerm_resource_group.rg-tf-demo.name

  security_rule {
    name                       = "allow-icmp"
    description                = "allow-icmp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-rdp"
    description                = "allow-rdp"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    description                = "allow-http"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsgassoc-windows" {
  network_interface_id      = azurerm_network_interface.nic-forwindowshost.id
  network_security_group_id = azurerm_network_security_group.nsg-forwindowshost.id
}


resource "azurerm_windows_virtual_machine" "vm-windows" {
  name                              = "vm-windows"
  resource_group_name               = azurerm_resource_group.rg-tf-demo.name
  location                          = "centralus"
  size                              = "Standard_D2s_v3"
  admin_username                    = "adminuser"
  admin_password                    = "P@$$w0rd1234!"
  vm_agent_platform_updates_enabled = false
  network_interface_ids = [
    azurerm_network_interface.nic-forwindowshost.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro-g2"
    version   = "19045.6456.251117"
  }
}

# Skip Windows OOBE (Out of Box Experience) prompts using Custom Script Extension
resource "azurerm_virtual_machine_extension" "vm-windows-skip-oobe" {
  name                 = "vm-windows-skip-oobe"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm-windows.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $oobePolicyPath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\OOBE'; if(!(Test-Path $oobePolicyPath)){New-Item -Path $oobePolicyPath -Force | Out-Null}; New-ItemProperty -Path $oobePolicyPath -Name 'DisablePrivacyExperience' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $oobePath='HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE'; if(!(Test-Path $oobePath)){New-Item -Path $oobePath -Force | Out-Null}; New-ItemProperty -Path $oobePath -Name 'SkipUserOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $oobePath -Name 'SkipMachineOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $oobePath -Name 'SkipPrivacySettings' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $oobePath -Name 'SkipNetworkSetup' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $oobePath -Name 'SkipEULA' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $locationPath='HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location'; if(!(Test-Path $locationPath)){New-Item -Path $locationPath -Force | Out-Null}; New-ItemProperty -Path $locationPath -Name 'Value' -Value 'Deny' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null; $locationPolicy='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\LocationAndSensors'; if(!(Test-Path $locationPolicy)){New-Item -Path $locationPolicy -Force | Out-Null}; New-ItemProperty -Path $locationPolicy -Name 'DisableLocation' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $inkPath='HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\userDataTasks'; if(!(Test-Path $inkPath)){New-Item -Path $inkPath -Force | Out-Null}; New-ItemProperty -Path $inkPath -Name 'Value' -Value 'Deny' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null; $advertisingPath='HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo'; if(!(Test-Path $advertisingPath)){New-Item -Path $advertisingPath -Force | Out-Null}; New-ItemProperty -Path $advertisingPath -Name 'Enabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $advertisingPolicy='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AdvertisingInfo'; if(!(Test-Path $advertisingPolicy)){New-Item -Path $advertisingPolicy -Force | Out-Null}; New-ItemProperty -Path $advertisingPolicy -Name 'DisabledByGroupPolicy' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $findDevicePath='HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\DeviceAccess\\Global\\{E6AD100E-5F4E-44CD-BE0F-2265D88D14F7}'; if(!(Test-Path $findDevicePath)){New-Item -Path $findDevicePath -Force | Out-Null}; New-ItemProperty -Path $findDevicePath -Name 'Value' -Value 'Deny' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null; $tailoredPath='HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Privacy'; if(!(Test-Path $tailoredPath)){New-Item -Path $tailoredPath -Force | Out-Null}; New-ItemProperty -Path $tailoredPath -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $tailoredPath -Name 'AllowLocation' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $tailoredPath -Name 'AllowInputPersonalization' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $networkPath='HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\NetworkList\\Profiles'; Get-ChildItem -Path $networkPath -ErrorAction SilentlyContinue | ForEach-Object { $profilePath=Join-Path $_.PSPath 'Category'; if(Test-Path $profilePath){Set-ItemProperty -Path $profilePath -Name '(default)' -Value 0 -Force -ErrorAction SilentlyContinue} }; $firewallPath='HKLM:\\SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\StandardProfile'; New-ItemProperty -Path $firewallPath -Name 'EnableDiscovery' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $networkDiscoveryPolicy='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Network Connections'; if(!(Test-Path $networkDiscoveryPolicy)){New-Item -Path $networkDiscoveryPolicy -Force | Out-Null}; New-ItemProperty -Path $networkDiscoveryPolicy -Name 'NC_DoNotAllowGuestAccess' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $browserPath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\MicrosoftEdge\\Main'; if(!(Test-Path $browserPath)){New-Item -Path $browserPath -Force | Out-Null}; New-ItemProperty -Path $browserPath -Name 'PreventFirstRunPage' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $edgePath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge'; if(!(Test-Path $edgePath)){New-Item -Path $edgePath -Force | Out-Null}; New-ItemProperty -Path $edgePath -Name 'HideFirstRunExperience' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; tzutil /s 'Eastern Standard Time'; $cortanaPath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search'; if(!(Test-Path $cortanaPath)){New-Item -Path $cortanaPath -Force | Out-Null}; New-ItemProperty -Path $cortanaPath -Name 'AllowCortana' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; $telemetryPath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection'; if(!(Test-Path $telemetryPath)){New-Item -Path $telemetryPath -Force | Out-Null}; New-ItemProperty -Path $telemetryPath -Name 'AllowTelemetry' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null\""
  })
}

output "windowsRDPaccess" {
  value = format("xfreerdp /u:%s /v:%s",
    azurerm_windows_virtual_machine.vm-windows.admin_username,
  azurerm_windows_virtual_machine.vm-windows.private_ip_address)

}
