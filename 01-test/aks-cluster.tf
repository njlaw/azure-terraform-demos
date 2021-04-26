resource "random_pet" "prefix" {}

provider "azurerm" {
  features {}
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

resource "azurerm_subnet" "nodepool" {
  name = "${random_pet.prefix.id}-nodepool-subnet"
  resource_group_name = azurerm_resource_group.vnet.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes = ["10.100.0.0/20"]
}

resource "azurerm_resource_group" "default" {
  name = "${random_pet.prefix.id}-rg"
  location = "West US 2"

  tags = {
    environment = "demo"
  }
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "default" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = azurerm_resource_group.default.location
    resource_group_name = azurerm_resource_group.default.name
    sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = "${random_pet.prefix.id}-aks"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = "${random_pet.prefix.id}-k8s"

  linux_profile {
    admin_username = "ubuntu"
    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  default_node_pool {
    name            = "default"
    node_count      = var.agent_count
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
    vnet_subnet_id = azurerm_subnet.nodepool.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  role_based_access_control {
    enabled = true
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.default.id
    }
  }

  tags = {
    environment = "demo"
  }
}
