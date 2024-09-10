resource "azurerm_subnet" "bastion_service" {
  name                 = var.bastion_service_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.bastion_service_address_prefixes
}

resource "azurerm_public_ip" "bastion_service" {
  name                = "${local.resource_name_prefix}-bastion-service-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion_service" {
  name                = "${local.resource_name_prefix}-bastion-service"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_service.id
    public_ip_address_id = azurerm_public_ip.bastion_service.id
  }
}