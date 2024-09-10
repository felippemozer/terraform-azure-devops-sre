# VNET
output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

## Web
output "web_subnet_name" {
  value = azurerm_subnet.web.name
}
output "web_subnet_id" {
  value = azurerm_subnet.web.id
}

output "web_subnet_nsg_name" {
  value = azurerm_network_security_group.web.name
}
output "web_subnet_nsg_id" {
  value = azurerm_network_security_group.web.id
}

output "web_vm_private_ip_list" {
  value = [for vm in azurerm_linux_virtual_machine.web : vm.private_ip_address]
}
output "web_vm_private_ip_map" {
  value = {for vm in azurerm_linux_virtual_machine.web : vm.name => vm.private_ip_address}
}
output "web_vm_private_ip_map_keys" {
  value = keys({for vm in azurerm_linux_virtual_machine.web : vm.name => vm.private_ip_address})
}
output "web_vm_private_ip_map_values" {
  value = values({for vm in azurerm_linux_virtual_machine.web : vm.name => vm.private_ip_address})
}
# output "web_vm_public_ip" {
#   value = azurerm_public_ip.web.ip_address
# }
output "web_vm_id_128bit" {
  description = "Web Linux Virtual Machine ID - 128-bit identifier"
  value       = azurerm_linux_virtual_machine.web.virtual_machine_id
}
output "web_vm_id" {
  value = azurerm_linux_virtual_machine.web.id
}
output "web_vm_nic_id_list" {
  value = [for nic in azurerm_network_interface.web_vm : nic.id]
}
output "web_vm_nic_id_map" {
  value = {for vm, nic in azurerm_network_interface.web_vm : vm => nic.id}
}
output "web_vm_nic_private_ip_addresses" {
  value = azurerm_network_interface.web_vm.private_ip_addresses
}

output "web_slb_id" {
  value = azurerm_lb.web.id
}
output "web_slb_frontend_ip_config" {
  value = azurerm_lb.web.frontend_ip_configuration
}

## App
output "app_subnet_name" {
  value = azurerm_subnet.app.name
}
output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "app_subnet_nsg_name" {
  value = azurerm_network_security_group.app.name
}
output "app_subnet_nsg_id" {
  value = azurerm_network_security_group.app.id
}

## DB
output "db_subnet_name" {
  value = azurerm_subnet.db.name
}
output "db_subnet_id" {
  value = azurerm_subnet.db.id
}

output "db_subnet_nsg_name" {
  value = azurerm_network_security_group.db.name
}
output "db_subnet_nsg_id" {
  value = azurerm_network_security_group.db.id
}

## Bastion
output "bastion_subnet_name" {
  value = azurerm_subnet.bastion.name
}
output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}

output "bastion_subnet_nsg_name" {
  value = azurerm_network_security_group.bastion.name
}
output "bastion_subnet_nsg_id" {
  value = azurerm_network_security_group.bastion.id
}
