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