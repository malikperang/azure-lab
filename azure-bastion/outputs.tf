## Target VM Public IP Output
output "bastion-target-vm-public-ip" {
  description = "Target VM Linux VM Public Address"
  value = azurerm_public_ip.bastion-target-vm-public-ip.ip_address
}
