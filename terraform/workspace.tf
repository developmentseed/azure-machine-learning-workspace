# Dependent resources for Azure Machine Learning
resource "azurerm_application_insights" "default" {
  name                = "${random_pet.prefix.id}-appi"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  application_type    = "web"
}

resource "azurerm_key_vault" "default" {
  name                     = "${var.prefix}${var.environment}${random_integer.suffix.result}kv"
  location                 = azurerm_resource_group.default.location
  resource_group_name      = azurerm_resource_group.default.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "premium"
  purge_protection_enabled = false
}

resource "azurerm_storage_account" "default" {
  name                            = "${var.prefix}${var.environment}${random_integer.suffix.result}st"
  location                        = azurerm_resource_group.default.location
  resource_group_name             = azurerm_resource_group.default.name
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_container_registry" "default" {
  name                = "${var.prefix}${var.environment}${random_integer.suffix.result}cr"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "Premium"
  admin_enabled       = true
}

# Machine Learning workspace
resource "azurerm_machine_learning_workspace" "default" {
  name                          = "${var.prefix}${var.environment}${random_integer.suffix.result}-mlw"
  location                      = azurerm_resource_group.default.location
  resource_group_name           = azurerm_resource_group.default.name
  application_insights_id       = azurerm_application_insights.default.id
  key_vault_id                  = azurerm_key_vault.default.id
  storage_account_id            = azurerm_storage_account.default.id
  container_registry_id         = azurerm_container_registry.default.id
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_user_assigned_identity" "default" {
  name                = "${var.prefix}${var.environment}${random_integer.suffix.result}-ml-identity"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
}

resource "azurerm_role_assignment" "ml_role_assignment" {
  scope                = azurerm_machine_learning_workspace.default.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.default.principal_id
}

resource "azurerm_machine_learning_compute_instance" "ml_compute_instance" {
  name                          = "${var.prefix}${var.environment}${random_integer.suffix.result}-comp"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.default.id
  virtual_machine_size          = "Standard_DS3_v2"
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.default.id,
    ]
  }
}

resource "null_resource" "set_idle_time" {
  provisioner "local-exec" {
    command = <<EOT
      az ml compute update --name ${azurerm_machine_learning_compute_instance.ml_compute_instance.name} \
       --workspace-name ${azurerm_machine_learning_workspace.default.name} \
       --resource-group ${azurerm_resource_group.default.name} \
       --tags idle_time_before_scale_down=30
    EOT
  }

  depends_on = [azurerm_machine_learning_compute_instance.ml_compute_instance]
}

