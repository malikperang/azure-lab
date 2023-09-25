resource "azurerm_resource_group" "bastion-example" {
  name     = "bastion-rg"
  location = "southeastasia"
}

resource "azurerm_virtual_network" "bastion-example" {
  name                = "bastion-vnet"
  address_space       = ["192.168.1.0/24"]
  location            = azurerm_resource_group.bastion-example.location
  resource_group_name = azurerm_resource_group.bastion-example.name
}

resource "azurerm_subnet" "bastion-example" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.bastion-example.name
  virtual_network_name = azurerm_virtual_network.bastion-example.name
  address_prefixes     = ["192.168.1.224/27"]
}

resource "azurerm_public_ip" "bastion-example" {
  name                = "bastion-public-ip"
  location            = azurerm_resource_group.bastion-example.location
  resource_group_name = azurerm_resource_group.bastion-example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion-example" {
  name                = "bastion-host"
  location            = azurerm_resource_group.bastion-example.location
  resource_group_name = azurerm_resource_group.bastion-example.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion-example.id
    public_ip_address_id = azurerm_public_ip.bastion-example.id
  }
}

resource "azurerm_network_interface" "bastion-target-vm" {  
  name                = "bastion-example-nic"
  location            = azurerm_resource_group.bastion-example.location
  resource_group_name = azurerm_resource_group.bastion-example.name

  ip_configuration {
    name                          = "bastion-host-ip-1"
    subnet_id                     = azurerm_subnet.bastion-example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.bastion-example.id 
  }
}


# Resource-1: Create Public IP Address for Target VM's
resource "azurerm_public_ip" "bastion-target-vm-public-ip" {
  name                = "bastion-target-vm-publicip"
  resource_group_name = azurerm_resource_group.bastion-example.name
  location            = azurerm_resource_group.bastion-example.location
  allocation_method   = "Static"
  sku = "Standard"
}

# Resource-2: Create Network Interface
resource "azurerm_network_interface" "bastion-target-vm-nic" {
  name                = "bastion-target-vm-nic"
  location            = azurerm_resource_group.bastion-example.location
  resource_group_name = azurerm_resource_group.bastion-example.name

  ip_configuration {
    name                          = "bastion-host-ip-1"
    subnet_id                     = azurerm_subnet.bastion-example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.bastion-target-vm-public-ip.id 
  }
}

# Resource-3: Azure Linux Virtual Machine - Target VM
resource "azurerm_linux_virtual_machine" "bastion-target-vm" {
  name = "test-bastion-linuxvm"
  #computer_name = "bastionlinux-vm"  # Hostname of the VM (Optional)
  resource_group_name   = azurerm_resource_group.bastion-example.name
  location              = azurerm_resource_group.bastion-example.location
  size                  = "Standard_DS1_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.bastion-target-vm-nic.id]
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh-keys/azureuser.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "83-gen2"
    version   = "latest"
  }
}

# Create a Null Resource and Provisioners
resource "null_resource" "name" {
  depends_on = [azurerm_linux_virtual_machine.bastion-target-vm]
# Connection Block for Provisioners to connect to Azure VM Instance
  connection {
    type = "ssh"
    host = azurerm_linux_virtual_machine.bastion-target-vm.public_ip_address
    user = azurerm_linux_virtual_machine.bastion-target-vm.admin_username
    private_key = file("${path.module}/ssh-keys/azureuser.pem")
  }

## File Provisioner: Copies the azureuser.pem file to /tmp/azureuser.pem
  provisioner "file" {
    source      = file("${path.module}/ssh-keys/azureuser.pem")
    destination = "/tmp/azureuser.pem"
  }
## Remote Exec Provisioner: Using remote-exec provisioner fix the private key permissions on Bastion Host
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 400 /tmp/azureuser.pem"
    ]
  }
}

provider "azurerm" {
  features {}
}
