# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.0"
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

# Create subnet
resource "azurerm_subnet" "snet-terraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.rg-tf-demo.name
    virtual_network_name = azurerm_virtual_network.vnet-terraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "centralus"
    resource_group_name          = azurerm_resource_group.rg-tf-demo.name
    allocation_method            = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg-forlinuxhost" {
    name                = "nsg-forLinuxHost"
    location            = "centralus"
    resource_group_name = azurerm_resource_group.rg-tf-demo.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create network interface
resource "azurerm_network_interface" "nic-forlinuxhost" {
    name                      = "nic-forlinuxhost"
    location                  = "centralus"
    resource_group_name       = azurerm_resource_group.rg-tf-demo.name

    ip_configuration {
        name                          = "LinuxNicConfiguration"
        subnet_id                     = azurerm_subnet.snet-terraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsgassoc-linux" {
    network_interface_id      = azurerm_network_interface.nic-forlinuxhost.id
    network_security_group_id = azurerm_network_security_group.nsg-forlinuxhost.id
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "st-forlinux" {
    name                        = "diagiecekohdie"
    resource_group_name         = azurerm_resource_group.rg-tf-demo.name
    location                    = "centralus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "keyfile" {
	 content = tls_private_key.example_ssh.private_key_pem
	 filename = "keyfile"
     file_permission = "0600"
}

resource "local_file" "keyfile_pub" {
	 content = tls_private_key.example_ssh.public_key_openssh
	 filename = "keyfile_pub"
     file_permission = "0600"
}

# Create Linux virtual machine
resource "azurerm_linux_virtual_machine" "vm-linux" {
    name                  = "vm-linux"
    location              = "centralus"
    resource_group_name   = azurerm_resource_group.rg-tf-demo.name
    network_interface_ids = [azurerm_network_interface.nic-forlinuxhost.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-focal"
        sku       = "20_04-lts-gen2"
        version   = "latest"
    }

    computer_name  = "myvm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.st-forlinux.primary_blob_endpoint
    }

    connection {
       type = "ssh"
       host = azurerm_linux_virtual_machine.vm-linux.public_ip_address
       user = azurerm_linux_virtual_machine.vm-linux.admin_username
       private_key = tls_private_key.example_ssh.private_key_pem
       timeout = "30s"
    }

    provisioner "file" {
      source = "linux-host-provision.sh"
      destination = "/tmp/prov-script.sh"
    }

    provisioner "remote-exec" {
      inline = [
        "echo export WIN1=${azurerm_windows_virtual_machine.vm-windows.private_ip_address} >> /tmp/provinfo.sh",
        "bash /tmp/prov-script.sh"
      ]
    }
}

# Create network interface
resource "azurerm_network_interface" "nic-forwindowshost" {
    name                      = "myWindowsNIC"
    location                  = "centralus"
    resource_group_name       = azurerm_resource_group.rg-tf-demo.name

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
  name                = "vm-windows"
  resource_group_name = azurerm_resource_group.rg-tf-demo.name
  location            = "centralus"
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  vm_agent_platform_updates_enabled = false
  network_interface_ids = [
  	azurerm_network_interface.nic-forwindowshost.id
   ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

output "ssh_command" {
       value = format("ssh -Y -i %s -l %s %s",
         local_file.keyfile.filename,
         azurerm_linux_virtual_machine.vm-linux.admin_username,
         azurerm_linux_virtual_machine.vm-linux.public_ip_address)
}

output "windowsRDPaccess" {
       value = format("xfreerdp /u:%s /v:%s",
         azurerm_windows_virtual_machine.vm-windows.admin_username,
         azurerm_windows_virtual_machine.vm-windows.private_ip_address)

}
