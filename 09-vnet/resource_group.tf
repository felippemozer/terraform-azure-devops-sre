resource "azurerm_resource_group" "rg" {
  name     = "${local.resource_name_prefix}-${var.resource_group_name}-${random_string.random.result}"
  location = var.resource_group_location
  tags     = local.common_tags
}