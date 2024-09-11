locals {
  app_inbound_ports_priority_map = {
    "100" : "80",
    "110" : "443",
    "120" : "8080",
    "130" : "22"
  }

  app_vm_custom_data = <<EOF
  #!/bin/sh
  sudo yum install -y httpd
  sudo systemctl enable httpd
  sudo systemctl start httpd
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
  sudo chmod -R 777 /var/www/html
  sudo mkdir /var/www/html/appvm
  sudo echo "Welcome to StackAmplify - AppVM App1 - VM Hostname: $(hostname)" > /var/www/html/index.html
  sudo echo "Welcome to StackAmplify - AppVM App1 - VM Hostname: $(hostname)" > /var/www/html/appvm/hostname.html
  sudo echo "Welcome to StackAmplify - AppVM App1 - App Status Page" > /var/www/html/appvm/status.html
  sudo curl -H "Metadata:true" --noproxy "*" "https://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/appvm/metadata.html
  EOF
}

resource "azurerm_subnet" "app" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.app_subnet_name}"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = var.app_subnet_address_space
}

resource "azurerm_network_security_group" "app" {
  name                = "app-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  depends_on = [azurerm_network_security_rule.app_inbound]

  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_network_security_rule" "app_inbound" {
  for_each = local.app_inbound_ports_priority_map

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
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_public_ip" "app_nat" {
  name                = "${local.resource_name_prefix}-app-nat-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "app" {
  name                = "${local.resource_name_prefix}-app-nat"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "app" {
  nat_gateway_id       = azurerm_nat_gateway.app.id
  public_ip_address_id = azurerm_public_ip.app_nat.id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.app.id
}

resource "azurerm_network_security_group" "app_vmss" {
  name                = "app-vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.app_vmss_nsg_inbound_ports
    content {
      name                       = "Rule-Port-${security_rule.value}"
      priority                   = sum([security_rule.key, 100])
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "app" {
  name = "${local.resource_name_prefix}-app-vmss"
  # computer_name_prefix = "app-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "azureuser"
  custom_data         = base64encode(local.app_vm_custom_data)
  upgrade_mode        = "Automatic"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh/terraform-azure.pub")
  }

  network_interface {
    name                      = "app-vmss-nic"
    network_security_group_id = azurerm_network_security_group.app_vmss.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.app_slb.id]
    }
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

resource "azurerm_monitor_autoscale_setting" "app_vmss" {
  name                = "${local.resource_name_prefix}-app-vmss-autoscaling"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app.id

  profile {
    name = "default"
    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824
      }
    }
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648
      }
    }
  }
}

resource "azurerm_lb" "app" {
  name                = "${local.resource_name_prefix}-app-slb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "app-lb-privateip-1"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Static"
    private_ip_address_version    = "IPv4"
    private_ip_address            = "10.1.11.241"
  }
}

resource "azurerm_lb_backend_address_pool" "app_slb" {
  name            = "app-backend"
  loadbalancer_id = azurerm_lb.app.id
}

resource "azurerm_lb_probe" "app_slb" {
  name                = "tcp_probe"
  protocol        = "Tcp"
  port            = 80
  loadbalancer_id = azurerm_lb.app.id
  resource_group_name   = azurerm_resource_group.rg.name
}

resource "azurerm_lb_rule" "app_slb" {
  name                           = "app-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.app.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.app_slb.id]
  probe_id                       = azurerm_lb_probe.app_slb.id
  loadbalancer_id                = azurerm_lb.app.id
  resource_group_name   = azurerm_resource_group.rg.name
}