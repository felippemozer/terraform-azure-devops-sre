resource "random_string" "random" {
  length  = 6
  upper   = false
  special = false
  numeric = false
  lower   = true
}