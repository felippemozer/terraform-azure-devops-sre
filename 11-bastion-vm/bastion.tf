locals {
  bastion_inbound_ports_priority_map = {
    "100" : "22",
    "110" : "3389"
  }
  bastion_vm_nic_inbound_ports_priority_map = {
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

resource "azurerm_public_ip" "bastion" {
  name                = "${local.resource_name_prefix}-bastion-host-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "bastion_vm" {
  name                = "${local.resource_name_prefix}-bastion-host-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "bastion-host-ip-1"
    subnet_id                     = azurerm_subnet.bastion.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "bastion_vm_nic" {
  name                = "${azurerm_network_interface.bastion_vm.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface_security_group_association" "bastion_vm_nic" {
  depends_on                = [azurerm_network_security_rule.bastion_vm_nic_inbound]
  network_interface_id      = azurerm_network_interface.bastion_vm.id
  network_security_group_id = azurerm_network_security_group.bastion_vm_nic.id
}

resource "azurerm_network_security_rule" "bastion_vm_nic_inbound" {
  for_each = local.bastion_vm_nic_inbound_ports_priority_map

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
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name = "${local.resource_name_prefix}-bastion-host"
  # computer_name = "bastion-linux-vm" # Hostname of the VM (Optional)
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.id
  size                  = "Standard_DS1_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.bastion_vm.id]

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
}

resource "null_resource" "null_copy_ssh_key_to_bastion" {
  depends_on = [ azurerm_linux_virtual_machine.bastion ]

  connection {
    type = "ssh"
    host = azurerm_linux_virtual_machine.bastion.public_ip_address
    user = azurerm_linux_virtual_machine.bastion.admin_username
    private_key = file("${path.module}/ssh/terraform-azure.pem")
  }

  provisioner "file" {
    source      = "${path.module}/ssh/terraform-azure.pem"
    destination = "/tmp/terraform-azure.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 400 /tmp/terraform-azure.pem"
    ]
  }
}