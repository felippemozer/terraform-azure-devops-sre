resource "azurerm_private_dns_zone" "zone" {
  name                = "terraformguru.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "zone" {
  name                = "${local.resource_name_prefix}-private-dns-zone-vnet-associate"
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.zone.name
  virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "app_slb" {
  depends_on = [ azurerm_lb.app ]
  name                = "applb"
  resource_group_name = azurerm_resource_group.rg.name
  zone_name = azurerm_private_dns_zone.zone.name
  ttl = 300
  records = [azurerm_lb.app.frontend_ip_configuration[0].private_ip_address]
}