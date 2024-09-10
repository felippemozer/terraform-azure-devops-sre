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

# resource "azurerm_public_ip" "web" {
#   name                = "${local.resource_name_prefix}-web-linuxvm-publicip"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   domain_name_label   = "app1-vm-${random_string.random.result}"
# }

resource "azurerm_network_interface" "web_vm" {
  name                = "${local.resource_name_prefix}-web-linuxvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "web-linuvm-ip-1"
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
  name = "${local.resource_name_prefix}-web-linuxvm"
  # computer_name = "web-linux-vm" # Hostname of the VM (Optional)
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.id
  size                  = "Standard_DS1_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web_vm.id]

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
  network_interface_id    = azurerm_network_interface.web_vm.id
  ip_configuration_name   = azurerm_network_interface.web_vm.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_slb.id
}