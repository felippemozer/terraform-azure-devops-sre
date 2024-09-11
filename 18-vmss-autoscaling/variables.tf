# General
variable "business_division" {
  default     = "sap"
  type        = string
  description = "Business Division in the large organization this infrastructure belongs"
}

variable "environment" {
  description = "Environment variable used as prefix"
  type        = string
  default     = "dev"
}

# Resource group
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-default"
}

variable "resource_group_location" {
  description = "Region in which Azure Resources to be created"
  type        = string
  default     = "eastus2"
}

# VNET
variable "vnet_name" {
  description = "VNET name"
  type        = string
  default     = "vnet-default"
}

variable "vnet_address_space" {
  description = "VNET CIDR blocks"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

# Subnets
variable "web_subnet_name" {
  description = "Web subnet name"
  type        = string
  default     = "web_subnet"
}
variable "web_subnet_address_space" {
  description = "Web subnet CIDR block"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}
variable "web_vm_instance_count" {
  description = "Web Linux VM instance count"
  type        = map(string)
  default = {
    "vm1" = "1022"
    "vm2" = "2022"
  }
}
variable "web_vmss_nsg_inbound_ports" {
  type    = list(string)
  default = ["22", "80", "443"]
}

variable "app_subnet_name" {
  description = "Web subnet name"
  type        = string
  default     = "app_subnet"
}
variable "app_subnet_address_space" {
  description = "Web subnet CIDR block"
  type        = list(string)
  default     = ["10.0.11.0/24"]
}

variable "db_subnet_name" {
  description = "Web subnet name"
  type        = string
  default     = "db_subnet"
}
variable "db_subnet_address_space" {
  description = "Web subnet CIDR block"
  type        = list(string)
  default     = ["10.0.21.0/24"]
}

variable "bastion_subnet_name" {
  description = "Web subnet name"
  type        = string
  default     = "bastion_subnet"
}
variable "bastion_subnet_address_space" {
  description = "Web subnet CIDR block"
  type        = list(string)
  default     = ["10.0.100.0/24"]
}

# VMs
