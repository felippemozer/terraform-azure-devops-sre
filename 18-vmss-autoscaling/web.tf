locals {
  web_inbound_ports_priority_map = {
    "100" : "80",
    "110" : "443",
    "120" : "22"
  }
  web_vm_nic_inbound_ports_priority_map = {
    "100" : "80",
    "110" : "443",
    "120" : "22"
  }
}

resource "azurerm_subnet" "web" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.web_subnet_name}"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = var.web_subnet_address_space
}

resource "azurerm_network_security_group" "web" {
  name                = "${azurerm_subnet.web.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "web" {
  depends_on = [azurerm_network_security_rule.web_inbound]

  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_network_security_rule" "web_inbound" {
  for_each = local.web_inbound_ports_priority_map

  name                        = "Rule-Port-${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_interface" "web_vm" {
  for_each = var.web_vm_instance_count

  name                = "${local.resource_name_prefix}-web-linuxvm-nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "web-${each.key}-ip"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.web.id
  }
}

resource "azurerm_network_security_group" "web_vm_nic" {
  name                = "${azurerm_network_interface.web_vm.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "web_vmss" {
  name                = "${azurerm_network_interface.web_vm.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.web_vmss_nsg_inbound_ports
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

resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name = "${local.resource_name_prefix}-web-vmss"
  # computer_name_prefix = "web-vmss-app1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "azureuser"
  custom_data         = filebase64("${path.module}/scripts/redhat-webvm-script.sh")
  upgrade_mode        = "Automatic"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh/terraform-azure.pub")
  }

  network_interface {
    name                      = "web-vmss-nic"
    network_security_group_id = azurerm_network_security_group.web_vmss.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_slb.id]
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

resource "azurerm_monitor_autoscale_setting" "web_vmss" {
  name                = "${local.resource_name_prefix}-web-vmss-autoscaling"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web.id

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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
  }

  profile {
    name = "weekdays"
    capacity {
      default = 4
      minimum = 4
      maximum = 20
    }
    recurrence {
      timezone = "Brazil Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [0]
      minutes  = [0]
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
  }

  profile {
    name = "weekends"
    capacity {
      default = 3
      minimum = 3
      maximum = 6
    }
    recurrence {
      timezone = "Brazil Standard Time"
      days     = ["Saturday", "Sunday"]
      hours    = [0]
      minutes  = [0]
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
  }

  profile {
    name = "fixed"
    capacity {
      default = 5
      minimum = 5
      maximum = 20
    }
    fixed_date {
      timezone = "Brazil Standard Time"
      start    = "2024-09-11T00:00:00Z"
      end      = "2024-09-11T23:59:59Z"
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10
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
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web.id
        metric_namespace   = "Microsoft.Network/loadBalancers"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
  }
}

resource "azurerm_network_interface_security_group_association" "web_vm_nic" {
  depends_on                = [azurerm_network_security_rule.web_vm_nic_inbound]
  network_interface_id      = azurerm_network_interface.web_vm.id
  network_security_group_id = azurerm_network_security_group.web_vm_nic.id
}

resource "azurerm_network_security_rule" "web_vm_nic_inbound" {
  for_each = local.web_vm_nic_inbound_ports_priority_map

  name                        = "Rule-Port-${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_linux_virtual_machine" "web" {
  for_each = var.web_vm_instance_count

  name = "${local.resource_name_prefix}-web-linuxvm-${each.key}"
  # computer_name = "web-linux-vm" # Hostname of the VM (Optional)
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.id
  size                  = "Standard_DS1_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web_vm[each.key].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh/terraform-azure.pub")
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

  custom_data = filebase64("${path.module}/scripts/redhat-webvm-script.sh")
}

resource "azurerm_public_ip" "web_slb" {
  name                = "${local.resource_name_prefix}-web-slb-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.id
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_lb" "web" {
  name                = "${local.resource_name_prefix}-web-slb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.id
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "web-lb-public-fip"
    public_ip_address_id = azurerm_public_ip.web_slb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web_slb" {
  name            = "web-backend"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "web_slb" {
  name            = "tcp-probe"
  protocol        = "Tcp"
  port            = 80
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_rule" "web_slb" {
  name                           = "web-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  frontend_ip_configuration_name = azurerm_lb.web.frontend_ip_configuration[0].name
  backend_port                   = 800
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_slb.id]
  probe_id                       = azurerm_lb_probe.web_slb.id
  loadbalancer_id                = azurerm_lb.web.id
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  for_each = var.web_vm_instance_count

  network_interface_id    = azurerm_network_interface.web_vm[each.key].id
  ip_configuration_name   = azurerm_network_interface.web_vm[each.key].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_slb.id
}

resource "azurerm_lb_nat_rule" "web_slb" {
  for_each = var.web_vm_instance_count

  name                           = "${each.key}-ssh-${each.value}-vm-22"
  protocol                       = "Tcp"
  frontend_port                  = each.value
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.web.frontend_ip_configuration[0].name
  loadbalancer_id                = azurerm_lb.web.id
  resource_group_name            = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface_nat_rule_association" "web" {
  for_each = var.web_vm_instance_count

  network_interface_id  = azurerm_network_interface.web_vm[each.key].id
  ip_configuration_name = azurerm_network_interface.web_vm[each.key].ip_configuration[0].name
  nat_rule_id           = azurerm_lb_nat_rule.web_slb[each.key].id
}
