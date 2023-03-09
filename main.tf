terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.46.0"
    }
  }

}

provider "azurerm" {

    /*subscription_id = "ea6e6692-4d05-4c5b-9909-51c7dc5f5c2b"
    client_id       = "337ed61f-f6f1-4511-9ecd-22e74eac740d"
    client_secret   = "Byz8Q~DbXJ9JOYPWTWRtUUcj~lNkVvbJlVAvgayd"
    tenant_id       = "4dfdfd67-3a37-4e2e-b9f0-434c7061ba33"
*/
    features {
      
    }
}

# Resource Group erstellen
resource "azurerm_resource_group" "abschluss-projekt-rg" {
  name     = "abschluss-projekt"
  location = "West Europe"
}

# Container Registery erstellen
resource "azurerm_container_registry" "abschlussprojektacr" {
  name                = "abschlussprojektacr"
  resource_group_name = "abschluss-projekt"
  location            = "West Europe"
  sku                 = "Standard"
  admin_enabled       = false
}


# SSH key erstellen
resource "azurerm_ssh_public_key" "sshkey" {
  name                = "sshkey"
  location            = "West Europe"
  resource_group_name = "abschluss-projekt"
  public_key          = file("./sshkey.pub")
}

# Virtual Network erstellen
resource "azurerm_virtual_network" "abschluss-projekt-rg" {
  name                = "abschluss-projekt-network"
  address_space       = ["10.0.0.0/16"]
  location            = "West Europe"
  resource_group_name = "abschluss-projekt"
}

# Subnet erstellen 
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "abschluss-projekt"
  virtual_network_name = "abschluss-projekt-network"
  address_prefixes     = ["10.0.2.0/24"]
}


# NSG1 für VM1 Jenkins erstellen
resource "azurerm_network_security_group" "jenkins-vm-nsg" {
  name                = "jenkins-vm-nsg"
  location            = "West Europe"
  resource_group_name = "abschluss-projekt"

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow_http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "all_out"
    priority                   = 400
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}



# Verbinden NSG1 mit NIC1 
resource "azurerm_network_interface_security_group_association" "jenkins-association" {
  network_interface_id      = azurerm_network_interface.nic1.id
  network_security_group_id = azurerm_network_security_group.jenkins-vm-nsg.id
}

# Öffentlische IP für VM1 Jenkins erstellen
resource "azurerm_public_ip" "jenkins-vm-public_ip" {
  name                = "jenkins-vm-public_ip"
  resource_group_name = "abschluss-projekt"
  location            = "West Europe"
  allocation_method   = "Static"
}

# NIC1 für VM1 Jenkins erstellen 
resource "azurerm_network_interface" "nic1" {
  name                = "abschluss-projekt-nic1"
  location            = "West Europe"
  resource_group_name = "abschluss-projekt"

  ip_configuration {
    name                          = "jenkins-vm-ip"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.jenkins-vm-public_ip.id
  }
}

# VM1 Jenkins erstellen
resource "azurerm_linux_virtual_machine" "jenkins-vm" {
  name                = "jenkins-vm"
  resource_group_name = "abschluss-projekt"
  location            = "West Europe"
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  
  network_interface_ids = [azurerm_network_interface.nic1.id]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }


  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.sshkey.public_key
  }
}

#################################################################

# NSG2 für VM2 Webserver erstellen
resource "azurerm_network_security_group" "webserver-vm-nsg" {
  name                = "webserver-vm-nsg"
  location            = "West Europe"
  resource_group_name = "abschluss-projekt"

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow_http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "all_out"
    priority                   = 400
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Verbinden NSG2 mit NIC2
resource "azurerm_network_interface_security_group_association" "server-association" {
  network_interface_id      = azurerm_network_interface.nic2.id
  network_security_group_id = azurerm_network_security_group.webserver-vm-nsg.id
}

# Öffentlische IP für VM2 Webserver erstellen
resource "azurerm_public_ip" "webserver-vm-public_ip" {
  name                = "webserver-vm-public_ip"
  resource_group_name = "abschluss-projekt"
  location            = "West Europe"
  allocation_method   = "Static"
}

# NIC2 für VM1 Webserver erstellen
resource "azurerm_network_interface" "nic2" {
  name                = "abschluss-projekt-nic2"
  location            = "West Europe"
  resource_group_name = "abschluss-projekt"

  ip_configuration {
    name                          = "webserver-vm-ip"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.webserver-vm-public_ip.id
  }
}

# VM2 Webserver erstellen
resource "azurerm_linux_virtual_machine" "server-vm" {
  name                = "webserver-vm"
  resource_group_name = "abschluss-projekt"
  location            = "West Europe"
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  
  network_interface_ids = [azurerm_network_interface.nic2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.sshkey.public_key
  }
}

