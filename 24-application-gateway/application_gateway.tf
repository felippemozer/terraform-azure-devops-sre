locals {
  ag_inbound_ports_priority_map = {
    "100" : "80",
    "110" : "443",
    "130" : "65200-65535"
  }

  ag_frontend_port_name             = "${azurerm_virtual_network.vnet.name}-feport"
  ag_frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
  ag_listener_name                  = "${azurerm_virtual_network.vnet.name}-httpslstn"
  ag_request_routing_rule1_name     = "${azurerm_virtual_network.vnet.name}-rqrt-1"

  ag_backend_address_pool_name_app1 = "${azurerm_virtual_network.vnet.name}-beapp-app1"
  ag_http_setting_name_app1         = "${azurerm_virtual_network.vnet.name}-be-htst-app1"
  ag_probe_name_app1                = "${azurerm_virtual_network.vnet.name}-be-probe-app1"
}

resource "azurerm_subnet" "ag" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.ag_subnet_name}"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = var.ag_subnet_address_space
}

resource "azurerm_network_security_group" "ag" {
  name                = "ag-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "ag" {
  depends_on = [azurerm_network_security_rule.ag_inbound]

  subnet_id                 = azurerm_subnet.ag.id
  network_security_group_id = azurerm_network_security_group.ag.id
}

resource "azurerm_network_security_rule" "ag_inbound" {
  for_each = local.ag_inbound_ports_priority_map

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
  network_security_group_name = azurerm_network_security_group.ag.name
}

resource "azurerm_public_ip" "ag_web" {
  name                = "${local.resource_name_prefix}-web-ag-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "ag" {
  name                = "${local.resource_name_prefix}-web-ag"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
    # capacity = 2
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 10
  }

  gateway_ip_configuration {
    name = "my-gateway-ip-config"
    subnet_id = azurerm_subnet.ag.id
  }

  frontend_port {
    name = local.ag_frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name = local.ag_frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.ag_web.id
  }

  http_listener {
    name = local.ag_listener_name
    frontend_ip_configuration_name = local.ag_frontend_ip_configuration_name
    frontend_port_name = local.ag_frontend_port_name
    protocol = "Http"
  }

  backend_address_pool {
    name = local.ag_backend_address_pool_name_app1
  }

  backend_http_settings {
    name = local.ag_http_setting_name_app1
    protocol = "Http"
    port = 80
    cookie_based_affinity = "Disabled"
    request_timeout = 60
    probe_name = local.ag_probe_name_app1
  }

  probe {
    name = local.ag_probe_name_app1
    host = "127.0.0.1"
    path = "/app1/status.html"
    interval = 30
    timeout = 30
    unhealthy_threshold = 3
    protocol = "Http"
    port = 80

    match {
      body = "App1"
      status_code = ["200"]
    }
  }

  request_routing_rule {
    name = local.ag_request_routing_rule1_name
    http_listener_name = local.ag_listener_name
    backend_address_pool_name = local.ag_backend_address_pool_name_app1
    backend_http_settings_name = local.ag_http_setting_name_app1
    rule_type = "Basic"
  }
}