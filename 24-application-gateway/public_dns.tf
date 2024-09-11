resource "azurerm_dns_zone" "zone" {
  name                = "kubeoncloud.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_dns_a_record" "web_root" {
  depends_on          = [azurerm_lb.web]
  name                = "@"
  resource_group_name = azurerm_resource_group.rg.name
  zone_name           = azurerm_dns_zone.zone.name
  ttl                 = 300
  target_resource_id = azurerm_lb.web.frontend_ip_configuration[0].public_ip_address_id
}

resource "azurerm_dns_a_record" "web_www" {
  depends_on          = [azurerm_lb.app]
  name                = "www"
  resource_group_name = azurerm_resource_group.rg.name
  zone_name           = azurerm_dns_zone.zone.name
  ttl                 = 300
  target_resource_id = azurerm_lb.web.frontend_ip_configuration[0].public_ip_address_id
}

resource "azurerm_dns_a_record" "web_app1" {
  depends_on          = [azurerm_lb.app]
  name                = "app1"
  resource_group_name = azurerm_resource_group.rg.name
  zone_name           = azurerm_dns_zone.zone.name
  ttl                 = 300
  target_resource_id = azurerm_lb.web.frontend_ip_configuration[0].public_ip_address_id
}
