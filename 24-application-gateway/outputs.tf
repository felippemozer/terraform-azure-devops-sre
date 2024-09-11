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
  value = { for vm in azurerm_linux_virtual_machine.web : vm.name => vm.private_ip_address }
}
output "web_vm_private_ip_map_keys" {
  value = keys({ for vm in azurerm_linux_virtual_machine.web : vm.name => vm.private_ip_address })
}
output "web_vm_private_ip_map_values" {
  value = values({ for vm in azurerm_linux_virtual_machine.web : vm.name => vm.private_ip_address })
}
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
  value = { for vm, nic in azurerm_network_interface.web_vm : vm => nic.id }
}
output "web_vm_nic_private_ip_addresses" {
  value = azurerm_network_interface.web_vm.private_ip_addresses
}

output "web_vmss_id" {
  value = azurerm_linux_virtual_machine_scale_set.web.id
}

output "web_slb_id" {
  value = azurerm_lb.web.id
}
output "web_slb_frontend_ip_config" {
  value = azurerm_lb.web.frontend_ip_configuration
}

output "web_dns_root_fqdn" {
  value = azurerm_dns_a_record.web_root.fqdn
}
output "web_dns_www_fqdn" {
  value = azurerm_dns_a_record.web_www.fqdn
}
output "web_dns_app1_fqdn" {
  value = azurerm_dns_a_record.web_app1.fqdn
}

output "web_ag_id" {
  value = azurerm_application_gateway.ag.id
}
output "web_ag_public_ip_1" {
  value = azurerm_public_ip.ag_web.ip_address
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

output "app_nat_id" {
  value = azurerm_nat_gateway.app.id
}
output "app_nat_public_ip" {
  value = azurerm_public_ip.app_nat.ip_address
}

output "app_slb_fqdn" {
  description = "App DNS record"
  value = azurerm_private_dns_a_record.app_slb.fqdn
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

# Storage
output "storage_account_primary_access_key" {
  value = azurerm_storage_account.sa.primary_access_key
  sensitive = true
}
output "storage_account_primary_web_enpoint" {
  value = azurerm_storage_account.sa.primary_web_endpoint
}
output "storage_account_primary_web_host" {
  value = azurerm_storage_account.sa.primary_web_host
}
output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

# DNS
output "dns_zone_id" {
  value = azurerm_dns_zone.zone.id
}
output "dns_zone_name" {
  value = azurerm_dns_zone.zone.name
}