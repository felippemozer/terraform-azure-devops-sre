locals {
  bastion_inbound_ports_priority_map = {
    "100" : "22",
    "110" : "3389"
  }
}

resource "azurerm_subnet" "bastion" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.bastion_subnet_name}"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = var.bastion_subnet_address_space
}

resource "azurerm_network_security_group" "bastion" {
  name                = "${azurerm_subnet.bastion.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  depends_on = [azurerm_network_security_rule.bastion_inbound]

  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

resource "azurerm_network_security_rule" "bastion_inbound" {
  for_each = local.bastion_inbound_ports_priority_map

  name                        = "Rule-Port-22"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
