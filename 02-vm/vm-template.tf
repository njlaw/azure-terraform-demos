resource "random_pet" "prefix" {}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "kv" {
  name = "${random_pet.prefix.id}-kv-rg"
  location = "West US 2"

  tags = {
    environment = "Test7"
  }
}

resource "random_id" "kvname" {
  byte_length = 5
  prefix = "keyvault"
  
}

data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "kv1" {
  name = random_id.kvname.hex
  location = azurerm_resource_group.kv.location
  resource_group_name = azurerm_resource_group.kv.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
    storage_permissions = [
      "get",
    ]
  }
}

resource "random_password" "vmpassword" {
  length = 20
  special = true
}
resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  value        = random_password.vmpassword.result
  key_vault_id = azurerm_key_vault.kv1.id
  depends_on = [ azurerm_key_vault.kv1 ]
}

resource "azurerm_resource_group" "vnet" {
  name = "${random_pet.prefix.id}-vnet-rg"
  location = "West US 2"

  tags = {
    environment = "demo"
  }
}

resource "azurerm_virtual_network" "default" {
  name = "${random_pet.prefix.id}-vnet"
  location = azurerm_resource_group.vnet.location
  resource_group_name = azurerm_resource_group.vnet.name
  address_space = [ "10.100.0.0/16" ]
}

resource "azurerm_subnet" "nprd" {
  name = "${random_pet.prefix.id}-nprd-subnet"
  resource_group_name = azurerm_resource_group.vnet.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes = ["10.100.16.0/20"]
}

resource "azurerm_resource_group" "nprdvms" {
  name = "${random_pet.prefix.id}-nprd-vms-rg"
  location = "West US 2"
}

resource "azurerm_public_ip" "vm" {
  count = 3
  name = "${random_pet.prefix.id}-${count.index}-pip"
  resource_group_name = azurerm_resource_group.nprdvms.name
  location = azurerm_resource_group.nprdvms.location
  allocation_method = "Static"
}

resource "azurerm_network_interface" "nic" {
  count = 3
  name = "${random_pet.prefix.id}-${count.index + 1}-nic"
  resource_group_name = azurerm_resource_group.nprdvms.name
  location = azurerm_resource_group.nprdvms.location

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.nprd.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = "${element(azurerm_public_ip.vm.*.id, count.index)}"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  count = 3
  name = "${random_pet.prefix.id}-${count.index + 1}"
  computer_name = "nprd-eagle-ap-${count.index + 1}"
  resource_group_name = azurerm_resource_group.nprdvms.name
  location = azurerm_resource_group.nprdvms.location

  size = "Standard_B2s"

  admin_username = "nadmin"
  admin_password = azurerm_key_vault_secret.vmpassword.value
  network_interface_ids = [ "${element(azurerm_network_interface.nic.*.id, count.index)}" ]
  
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags = {
    app = "Eagle"
    env = "Test7"
    owner = "Kago Ng"
  }
}

