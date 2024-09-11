locals {
  httpd_conf_files = ["app1.conf"]
}

resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = var.storage_account_tier
  account_kind             = var.storage_account_kind
  account_replication_type = var.storage_account_replication_type

  static_website {
    index_document = var.static_website_index_document
    error_404_document = var.static_website_error_404_document
  }
}

resource "azurerm_storage_container" "httpd_files" {
  name = "httpd-files-container"
  storage_account_name = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "httpd_files_container" {
  for_each = local.httpd_conf_files
  name = each.value
  storage_account_name = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.httpd_files.name
  type = "Block"
  source = "${path.module}/scripts/${each.value}"
}